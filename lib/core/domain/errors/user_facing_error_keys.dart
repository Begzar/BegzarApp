/// Canonical l10n keys for user-visible errors (no server URLs or raw API text).
///
/// These are the vocabulary a `Failure` answers in, so they sit in the domain
/// layer where a module's own failure types can reach them. Turning a key into
/// a sentence is a presentation job and lives in
/// `core/errors/user_facing_errors.dart`.
library;

abstract final class UserFacingErrorKeys {
  static const accessDenied = 'errAccessDenied';
  static const noResponse = 'errNoResponse';
  static const noStorageAccess = 'errNoStorageAccess';
  static const rateLimit = 'errRateLimit';
  static const noWorkingConfig = 'errNoWorkingConfig';
  static const connectionTimeout = 'errConnectionTimeout';
  static const networkError = 'errNetworkError';
  static const noConfigsFromServer = 'errNoConfigsFromServer';
  static const noConfigsAvailable = 'errNoConfigsAvailable';
  static const apiV2Unavailable = 'errApiV2Unavailable';
  static const premiumApiUnavailable = 'errPremiumApiUnavailable';
  static const proxyTestFailed = 'errProxyTestFailed';
  static const invalidConfig = 'errInvalidConfig';
  static const connectionFailed = 'errConnectionFailed';
  static const unauthorized = 'errUnauthorized';
  static const forbidden = 'errForbidden';
  static const deviceInitFailed = 'errDeviceInitFailed';
  static const fetchConfigsFailed = 'errFetchConfigsFailed';
  static const secureConnectionFailed = 'errSecureConnectionFailed';
  static const clockSkew = 'errClockSkew';
  static const requestUnverified = 'errRequestUnverified';
  static const replayDetected = 'errReplayDetected';
  static const ipBlocked = 'errIpBlocked';
  static const missingSession = 'errMissingSession';
  static const invalidCredentials = 'errInvalidCredentials';
  static const sessionCredentials = 'errSessionCredentials';
  static const deviceLimit = 'errDeviceLimit';
  static const deviceNotRegistered = 'errDeviceNotRegistered';

  // The same fact as [deviceNotRegistered], told to a reader the app has
  // already signed out because the seat was taken away. Only the advice
  // differs: there is no sign-out left to press.
  static const deviceRemoved = 'errDeviceRemoved';
  static const accountDisabled = 'errAccountDisabled';
  static const accountExpired = 'errAccountExpired';
  static const subscriptionRequired = 'errSubscriptionRequired';
  static const credentialsRequired = 'errCredentialsRequired';
  static const refreshFailed = 'errRefreshFailed';
  static const signOutFailed = 'errSignOutFailed';
  static const locationUnavailable = 'errLocationUnavailable';
  static const engineLogUnavailable = 'errEngineLogUnavailable';

  // A build made without the private engine, on the open stand-in: nothing
  // that needs the engine can work, and saying so beats "no connection".
  static const engineMissing = 'errEngineMissing';

  // Named for the premium call that failed rather than for the cause, because
  // the cause is exactly what is unknown when one of these is chosen: they are
  // the vocabulary for a throw the call site did not anticipate. Saying which
  // call it was is the most a user can be told without guessing.
  static const loginFailed = 'errLoginFailed';
  static const loadSubscription = 'errLoadSubscription';
  static const logoutFailed = 'errLogoutFailed';
  static const sessionNotFound = 'errSessionNotFound';
  static const loadDevices = 'errLoadDevices';
  static const loadPremiumServers = 'errLoadPremiumServers';
  static const removeDevice = 'errRemoveDevice';

  // Creating and deleting an account in the app. The first five are what the
  // server says when it refuses; [passwordRequired] is refused before asking;
  // the last three name the call that failed, like the group above.
  static const emailTaken = 'errEmailTaken';
  static const codeInvalid = 'errCodeInvalid';
  static const codeExpired = 'errCodeExpired';
  static const tooManyAttempts = 'errTooManyAttempts';
  static const wrongPassword = 'errWrongPassword';
  static const passwordRequired = 'errPasswordRequired';
  static const signUpFailed = 'errSignUpFailed';
  static const verifyFailed = 'errVerifyFailed';
  static const deleteAccountFailed = 'errDeleteAccountFailed';

  // Selling premium through Google Play on a Play build.
  static const plansUnavailable = 'errPlansUnavailable';
  static const purchaseFailed = 'errPurchaseFailed';
  static const playAlreadyOwned = 'errPlayAlreadyOwned';

  // Tunnel mode on Windows. The first is the admin prompt the user declined,
  // the second a tunnel that could not be brought up, and the last one that
  // stopped while connected.
  static const elevationDeclined = 'errElevationDeclined';
  static const tunnelUnavailable = 'errTunnelUnavailable';
  static const tunnelStopped = 'errTunnelStopped';

  static const all = {
    accessDenied,
    noResponse,
    noStorageAccess,
    rateLimit,
    noWorkingConfig,
    connectionTimeout,
    networkError,
    noConfigsFromServer,
    noConfigsAvailable,
    apiV2Unavailable,
    premiumApiUnavailable,
    proxyTestFailed,
    invalidConfig,
    connectionFailed,
    unauthorized,
    forbidden,
    deviceInitFailed,
    fetchConfigsFailed,
    secureConnectionFailed,
    clockSkew,
    requestUnverified,
    replayDetected,
    ipBlocked,
    missingSession,
    invalidCredentials,
    sessionCredentials,
    deviceLimit,
    deviceNotRegistered,
    deviceRemoved,
    accountDisabled,
    accountExpired,
    subscriptionRequired,
    credentialsRequired,
    refreshFailed,
    signOutFailed,
    locationUnavailable,
    engineLogUnavailable,
    engineMissing,
    loginFailed,
    loadSubscription,
    logoutFailed,
    sessionNotFound,
    loadDevices,
    loadPremiumServers,
    removeDevice,
    emailTaken,
    codeInvalid,
    codeExpired,
    tooManyAttempts,
    wrongPassword,
    passwordRequired,
    signUpFailed,
    verifyFailed,
    deleteAccountFailed,
    plansUnavailable,
    purchaseFailed,
    playAlreadyOwned,
    elevationDeclined,
    tunnelUnavailable,
    tunnelStopped,
  };
}

bool isUserFacingErrorKey(String? value) {
  if (value == null) return false;
  return UserFacingErrorKeys.all.contains(value.trim());
}
