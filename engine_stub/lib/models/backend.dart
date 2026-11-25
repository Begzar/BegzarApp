// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// The app's backend, as operations.
///
/// The engine owns everything between an operation and the backend; what
/// comes back is a typed answer, or a [BackendException] saying which of the
/// app's failures it was. The app keeps its own credentials and hands them
/// in, so nothing here stores anything.
abstract interface class BegzarBackend {
  /// A session key for this device, which the free tier's operations take.
  Future<BackendAnswer<String>> registerSession();

  /// The free tier's servers, as share links in the backend's order, under
  /// [sessionKey].
  Future<BackendAnswer<List<String>>> fetchFreeServers({
    required String sessionKey,
    required String deviceId,
  });

  /// The promotions under [sessionKey], in the backend's order. One that does
  /// not read fails the list.
  Future<BackendAnswer<List<BackendPromotion>>> fetchPromotions({
    required String sessionKey,
    required String deviceId,
  });

  /// The release catalog, or null for an answer with nothing usable in it.
  Future<BackendAnswer<BackendVersionCatalog?>> appVersionCatalog();

  /// The country the backend places this device's address in, or null when
  /// it names none.
  Future<BackendAnswer<String?>> lookupRegionCountry();

  /// Where the backend places the address this device reaches it from:
  /// through [viaSocks5], the tunnel's SOCKS5 port as `host:port`, while one
  /// is up. Asked once, never retried.
  Future<BackendAnswer<BackendExitReading>> lookupExit({String viaSocks5 = ''});

  /// Signs in with a username and password, binding the account to this
  /// device under [deviceName]. [credentials] carry no access key yet.
  Future<BackendAnswer<BackendSession>> premiumSignIn({
    required String username,
    required String password,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  });

  /// The account behind the access key and the devices it is signed in on.
  Future<BackendAnswer<BackendAccountData>> premiumAccount(
    BackendPremiumCredentials credentials,
  );

  /// Signs this device out of the account.
  Future<BackendAnswer<void>> premiumSignOut(
    BackendPremiumCredentials credentials,
  );

  /// Frees the seat [deviceId] holds, answering with how many are still
  /// taken.
  Future<BackendAnswer<int>> premiumRemoveDevice({
    required String deviceId,
    required BackendPremiumCredentials credentials,
  });

  /// The servers the account may use, in the backend's order.
  Future<BackendAnswer<List<BackendPremiumServer>>> premiumServers(
    BackendPremiumCredentials credentials,
  );

  /// Starts an account and has a code emailed. The answer is how many seconds
  /// the backend asks the app to wait before asking again, when it named a
  /// whole number. [credentials] must carry the device's session key.
  Future<BackendAnswer<int?>> requestSignUpCode({
    required String email,
    required String password,
    required BackendPremiumCredentials credentials,
  });

  /// Emails the code again; answers as [requestSignUpCode].
  Future<BackendAnswer<int?>> resendSignUpCode({
    required String email,
    required BackendPremiumCredentials credentials,
  });

  /// Confirms the emailed code, signing the new account in on this device.
  /// Sent once.
  Future<BackendAnswer<BackendSession>> confirmSignUp({
    required String email,
    required String code,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  });

  /// Deletes the account, its password asked again. Sent once.
  Future<BackendAnswer<void>> deleteAccount({
    required String password,
    required BackendPremiumCredentials credentials,
  });

  /// The plans on sale, in the backend's order, read signed out.
  Future<BackendAnswer<List<BackendPlan>>> premiumPlans();

  /// Reports a purchase Google Play made, for the backend to grant.
  Future<BackendAnswer<void>> reportPlayPurchase({
    required String productId,
    required String purchaseToken,
    required BackendPremiumCredentials credentials,
  });
}

/// One plan the paywall sells.
class BackendPlan {
  const BackendPlan({
    required this.devices,
    required this.productId,
    required this.basePlanId,
  });

  final int devices;
  final String productId;
  final String basePlanId;
}

/// What a premium call is made with, all of it the app's own: the device's
/// session key when it has one, the account's access key, and this install's
/// id.
class BackendPremiumCredentials {
  const BackendPremiumCredentials({
    this.sessionKey = '',
    this.accessKey = '',
    required this.deviceId,
  });

  final String sessionKey;
  final String accessKey;
  final String deviceId;
}

/// A premium account. A null field is one the backend did not name.
class BackendAccount {
  const BackendAccount({
    required this.username,
    this.email,
    this.expireDate,
    this.statusLabel,
  });

  final String username;
  final String? email;
  final String? expireDate;

  /// "true", "false" or the backend's word in lower case.
  final String? statusLabel;
}

/// A signed-in account and the key its calls are made with.
class BackendSession {
  const BackendSession({required this.accessKey, required this.account});

  final String accessKey;
  final BackendAccount account;
}

