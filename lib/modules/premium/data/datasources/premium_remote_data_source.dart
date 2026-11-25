import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/backend_failure.dart';
import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/premium/data/datasources/premium_device_info.dart';
import 'package:begzar/modules/premium/data/dtos/premium_device_dto.dart';
import 'package:begzar/modules/premium/data/dtos/premium_server_dto.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:fpdart/fpdart.dart';

/// The premium backend — the module's remote data source.
///
/// Named a data source rather than a service so it is not mistaken for the
/// application-layer services above it: nothing here decides anything. Each
/// call is one of the engine's operations, handed the credentials this app
/// keeps, and its answer is turned into a result.
///
/// Every call that needs a credential is handed one. It used to read the
/// stored session itself, which made one data source depend on another and
/// left "is there a session" answered in two places; [PremiumRepository] owns
/// that question now.
///
/// Sign-up, account deletion, plans and Play purchases follow the contracts
/// proposed in #340 and #343 until the backend builds them.
///
/// Calls return `Either<ApiFailure, T>` — the failure side carries a typed
/// cause.
class PremiumRemoteDataSource {
  /// How long to wait before offering another code when the server does not
  /// say.
  static const _fallbackResendAfter = Duration(seconds: 60);

  /// [ensureSessionToken] is handed down rather than read here, for the same
  /// reason the credentials are: asking for a sign-up code is signed with the
  /// device's session rather than an account's, and a device that has never
  /// connected has not registered one yet.
  ///
  /// [backend] stands in for the engine's operations in tests.
  PremiumRemoteDataSource({
    PremiumDeviceInfo? deviceInfo,
    Future<Either<ApiFailure, String>> Function()? ensureSessionToken,
    BegzarBackend? backend,
    DeviceIdentity? deviceIdentity,
  }) : _deviceInfo = deviceInfo ?? PremiumDeviceInfo(),
       _ensureSessionToken = ensureSessionToken,
       _backendOverride = backend,
       _deviceIdentityOverride = deviceIdentity;

  final PremiumDeviceInfo _deviceInfo;
  final Future<Either<ApiFailure, String>> Function()? _ensureSessionToken;
  final BegzarBackend? _backendOverride;
  final DeviceIdentity? _deviceIdentityOverride;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  /// What a premium call is made with: the device's session key when it has
  /// one, [accessKey], and the id this install signs with unless [deviceId]
  /// names the device the call is about.
  Future<BackendPremiumCredentials> _credentials({
    String accessKey = '',
    String? deviceId,
  }) async => BackendPremiumCredentials(
    sessionKey: await ApiV2Service.readSessionToken() ?? '',
    accessKey: accessKey,
    deviceId:
        deviceId ??
        await (_deviceIdentityOverride ?? DeviceIdentity()).getOrCreate(),
  );

  /// Runs an engine operation, turning a refusal into the failure the call
  /// always returned and anything unforeseen into [unexpected].
  Future<Either<ApiFailure, T>> _operation<T>(
    Future<T> Function() run, {
    required String unexpected,
    required String unexpectedKey,
  }) async {
    try {
      return right(await run());
    } on BackendException catch (e) {
      return left(apiFailureFromBackend(e, unexpectedKey: unexpectedKey));
    } catch (e) {
      return left(
        UnexpectedFailure(
          '$unexpected: $e',
          userFacingKey: unexpectedKey,
          cause: e,
        ),
      );
    }
  }

  static PremiumAccount _accountFrom(BackendAccount account) => PremiumAccount(
    username: account.username,
    email: account.email,
    expireDate: account.expireDate,
    statusLabel: account.statusLabel,
  );

  static PremiumSession _sessionFrom(BackendSession session) => PremiumSession(
    accessKey: session.accessKey,
    account: _accountFrom(session.account),
  );

  Future<Either<ApiFailure, PremiumSession>> login({
    required String username,
    required String password,
    required String deviceId,
  }) => _operation(
    () async => _sessionFrom(
      (await _backend.premiumSignIn(
        username: username.trim(),
        password: password,
        deviceName: await _deviceInfo.getDeviceName(),
        credentials: await _credentials(deviceId: deviceId),
      )).value,
    ),
    unexpected: 'Login failed',
    unexpectedKey: UserFacingErrorKeys.loginFailed,
  );

  /// Asks for a confirmation code to be emailed, and answers with how long to
  /// wait before another may be asked for. Sign-up and resend share this: both
  /// send a code, and both answer with the wait.
  Future<Either<ApiFailure, Duration>> _requestCode(
    Future<BackendAnswer<int?>> Function(BackendPremiumCredentials) ask,
  ) async {
    // Without a session the request would go out unsigned, which the server
    // refuses.
    final session = await _ensureSessionToken?.call();
    if (session case Left(value: final failure)) return left(failure);

    return _operation(
      () async {
        final seconds = (await ask(await _credentials())).value;
        return seconds != null && seconds > 0
            ? Duration(seconds: seconds)
            : _fallbackResendAfter;
      },
      unexpected: 'Sign-up failed',
      unexpectedKey: UserFacingErrorKeys.signUpFailed,
    );
  }

