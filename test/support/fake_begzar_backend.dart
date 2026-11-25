import 'package:begzar_engine/begzar_engine.dart';

/// A [BegzarBackend] a test scripts one operation at a time. An operation it
/// was not given fails as no connection, so a test only names what it reads.
class FakeBegzarBackend implements BegzarBackend {
  FakeBegzarBackend({
    this.onRegisterSession,
    this.onFetchFreeServers,
    this.onFetchPromotions,
    this.onAppVersionCatalog,
    this.onLookupRegionCountry,
    this.onLookupExit,
    this.onPremiumSignIn,
    this.onPremiumAccount,
    this.onPremiumSignOut,
    this.onPremiumRemoveDevice,
    this.onPremiumServers,
    this.onRequestSignUpCode,
    this.onResendSignUpCode,
    this.onConfirmSignUp,
    this.onDeleteAccount,
    this.onPremiumPlans,
    this.onReportPlayPurchase,
  });

  final Future<BackendAnswer<String>> Function()? onRegisterSession;
  final Future<BackendAnswer<List<String>>> Function(
    String sessionKey,
    String deviceId,
  )?
  onFetchFreeServers;
  final Future<BackendAnswer<List<BackendPromotion>>> Function(
    String sessionKey,
    String deviceId,
  )?
  onFetchPromotions;
  final Future<BackendAnswer<BackendVersionCatalog?>> Function()?
  onAppVersionCatalog;
  final Future<BackendAnswer<String?>> Function()? onLookupRegionCountry;
  final Future<BackendAnswer<BackendExitReading>> Function(String viaSocks5)?
  onLookupExit;

  final Future<BackendAnswer<BackendSession>> Function(
    String username,
    String password,
    String deviceName,
    BackendPremiumCredentials credentials,
  )?
  onPremiumSignIn;
  final Future<BackendAnswer<BackendAccountData>> Function(
    BackendPremiumCredentials credentials,
  )?
  onPremiumAccount;
  final Future<BackendAnswer<void>> Function(
    BackendPremiumCredentials credentials,
  )?
  onPremiumSignOut;
  final Future<BackendAnswer<int>> Function(
    String deviceId,
    BackendPremiumCredentials credentials,
  )?
  onPremiumRemoveDevice;
  final Future<BackendAnswer<List<BackendPremiumServer>>> Function(
    BackendPremiumCredentials credentials,
  )?
  onPremiumServers;

  final Future<BackendAnswer<int?>> Function(
    String email,
    String password,
    BackendPremiumCredentials credentials,
  )?
  onRequestSignUpCode;
  final Future<BackendAnswer<int?>> Function(
    String email,
    BackendPremiumCredentials credentials,
  )?
  onResendSignUpCode;
  final Future<BackendAnswer<BackendSession>> Function(
    String email,
    String code,
    String deviceName,
    BackendPremiumCredentials credentials,
  )?
  onConfirmSignUp;
  final Future<BackendAnswer<void>> Function(
    String password,
    BackendPremiumCredentials credentials,
  )?
  onDeleteAccount;
  final Future<BackendAnswer<List<BackendPlan>>> Function()? onPremiumPlans;
  final Future<BackendAnswer<void>> Function(
    String productId,
    String purchaseToken,
    BackendPremiumCredentials credentials,
  )?
  onReportPlayPurchase;

  /// Every operation asked for, by name, in order.
  final List<String> calls = [];

  static const unscripted = BackendException(
    BackendFailureKind.network,
    message: 'not scripted',
  );

  Future<T> _run<T>(String op, Future<T> Function()? answer) {
    calls.add(op);
    if (answer == null) throw unscripted;
    return answer();
  }

  @override
  Future<BackendAnswer<String>> registerSession() =>
      _run('registerSession', onRegisterSession);

  @override
  Future<BackendAnswer<List<String>>> fetchFreeServers({
    required String sessionKey,
    required String deviceId,
  }) => _run(
    'fetchFreeServers',
    onFetchFreeServers == null
        ? null
        : () => onFetchFreeServers!(sessionKey, deviceId),
  );

  @override
  Future<BackendAnswer<List<BackendPromotion>>> fetchPromotions({
    required String sessionKey,
    required String deviceId,
  }) => _run(
    'fetchPromotions',
    onFetchPromotions == null
        ? null
        : () => onFetchPromotions!(sessionKey, deviceId),
  );

  @override
  Future<BackendAnswer<BackendVersionCatalog?>> appVersionCatalog() =>
      _run('appVersionCatalog', onAppVersionCatalog);

  @override
  Future<BackendAnswer<String?>> lookupRegionCountry() =>
      _run('lookupRegionCountry', onLookupRegionCountry);

  @override
  Future<BackendAnswer<BackendExitReading>> lookupExit({
    String viaSocks5 = '',
  }) => _run(
    'lookupExit',
    onLookupExit == null ? null : () => onLookupExit!(viaSocks5),
  );

  @override
  Future<BackendAnswer<BackendSession>> premiumSignIn({
    required String username,
    required String password,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'premiumSignIn',
    onPremiumSignIn == null
        ? null
        : () => onPremiumSignIn!(username, password, deviceName, credentials),
  );

  @override
  Future<BackendAnswer<BackendAccountData>> premiumAccount(
    BackendPremiumCredentials credentials,
  ) => _run(
    'premiumAccount',
    onPremiumAccount == null ? null : () => onPremiumAccount!(credentials),
  );

  @override
  Future<BackendAnswer<void>> premiumSignOut(
    BackendPremiumCredentials credentials,
  ) => _run(
    'premiumSignOut',
    onPremiumSignOut == null ? null : () => onPremiumSignOut!(credentials),
  );

  @override
  Future<BackendAnswer<int>> premiumRemoveDevice({
    required String deviceId,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'premiumRemoveDevice',
    onPremiumRemoveDevice == null
        ? null
        : () => onPremiumRemoveDevice!(deviceId, credentials),
  );

  @override
  Future<BackendAnswer<List<BackendPremiumServer>>> premiumServers(
    BackendPremiumCredentials credentials,
  ) => _run(
    'premiumServers',
    onPremiumServers == null ? null : () => onPremiumServers!(credentials),
  );

  @override
  Future<BackendAnswer<int?>> requestSignUpCode({
    required String email,
    required String password,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'requestSignUpCode',
    onRequestSignUpCode == null
        ? null
        : () => onRequestSignUpCode!(email, password, credentials),
  );

  @override
  Future<BackendAnswer<int?>> resendSignUpCode({
    required String email,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'resendSignUpCode',
    onResendSignUpCode == null
        ? null
        : () => onResendSignUpCode!(email, credentials),
  );

  @override
  Future<BackendAnswer<BackendSession>> confirmSignUp({
    required String email,
    required String code,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'confirmSignUp',
    onConfirmSignUp == null
        ? null
        : () => onConfirmSignUp!(email, code, deviceName, credentials),
  );

  @override
  Future<BackendAnswer<void>> deleteAccount({
    required String password,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'deleteAccount',
    onDeleteAccount == null
        ? null
        : () => onDeleteAccount!(password, credentials),
  );

  @override
  Future<BackendAnswer<List<BackendPlan>>> premiumPlans() =>
      _run('premiumPlans', onPremiumPlans);

  @override
  Future<BackendAnswer<void>> reportPlayPurchase({
    required String productId,
    required String purchaseToken,
    required BackendPremiumCredentials credentials,
  }) => _run(
    'reportPlayPurchase',
    onReportPlayPurchase == null
        ? null
        : () => onReportPlayPurchase!(productId, purchaseToken, credentials),
  );
}
