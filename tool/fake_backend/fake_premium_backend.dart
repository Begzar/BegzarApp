import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// A base plan Play Console sells: its device count, the product and base
/// plan ids that name it, and the months it buys.
typedef FakePlan = ({
  int devices,
  String productId,
  String basePlanId,
  int months,
});

/// An account this backend has created, for the length of one run. It starts
/// with a second device already on it, so removing one can be tried.
class _Account {
  _Account({required this.email, required this.password});

  final String email;
  final String password;
  final Set<String> deviceIds = {FakePremiumBackend.otherDeviceId};

  /// Null until a purchase is granted: an account starts never having paid.
  DateTime? expiresAt;
}

/// The engine's backend operations, answered in memory, for running the app
/// on a device before the server has the sign-up and delete-account routes
/// (#340).
///
/// It answers the premium operations the way the real backend does, or, for
/// what the server does not have yet, the way #340 proposes. Accounts last
/// for one run; nothing is written anywhere. It also answers the version
/// catalog with a newer release on every channel, so the update row and the
/// dot on the settings tab can be tried (#398). Everything else fails as no
/// connection.
///
/// Reached only through `tool/fake_backend/main.dart`. A release build starts
/// from `lib/main.dart`, which never imports this.
class FakePremiumBackend implements BegzarBackend {
  /// The one code that confirms a sign-up.
  static const confirmationCode = '123456';

  /// A code that answers as expired, so that message can be reached.
  static const expiredCode = '000000';

  /// The device every account starts with besides the one signing up.
  static const otherDeviceId = 'fake-other-device';

  /// Every base plan Play Console sells, in display order, under the ids
  /// Console holds, so the real Play prices them as well as the fake one.
  ///
  /// The ids are copied rather than built from a pattern because two break
  /// it: three devices' quarterly and semiannual plans were remade with a
  /// `-new` suffix after going live with the wrong period, and five devices'
  /// monthly plan says `devices`.
  static const plans = <FakePlan>[
    (
      devices: 1,
      productId: 'premium_1_device',
      basePlanId: 'premium-1-device-monthly',
      months: 1,
    ),
    (
      devices: 1,
      productId: 'premium_1_device',
      basePlanId: 'premium-1-device-quarterly',
      months: 3,
    ),
    (
      devices: 1,
      productId: 'premium_1_device',
      basePlanId: 'premium-1-device-semiannual',
      months: 6,
    ),
    (
      devices: 1,
      productId: 'premium_1_device',
      basePlanId: 'premium-1-device-yearly',
      months: 12,
    ),
    (
      devices: 2,
      productId: 'premium_2_device',
      basePlanId: 'premium-2-device-monthly',
      months: 1,
    ),
    (
      devices: 2,
      productId: 'premium_2_device',
      basePlanId: 'premium-2-device-quarterly',
      months: 3,
    ),
    (
      devices: 2,
      productId: 'premium_2_device',
      basePlanId: 'premium-2-device-semiannual',
      months: 6,
    ),
    (
      devices: 2,
      productId: 'premium_2_device',
      basePlanId: 'premium-2-device-yearly',
      months: 12,
    ),
    (
      devices: 3,
      productId: 'premium_3_device',
      basePlanId: 'premium-3-device-monthly',
      months: 1,
    ),
    (
      devices: 3,
      productId: 'premium_3_device',
      basePlanId: 'premium-3-device-quarterly-new',
      months: 3,
    ),
    (
      devices: 3,
      productId: 'premium_3_device',
      basePlanId: 'premium-3-device-semiannual-new',
      months: 6,
    ),
    (
      devices: 3,
      productId: 'premium_3_device',
      basePlanId: 'premium-3-device-yearly',
      months: 12,
    ),
    (
      devices: 4,
      productId: 'premium_4_device',
      basePlanId: 'premium-4-device-monthly',
      months: 1,
    ),
    (
      devices: 4,
      productId: 'premium_4_device',
      basePlanId: 'premium-4-device-quarterly',
      months: 3,
    ),
    (
      devices: 4,
      productId: 'premium_4_device',
      basePlanId: 'premium-4-device-semiannual',
      months: 6,
    ),
    (
      devices: 4,
      productId: 'premium_4_device',
      basePlanId: 'premium-4-device-yearly',
      months: 12,
    ),
    (
      devices: 5,
      productId: 'premium_5_device',
      basePlanId: 'premium-5-devices-monthly',
      months: 1,
    ),
    (
      devices: 5,
      productId: 'premium_5_device',
      basePlanId: 'premium-5-device-quarterly',
      months: 3,
    ),
    (
      devices: 5,
      productId: 'premium_5_device',
      basePlanId: 'premium-5-device-semiannual',
      months: 6,
    ),
    (
      devices: 5,
      productId: 'premium_5_device',
      basePlanId: 'premium-5-device-yearly',
      months: 12,
    ),
  ];