  /// Starts an account: the server holds the email and password until the
  /// code it emails comes back through [verifySignUp].
  Future<Either<ApiFailure, Duration>> signUp({
    required String email,
    required String password,
  }) => _requestCode(
    (credentials) => _backend.requestSignUpCode(
      email: email,
      password: password,
      credentials: credentials,
    ),
  );

  Future<Either<ApiFailure, Duration>> resendSignUpCode({
    required String email,
  }) => _requestCode(
    (credentials) =>
        _backend.resendSignUpCode(email: email, credentials: credentials),
  );

  /// Confirms the emailed code. A confirmed sign-up is a sign-in on this
  /// device, so the answer is the same as [login]'s. It is sent once: a
  /// consumed code is not accepted twice.
  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
    required String deviceId,
  }) => _operation(
    () async => _sessionFrom(
      (await _backend.confirmSignUp(
        email: email,
        code: code,
        deviceName: await _deviceInfo.getDeviceName(),
        credentials: await _credentials(deviceId: deviceId),
      )).value,
    ),
    unexpected: 'Verification failed',
    unexpectedKey: UserFacingErrorKeys.verifyFailed,
  );

  /// Deletes the account and everything on it. The password is asked again
  /// because a session left signed in on a borrowed phone should not be
  /// enough to do this. It is sent once: an account already deleted cannot be
  /// deleted again.
  Future<Either<ApiFailure, Unit>> deleteAccount({
    required String accessKey,
    required String deviceId,
    required String password,
  }) => _operation(
    () async {
      await _backend.deleteAccount(
        password: password,
        credentials: await _credentials(
          accessKey: accessKey,
          deviceId: deviceId,
        ),
      );
      return unit;
    },
    unexpected: 'Account deletion failed',
    unexpectedKey: UserFacingErrorKeys.deleteAccountFailed,
  );

  /// The plans the paywall sells, in display order, read signed out.
  Future<Either<ApiFailure, List<PremiumPlan>>> fetchPlans() => _operation(
    () async => [
      for (final plan in (await _backend.premiumPlans()).value)
        PremiumPlan(
          devices: plan.devices,
          productId: plan.productId,
          basePlanId: plan.basePlanId,
        ),
    ],
    unexpected: 'Plans unavailable',
    unexpectedKey: UserFacingErrorKeys.plansUnavailable,
  );

  /// Tells the server about a purchase Play made, so it can check it with
  /// Google and grant it. Safe to send again for the same token: the app
  /// reports at every launch until the purchase is acknowledged.
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String accessKey,
    required String deviceId,
    required String productId,
    required String purchaseToken,
  }) => _operation(
    () async {
      await _backend.reportPlayPurchase(
        productId: productId,
        purchaseToken: purchaseToken,
        credentials: await _credentials(
          accessKey: accessKey,
          deviceId: deviceId,
        ),
      );
      return unit;
    },
    unexpected: 'Purchase report failed',
    unexpectedKey: UserFacingErrorKeys.purchaseFailed,
  );

  /// The subscription and its device roster, which one answer carries.
  Future<Either<ApiFailure, PremiumUserData>> fetchUserData(String accessKey) =>
      _operation(
        () async {
          final data = (await _backend.premiumAccount(
            await _credentials(accessKey: accessKey),
          )).value;
          return PremiumUserData(
            account: _accountFrom(data.account),
            devices: PremiumDeviceDto.rosterFromBackend(data),
          );
        },
        unexpected: 'Failed to load subscription',
        unexpectedKey: UserFacingErrorKeys.loadSubscription,
      );

  Future<Either<ApiFailure, Unit>> logout({
    required String accessKey,
    required String deviceId,
  }) => _operation(
    () async {
      await _backend.premiumSignOut(
        await _credentials(accessKey: accessKey, deviceId: deviceId),
      );
      return unit;
    },
    unexpected: 'Logout failed',
    unexpectedKey: UserFacingErrorKeys.logoutFailed,
  );

  Future<Either<ApiFailure, int>> removeDevice({
    required String accessKey,
    required String deviceId,
  }) => _operation(
    () async => (await _backend.premiumRemoveDevice(
      deviceId: deviceId,
      credentials: await _credentials(accessKey: accessKey),
    )).value,
    unexpected: 'Failed to remove device',
    unexpectedKey: UserFacingErrorKeys.removeDevice,
  );

  Future<Either<ApiFailure, List<PremiumServer>>> fetchServers(
    String accessKey,
  ) => _operation(
    () async => PremiumServerDto.listFromBackend(
      (await _backend.premiumServers(
        await _credentials(accessKey: accessKey),
      )).value,
    ),
    unexpected: 'Failed to load premium servers',
    unexpectedKey: UserFacingErrorKeys.loadPremiumServers,
  );
}
