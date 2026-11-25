import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/backend_failure.dart';
import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:fpdart/fpdart.dart';

/// The free tier's backend calls, through the engine's operations.
///
/// The session key is kept here, under the keys every installed copy already
/// wrote it to; the engine is handed it for each call.
///
/// Calls return `Either<ApiFailure, T>` — the failure side carries a typed
/// cause instead of an exception message or a bare null.
class ApiV2Service {
  static const _log = Log('api');

  /// V4 session token (32-byte key, base64).
  static const String keySessionToken = 'begzar_session_token';

  /// Legacy V3 storage key — migrated on read.
  static const String keyUserKey = 'api_v2_user_key';

  ApiV2Service({BegzarBackend? backend, DeviceIdentity? deviceIdentity})
    : _backendOverride = backend,
      _deviceIdentityOverride = deviceIdentity;

  final BegzarBackend? _backendOverride;
  final DeviceIdentity? _deviceIdentityOverride;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  DeviceIdentity get _deviceIdentity =>
      _deviceIdentityOverride ?? DeviceIdentity();

  AppKeyedStorage get _storage => AppSecureStorage.instance;

  static Future<String?> readSessionToken() async {
    final storage = AppSecureStorage.instance;
    var token = await storage.read(key: keySessionToken);
    if (token != null && token.isNotEmpty) return token;

    final legacy = await storage.read(key: keyUserKey);
    if (legacy != null && legacy.isNotEmpty) {
      await storage.write(key: keySessionToken, value: legacy);
      return legacy;
    }
    return null;
  }

  /// Register session (first run).
  Future<Either<ApiFailure, String>> initializeDevice() async {
    _log.trace('session.register');
    try {
      final BackendAnswer<String> answer;
      try {
        answer = await _backend.registerSession();
      } on BackendException catch (e) {
        ReleaseHintBus.publish(e.releaseHint);
        _log.error('session.register.failed', {
          'kind': e.kind.name,
          'status': e.status,
        });
        return left(
          apiFailureFromBackend(
            e,
            unexpectedKey: UserFacingErrorKeys.deviceInitFailed,
          ),
        );
      }
      ReleaseHintBus.publish(answer.releaseHint);
      await _storage.write(key: keySessionToken, value: answer.value);
      await _storage.delete(key: keyUserKey);
      _log.trace('session.register.ok');
      return right(answer.value);
    } catch (e) {
      _log.error('session.register.threw', {'type': e.runtimeType}, e);
      return left(
        UnexpectedFailure(
          'Session registration failed: $e',
          userFacingKey: UserFacingErrorKeys.deviceInitFailed,
          cause: e,
        ),
      );
    }
  }

  /// The stored session token, registering this device for one first when
  /// there is none.
  ///
  /// Every route signed with the session key needs it, and nothing registers
  /// one at launch: a device that has never connected has none until a route
  /// asks for it here.
  Future<Either<ApiFailure, String>> ensureSessionToken() async {
    final stored = await readSessionToken();
    if (stored != null) {
      _log.trace('session.present');
      return right(stored);
    }
    _log.trace('session.missing');
    return initializeDevice();
  }

  Future<Either<ApiFailure, SubscriptionPayload>> getVPNConfigurations() async {
    _log.trace('subscription.fetch');
    try {
      final session = await ensureSessionToken();
      if (session case Left(value: final failure)) {
        _log.error('subscription.registerFailed', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        return left(failure);
      }
      final sessionToken = session.getOrElse((_) => '');
      final deviceId = await _deviceIdentity.getOrCreate();

      final BackendAnswer<List<String>> answer;
      try {
        answer = await _backend.fetchFreeServers(
          sessionKey: sessionToken,
          deviceId: deviceId,
        );
      } on BackendException catch (e) {
        ReleaseHintBus.publish(e.releaseHint);
        _log.error('subscription.failed', {
          'kind': e.kind.name,
          'status': e.status,
        });
        return left(
          apiFailureFromBackend(
            e,
            unexpectedKey: UserFacingErrorKeys.fetchConfigsFailed,
          ),
        );
      }
      ReleaseHintBus.publish(answer.releaseHint);
      _log.trace('subscription.ok', {'configs': answer.value.length});
      return right(
        SubscriptionPayload(
          configUrls: answer.value,
          serverVersion: answer.releaseHint?.version,
          updatedUrl: answer.releaseHint?.updateUrl,
        ),
      );
    } catch (e) {
      _log.error('subscription.threw', {'type': e.runtimeType}, e);
      return left(
        UnexpectedFailure(
          'Failed to fetch configurations: $e',
          userFacingKey: UserFacingErrorKeys.fetchConfigsFailed,
          cause: e,
        ),
      );
    }
  }

  Future<bool> isInitialized() async {
    return await readSessionToken() != null;
  }

  Future<String?> getUserKey() async => readSessionToken();

  Future<void> clearCredentials() async {
    await _storage.delete(key: keySessionToken);
    await _storage.delete(key: keyUserKey);
  }
}

/// What a decrypted subscription response carried.
///
/// Config URLs rather than configs: this layer moves bytes and proves they
/// came from Begzar, and stops short of deciding what they mean. The
/// connection module builds its own entities out of [configUrls].
class SubscriptionPayload {
  const SubscriptionPayload({
    required this.configUrls,
    this.serverVersion,
    this.updatedUrl,
  });

  final List<String> configUrls;
  final String? serverVersion;
  final String? updatedUrl;
}