  /// The release every channel offers: far enough ahead of any real build
  /// that the update row always shows.
  static const latestVersion = '99.0.0';

  /// The minimum every channel asks for, low enough that no build is forced.
  static const minimumVersion = '0.0.0';

  /// Where the update row sends the user.
  static const updatePage = 'https://example.com/';

  /// Every platform key `AppDistribution.catalogPlatform` can answer with.
  static const _catalogPlatforms = [
    'android',
    'ios',
    'windows',
    'macos',
    'linux',
  ];
  static const _resendAfterSeconds = 30;
  static const _maxDevices = 2;
  static const _purchaseTokenPrefix = 'fake-purchase';

  /// What a purchase the real Play made buys: the shortest period, since its
  /// token names no plan this backend can read.
  static const _realPlayMonths = 1;

  final Map<String, _Account> _accountsByEmail = {};
  final Map<String, _Account> _accountsByAccessKey = {};
  final Map<String, String> _pendingPasswordByEmail = {};
  final Set<String> _grantedTokens = {};
  int _issuedKeys = 0;

  /// The token the fake Play hands out for a purchase of [basePlanId].
  ///
  /// The real server learns what was bought by asking Google about the
  /// token; this one reads the base plan back out of it instead.
  static String purchaseTokenFor(String basePlanId, int serial) =>
      '$_purchaseTokenPrefix:$basePlanId:$serial';

  /// The months [token] bought, or null for a token no purchase could have.
  ///
  /// The fake Play writes the base plan into its tokens. The real Play's
  /// carry nothing readable, and the app reports no base plan beside them,
  /// so any other token buys [_realPlayMonths].
  static int? _monthsBoughtWith(String token) {
    final parts = token.split(':');
    if (parts.first != _purchaseTokenPrefix) {
      return token.isEmpty ? null : _realPlayMonths;
    }
    if (parts.length != 3) return null;
    return plans
        .where((plan) => plan.basePlanId == parts[1])
        .firstOrNull
        ?.months;
  }

  static String? _expireDateOf(_Account account) =>
      account.expiresAt?.toIso8601String();

  static const _absent = BackendException(
    BackendFailureKind.network,
    message: 'Not in the fake backend',
  );

  static BackendException _refused(
    int status,
    String message, [
    BackendRefusal? refusal,
  ]) => BackendException(
    BackendFailureKind.server,
    message: message,
    status: status,
    serverMessage: message,
    refusal: refusal,
  );

  static const _staleKey = 'Invalid credentials';

  _Account _accountFor(BackendPremiumCredentials credentials) {
    final account = _accountsByAccessKey[credentials.accessKey];
    if (account == null) {
      throw _refused(401, _staleKey, BackendRefusal.sessionCredentials);
    }
    return account;
  }

  static BackendAccount _accountOf(_Account account) => BackendAccount(
    username: account.email,
    expireDate: _expireDateOf(account),
    statusLabel: 'active',
  );

  /// Signs [account] in on [deviceId], the way signing in and a confirmed
  /// sign-up both do.
  BackendAnswer<BackendSession> _session(_Account account, String deviceId) {
    account.deviceIds.add(deviceId);
    _issuedKeys++;
    final accessKey = 'fake-key-$_issuedKeys';
    _accountsByAccessKey[accessKey] = account;
    return BackendAnswer(
      BackendSession(accessKey: accessKey, account: _accountOf(account)),
    );
  }

  @override
  Future<BackendAnswer<int?>> requestSignUpCode({
    required String email,
    required String password,
    required BackendPremiumCredentials credentials,
  }) async {
    if (_accountsByEmail.containsKey(email)) {
      throw _refused(422, 'email_taken', BackendRefusal.emailTaken);
    }
    _pendingPasswordByEmail[email] = password;
    return const BackendAnswer(_resendAfterSeconds);
  }

  @override
  Future<BackendAnswer<int?>> resendSignUpCode({
    required String email,
    required BackendPremiumCredentials credentials,
  }) async => const BackendAnswer(_resendAfterSeconds);