/// One device an account is signed in on, as the backend listed it.
class BackendDevice {
  const BackendDevice(
      {required this.deviceId, this.deviceName, this.loggedInAt});

  /// Empty when the backend named none.
  final String deviceId;
  final String? deviceName;

  /// As the backend wrote it.
  final String? loggedInAt;
}

/// An account and its devices.
class BackendAccountData {
  const BackendAccountData({
    required this.account,
    required this.rosterKnown,
    this.devices = const [],
    this.maxDevices,
    this.activeDevices,
  });

  final BackendAccount account;

  /// False when the answer carried no device list at all: silence, not an
  /// empty roster.
  final bool rosterKnown;
  final List<BackendDevice> devices;
  final int? maxDevices;
  final int? activeDevices;
}

/// A premium server and its configs. A null field is one not named.
class BackendPremiumServer {
  const BackendPremiumServer({
    required this.id,
    this.name,
    this.icon,
    this.configs = const [],
  });

  final int id;
  final String? name;
  final String? icon;
  final List<BackendPremiumConfig> configs;
}

/// One of a premium server's configs.
class BackendPremiumConfig {
  const BackendPremiumConfig({required this.id, this.name, required this.url});

  final int id;
  final String? name;

  /// Empty when the backend named none.
  final String url;
}

/// One promotion. Dates are the backend's text, for the app's own parser.
class BackendPromotion {
  const BackendPromotion({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.clickUrl,
    required this.position,
    required this.priority,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.action,
    this.buttonColor,
    this.duration,
    this.byLanguage = const {},
  });

  final int id;
  final String title;
  final String description;
  final String bannerUrl;
  final String clickUrl;
  final String position;
  final int priority;
  final String startDate;
  final String endDate;
  final String type;

  /// Null when the backend sent none.
  final String? action;
  final String? buttonColor;

  /// Seconds, truncated; null when the backend sent no number.
  final int? duration;

  /// The same promotion per language, in language order.
  final Map<String, BackendPromotion> byLanguage;
}

/// Every platform's distribution channels.
class BackendVersionCatalog {
  const BackendVersionCatalog(this.platforms);

  /// By platform, then by channel.
  final Map<String, Map<String, BackendSourceRelease>> platforms;
}

/// What one channel offers a platform.
class BackendSourceRelease {
  const BackendSourceRelease({
    required this.version,
    this.latestVersion,
    this.url,
  });

  /// The oldest release still allowed to connect.
  final String version;
  final String? latestVersion;
  final String? url;
}

/// Where the backend places an address. A null field is one it did not name.
class BackendExitReading {
  const BackendExitReading({this.ip, this.country, this.countryCode});

  final String? ip;
  final String? country;
  final String? countryCode;
}

/// A backend operation's result, with the newest release the backend named
/// on the way.
class BackendAnswer<T> {
  const BackendAnswer(this.value, {this.releaseHint});

  final T value;
  final BackendReleaseHint? releaseHint;
}

/// The newest release the backend named for this platform. A null field is
/// one it did not name.
class BackendReleaseHint {
  const BackendReleaseHint({this.version, this.updateUrl});

  final String? version;
  final String? updateUrl;
}

/// Which of the app's failures an operation ended in.
enum BackendFailureKind {
  /// No answer: the connection failed, was refused or was cancelled.
  network,

  /// No answer in time.
  timeout,

  /// The server's key was not the one expected.
  pinning,

  /// Too many requests.
  rateLimit,

  /// The backend answered and refused.
  server,

  /// The answer could not be opened.
  payload,

  /// The answer opened to nothing.
  noConfigs,

  /// The answer was not what the operation expects.
  unexpected,

  /// The engine is not part of this build.
  engineMissing,
}

/// Which of the backend's known refusals an answer was.
enum BackendRefusal {
  clockSkew,
  requestUnverified,
  replayDetected,
  ipBlocked,
  missingSession,
  invalidCredentials,
  sessionCredentials,
  deviceNotRegistered,
  accountDisabled,
  accountExpired,
  emailTaken,
  codeInvalid,
  codeExpired,
  tooManyAttempts,
  wrongPassword,
  deviceLimit,
}

/// A backend operation that did not succeed.
class BackendException implements Exception {
  const BackendException(
    this.kind, {
    this.message = '',
    this.status,
    this.serverMessage,
    this.refusal,
    this.retryAfterSeconds,
    this.releaseHint,
  });

  final BackendFailureKind kind;

  /// Developer-facing. For [BackendFailureKind.server] the app's last-resort
  /// message key is read from it, as it always was.
  final String message;

  /// The HTTP status, when the backend answered.
  final int? status;

  /// The backend's own account of a refusal. Developer-facing only.
  final String? serverMessage;

  final BackendRefusal? refusal;
  final int? retryAfterSeconds;

  /// The newest release the backend named, even in a refusal.
  final BackendReleaseHint? releaseHint;

  @override
  String toString() => 'BackendException(${kind.name}, status: $status)';
}
