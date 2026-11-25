import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:begzar/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on AppLocalizations {
  String connectionTitle(String status) => switch (status) {
    'connecting' => conn_connecting,
    'disconnecting' => conn_disconnecting,
    'connected' => conn_connected,
    'error' => conn_error,
    'ready' => conn_ready,
    _ => conn_ready,
  };

  /// The second line under the dial, for every state that says it in words.
  ///
  /// Connected is deliberately absent: its second line is the elapsed clock,
  /// which is written from the connection itself rather than translated.
  ///
  /// The lines that ask for a press say click on a desktop and tap on a
  /// phone; see [_clicks].
  String connectionSubtitle(String status, TargetPlatform platform) {
    final clicks = _clicks(platform);

    return switch (status) {
      'connecting' => clicks ? connSub_connectingDesktop : connSub_connecting,
      'disconnecting' => connSub_disconnecting,
      'error' => clicks ? connSub_errorDesktop : connSub_error,
      'ready' => clicks ? connSub_readyDesktop : connSub_ready,
      _ => clicks ? connSub_readyDesktop : connSub_ready,
    };
  }

  /// The home server row's hint while no server is chosen, which asks for a
  /// press the way the dial does.
  String serverRowChooseHintFor(TargetPlatform platform) =>
      _clicks(platform) ? serverRowChooseHintDesktop : serverRowChooseHint;

  /// The ping line before anything has been measured, which is pressed to
  /// measure it.
  String tapToTestFor(TargetPlatform platform) =>
      _clicks(platform) ? tapToTestDesktop : tapToTest;

  /// The ping line after a measurement failed, which is pressed to measure
  /// again.
  String tapToRetryFor(TargetPlatform platform) =>
      _clicks(platform) ? tapToRetryDesktop : tapToRetry;

  /// The premium list's subtitle while connected, where pressing the
  /// connected server drops the tunnel.
  String premiumServersConnectedHintFor(TargetPlatform platform) =>
      _clicks(platform)
      ? premiumServersConnectedHintDesktop
      : premiumServersConnectedHint;

  /// The account card's line for a signed-in account that has never paid,
  /// which sends the user to the Refresh button once they have.
  String premiumNoSubscriptionHintFor(TargetPlatform platform) =>
      _clicks(platform)
      ? premiumNoSubscriptionHintDesktop
      : premiumNoSubscriptionHint;

  /// Whether a mouse rather than a finger reaches the controls on
  /// [platform], so a line asking for a press says click rather than tap.
  /// The switch names every platform, so a new one is a compile error here
  /// rather than a guess.
  static bool _clicks(TargetPlatform platform) => switch (platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };

  String translateUserStatus(String? status) {
    if (status == null || status.trim().isEmpty) return unknown;
    final normalized = status.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return userStatusActive;
    }
    if (normalized == 'false' || normalized == '0') {
      return userStatusInactive;
    }
    return switch (normalized) {
      'active' || 'enabled' => userStatusActive,
      'expired' => userStatusExpired,
      'inactive' => userStatusInactive,
      'disabled' => userStatusDisabled,
      'suspended' => userStatusSuspended,
      'banned' => userStatusBanned,
      _ => status,
    };
  }

  String? errorHint(String key, {int? retryAfterSeconds}) {
    if (key == UserFacingErrorKeys.rateLimit &&
        retryAfterSeconds != null &&
        retryAfterSeconds > 0) {
      return errRateLimitWait(retryAfterSeconds);
    }
    return switch (key) {
      UserFacingErrorKeys.clockSkew => errClockSkewHint,
      UserFacingErrorKeys.requestUnverified => errRequestUnverifiedHint,
      UserFacingErrorKeys.replayDetected => errReplayDetectedHint,
      UserFacingErrorKeys.ipBlocked => errIpBlockedHint,
      UserFacingErrorKeys.missingSession => errMissingSessionHint,
      UserFacingErrorKeys.deviceInitFailed => errDeviceInitFailedHint,
      UserFacingErrorKeys.invalidCredentials => errInvalidCredentialsHint,
      UserFacingErrorKeys.deviceLimit => errDeviceLimitHint,
      UserFacingErrorKeys.deviceNotRegistered => errDeviceNotRegisteredHint,
      // Reuses a sentence every locale already carries, which says exactly
      // what a device that was signed out for it has left to do.
      UserFacingErrorKeys.deviceRemoved => errSessionCredentials,
      UserFacingErrorKeys.accountDisabled => errAccountDisabledHint,
      UserFacingErrorKeys.accountExpired => errAccountExpiredHint,
      UserFacingErrorKeys.rateLimit => errRateLimitHint,
      UserFacingErrorKeys.sessionCredentials => errSessionCredentialsHint,
      _ => null,
    };
  }

  String translateError(String? message) {
    final key = isUserFacingErrorKey(message)
        ? message!.trim()
        : resolveUserFacingErrorKey(message);
    return switch (key) {
      UserFacingErrorKeys.accessDenied => errAccessDenied,
      UserFacingErrorKeys.noResponse => errNoResponse,
      UserFacingErrorKeys.noStorageAccess => errNoStorageAccess,
      UserFacingErrorKeys.rateLimit => errRateLimit,
      UserFacingErrorKeys.noWorkingConfig => errNoWorkingConfig,
      UserFacingErrorKeys.connectionTimeout => errConnectionTimeout,
      UserFacingErrorKeys.networkError => errNetworkError,
      UserFacingErrorKeys.noConfigsFromServer => errNoConfigsFromServer,
      UserFacingErrorKeys.noConfigsAvailable => errNoConfigsAvailable,
      UserFacingErrorKeys.apiV2Unavailable => errApiV2Unavailable,
      UserFacingErrorKeys.premiumApiUnavailable => errPremiumApiUnavailable,
      UserFacingErrorKeys.proxyTestFailed => errProxyTestFailed,
      UserFacingErrorKeys.invalidConfig => errInvalidConfig,
      UserFacingErrorKeys.connectionFailed => errConnectionFailed,
      UserFacingErrorKeys.unauthorized => errUnauthorized,
      UserFacingErrorKeys.forbidden => errForbidden,
      UserFacingErrorKeys.deviceInitFailed => errDeviceInitFailed,
      UserFacingErrorKeys.fetchConfigsFailed => errFetchConfigsFailed,
      UserFacingErrorKeys.secureConnectionFailed => errSecureConnectionFailed,
      UserFacingErrorKeys.clockSkew => errClockSkew,
      UserFacingErrorKeys.requestUnverified => errRequestUnverified,
      UserFacingErrorKeys.replayDetected => errReplayDetected,
      UserFacingErrorKeys.ipBlocked => errIpBlocked,
      UserFacingErrorKeys.missingSession => errMissingSession,
      UserFacingErrorKeys.invalidCredentials => errInvalidCredentials,
      UserFacingErrorKeys.sessionCredentials => errSessionCredentials,
      UserFacingErrorKeys.deviceLimit => errDeviceLimit,
      UserFacingErrorKeys.deviceNotRegistered => errDeviceNotRegistered,
      UserFacingErrorKeys.deviceRemoved => errDeviceNotRegistered,
      UserFacingErrorKeys.accountDisabled => errAccountDisabled,
      UserFacingErrorKeys.accountExpired => errAccountExpired,
      UserFacingErrorKeys.subscriptionRequired => errSubscriptionRequired,
      UserFacingErrorKeys.credentialsRequired => errCredentialsRequired,
      UserFacingErrorKeys.refreshFailed => errRefreshFailed,
      UserFacingErrorKeys.signOutFailed => errSignOutFailed,
      // Reuses the string the location pill already shows, rather than adding
      // a fifth translation of the same sentence to every .arb file.
      UserFacingErrorKeys.locationUnavailable => locationUnavailable,
      UserFacingErrorKeys.engineLogUnavailable => errEngineLogUnavailable,
      UserFacingErrorKeys.engineMissing => errEngineMissing,
      UserFacingErrorKeys.loginFailed => errLoginFailed,
      UserFacingErrorKeys.loadSubscription => errLoadSubscription,
      UserFacingErrorKeys.logoutFailed => errLogoutFailed,
      UserFacingErrorKeys.sessionNotFound => errSessionNotFound,
      UserFacingErrorKeys.loadDevices => errLoadDevices,
      UserFacingErrorKeys.loadPremiumServers => errLoadPremiumServers,
      UserFacingErrorKeys.removeDevice => errRemoveDevice,
      UserFacingErrorKeys.emailTaken => errEmailTaken,
      UserFacingErrorKeys.codeInvalid => errCodeInvalid,
      UserFacingErrorKeys.codeExpired => errCodeExpired,
      UserFacingErrorKeys.tooManyAttempts => errTooManyAttempts,
      UserFacingErrorKeys.wrongPassword => errWrongPassword,
      UserFacingErrorKeys.passwordRequired => errPasswordRequired,
      UserFacingErrorKeys.signUpFailed => errSignUpFailed,
      UserFacingErrorKeys.verifyFailed => errVerifyFailed,
      UserFacingErrorKeys.deleteAccountFailed => errDeleteAccountFailed,
      UserFacingErrorKeys.plansUnavailable => errPlansUnavailable,
      UserFacingErrorKeys.purchaseFailed => errPurchaseFailed,
      UserFacingErrorKeys.playAlreadyOwned => errPlayAlreadyOwned,
      UserFacingErrorKeys.elevationDeclined => errElevationDeclined,
      UserFacingErrorKeys.tunnelUnavailable => errTunnelUnavailable,
      UserFacingErrorKeys.tunnelStopped => errTunnelStopped,
      _ => errConnectionFailed,
    };
  }
}

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