  @override
  Future<BackendAnswer<BackendSession>> confirmSignUp({
    required String email,
    required String code,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) async {
    final password = _pendingPasswordByEmail[email];
    if (code == expiredCode) {
      throw _refused(422, 'code_expired', BackendRefusal.codeExpired);
    }
    if (password == null || code != confirmationCode) {
      throw _refused(422, 'invalid_code', BackendRefusal.codeInvalid);
    }
    _pendingPasswordByEmail.remove(email);
    final account = _Account(email: email, password: password);
    _accountsByEmail[email] = account;
    return _session(account, credentials.deviceId);
  }

  @override
  Future<BackendAnswer<BackendSession>> premiumSignIn({
    required String username,
    required String password,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) async {
    final account = _accountsByEmail[username];
    if (account == null || account.password != password) {
      throw _refused(
        401,
        'Invalid username or password',
        BackendRefusal.invalidCredentials,
      );
    }
    return _session(account, credentials.deviceId);
  }

  @override
  Future<BackendAnswer<BackendAccountData>> premiumAccount(
    BackendPremiumCredentials credentials,
  ) async {
    final account = _accountFor(credentials);
    return BackendAnswer(
      BackendAccountData(
        account: _accountOf(account),
        rosterKnown: true,
        maxDevices: _maxDevices,
        devices: [
          for (final deviceId in account.deviceIds)
            BackendDevice(
              deviceId: deviceId,
              deviceName: deviceId == otherDeviceId
                  ? 'Other fake device'
                  : 'Fake device',
            ),
        ],
      ),
    );
  }

  @override
  Future<BackendAnswer<void>> premiumSignOut(
    BackendPremiumCredentials credentials,
  ) async => const BackendAnswer(null);

  @override
  Future<BackendAnswer<int>> premiumRemoveDevice({
    required String deviceId,
    required BackendPremiumCredentials credentials,
  }) async {
    final account = _accountFor(credentials);
    account.deviceIds.remove(deviceId);
    return BackendAnswer(account.deviceIds.length);
  }

  /// An entitled account asks for its servers; this backend has none.
  @override
  Future<BackendAnswer<List<BackendPremiumServer>>> premiumServers(
    BackendPremiumCredentials credentials,
  ) async => const BackendAnswer([]);

  @override
  Future<BackendAnswer<void>> deleteAccount({
    required String password,
    required BackendPremiumCredentials credentials,
  }) async {
    final account = _accountFor(credentials);
    if (account.password != password) {
      throw _refused(422, 'invalid_password', BackendRefusal.wrongPassword);
    }
    _accountsByEmail.remove(account.email);
    _accountsByAccessKey.removeWhere((_, held) => held == account);
    return const BackendAnswer(null);
  }

  @override
  Future<BackendAnswer<List<BackendPlan>>> premiumPlans() async =>
      BackendAnswer([
        for (final plan in plans)
          BackendPlan(
            devices: plan.devices,
            productId: plan.productId,
            basePlanId: plan.basePlanId,
          ),
      ]);

  /// Grants the months the purchase bought, from today or from the expiry
  /// still ahead. A token already granted is answered without granting it
  /// again, because the app reports until it has acknowledged.
  @override
  Future<BackendAnswer<void>> reportPlayPurchase({
    required String productId,
    required String purchaseToken,
    required BackendPremiumCredentials credentials,
  }) async {
    final account = _accountFor(credentials);
    final months = _monthsBoughtWith(purchaseToken);
    if (months == null) throw _refused(422, 'invalid_purchase');

    if (_grantedTokens.add(purchaseToken)) {
      final now = DateTime.now();
      final current = account.expiresAt;
      final from = current != null && current.isAfter(now) ? current : now;
      account.expiresAt = DateTime(
        from.year,
        from.month + months,
        from.day,
        from.hour,
        from.minute,
      );
    }
    return const BackendAnswer(null);
  }

  /// The version catalog with a latest release filled in, which the real
  /// server does not send yet: every platform and channel is offered
  /// [latestVersion] and forced to nothing.
  @override
  Future<BackendAnswer<BackendVersionCatalog?>> appVersionCatalog() async =>
      BackendAnswer(
        BackendVersionCatalog({
          for (final platform in _catalogPlatforms)
            platform: {
              for (final source in AppDistributionSource.values)
                source.apiKey: const BackendSourceRelease(
                  version: minimumVersion,
                  latestVersion: latestVersion,
                  url: updatePage,
                ),
            },
        }),
      );

  @override
  Future<BackendAnswer<String>> registerSession() async => throw _absent;

  @override
  Future<BackendAnswer<List<String>>> fetchFreeServers({
    required String sessionKey,
    required String deviceId,
  }) async => throw _absent;

  @override
  Future<BackendAnswer<List<BackendPromotion>>> fetchPromotions({
    required String sessionKey,
    required String deviceId,
  }) async => throw _absent;

  @override
  Future<BackendAnswer<String?>> lookupRegionCountry() async => throw _absent;

  @override
  Future<BackendAnswer<BackendExitReading>> lookupExit({
    String viaSocks5 = '',
  }) async => throw _absent;
}
