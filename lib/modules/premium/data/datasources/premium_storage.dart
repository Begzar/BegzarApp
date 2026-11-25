import 'dart:convert';

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar/modules/premium/data/dtos/premium_session_dto.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';

/// Persists the premium sign-in via secure storage — the module's local
/// data source.
class PremiumStorage {
  static const _sessionKey = 'premium_session_v1';
  static const _legacyAccessKey = 'premium_access_key';
  static const _legacyUsernameKey = 'premium_username';
  static const _legacyExpireDateKey = 'premium_expire_date';

  /// Written by builds that persisted the free/premium view mode. Nothing
  /// reads it any more; signing out still clears it so it does not outlive
  /// the session it was written beside.
  static const _legacyConfigSourceKey = 'premium_config_source';

  static const _lastConnectedServerIdKey = 'premium_last_connected_server_id';
  static const _lastConnectedConfigIdKey = 'premium_last_connected_config_id';

  /// The names the last connect landed on, saved with its ids so a later
  /// launch can show them after the list stops offering that server.
  static const _lastConnectedLabelKey = 'premium_last_connected_label';
  static const _labelServerField = 'server';
  static const _labelConfigField = 'config';
  static const _labelFlagField = 'flag';

  final AppKeyedStorage _storage;
  final DeviceIdentity _deviceIdentity;

  PremiumStorage({AppKeyedStorage? storage})
    : _storage = storage ?? AppSecureStorage.instance,
      _deviceIdentity = DeviceIdentity(storage: storage);

  /// This install's id, which premium uses to bind and list devices.
  ///
  /// The id itself is core's — every signed request carries it, signed in or
  /// not — so this only forwards. Kept as a method here because the premium
  /// repository asks for it by this name in three places, and because it is
  /// genuinely part of what premium needs to know about a device.
  Future<String> getOrCreateDeviceId() => _deviceIdentity.getOrCreate();

  Future<void> saveSession(PremiumSession session) => _storage.write(
    key: _sessionKey,
    value: jsonEncode(PremiumSessionDto.toJson(session)),
  );

  Future<PremiumSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final session = PremiumSessionDto.fromJson(map);
        // Older builds stored a password and a view mode alongside the
        // session; rewriting drops both from disk on the next launch.
        if (PremiumSessionDto.legacyFields.any(map.containsKey)) {
          await saveSession(session);
        }
        return session;
      } catch (_) {
        // Unreadable session JSON; try the legacy keys.
      }
    }

    return _migrateLegacySession();
  }

  Future<PremiumSession?> _migrateLegacySession() async {
    final accessKey = await _storage.read(key: _legacyAccessKey);
    final username = await _storage.read(key: _legacyUsernameKey);
    final expireDate = await _storage.read(key: _legacyExpireDateKey);

    if (accessKey == null || username == null || expireDate == null) {
      return null;
    }

    final session = PremiumSession(
      accessKey: accessKey,
      account: PremiumAccount(username: username, expireDate: expireDate),
    );
    await saveSession(session);
    return session;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _sessionKey),
      _storage.delete(key: _legacyAccessKey),
      _storage.delete(key: _legacyUsernameKey),
      _storage.delete(key: _legacyExpireDateKey),
      _storage.delete(key: _legacyConfigSourceKey),
    ]);
  }

  Future<void> saveLastConnected({
    required int serverId,
    required int configId,
    required PremiumServerLabel label,
  }) async {
    await Future.wait([
      _storage.write(
        key: _lastConnectedServerIdKey,
        value: serverId.toString(),
      ),
      _storage.write(
        key: _lastConnectedConfigIdKey,
        value: configId.toString(),
      ),
      _storage.write(
        key: _lastConnectedLabelKey,
        value: jsonEncode({
          _labelServerField: label.serverName,
          _labelConfigField: label.configName,
          _labelFlagField: label.flagCode,
        }),
      ),
    ]);
  }

  /// The names saved with the last-connected ids, or null when none were
  /// saved or what was saved cannot be read.
  Future<PremiumServerLabel?> readLastConnectedLabel() async {
    final raw = await _storage.read(key: _lastConnectedLabelKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PremiumServerLabel(
        serverName: map[_labelServerField] as String,
        configName: map[_labelConfigField] as String,
        flagCode: map[_labelFlagField] as String?,
      );
    } catch (_) {
      // A label is only ever shown, so an unreadable one is the same as none.
      return null;
    }
  }

  Future<({int serverId, int configId})?> readLastConnected() async {
    final serverRaw = await _storage.read(key: _lastConnectedServerIdKey);
    final configRaw = await _storage.read(key: _lastConnectedConfigIdKey);
    final serverId = int.tryParse(serverRaw ?? '');
    final configId = int.tryParse(configRaw ?? '');
    if (serverId == null || configId == null) {
      return null;
    }
    return (serverId: serverId, configId: configId);
  }
}
