// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'BEGZAR';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get premium => 'Premium';

  @override
  String get basic => 'Basic';

  @override
  String get unknown => '-';

  @override
  String get planPremium => 'Premium';

  @override
  String get planBasic => 'Basic';

  @override
  String get premiumDialogTitle => 'Premium Subscription';

  @override
  String get premiumDialogMessage =>
      'Sign in or purchase Premium to unlock premium server configs.';

  @override
  String get buyPremium => 'Buy Premium';

  @override
  String get subscriptionExpiredTitle => 'Subscription Expired';

  @override
  String get subscriptionExpiredMessage =>
      'Your Premium subscription has expired. Renew to continue using premium servers.';

  @override
  String get renewSubscription => 'Renew Subscription';

  @override
  String get accountInactiveTitle => 'Account Inactive';

  @override
  String get accountInactiveMessage =>
      'Your account has been deactivated. Please contact Telegram support.';

  @override
  String get otherVpnTurnedOff =>
      'Another VPN was connected on your device, so Begzar disconnected it.';

  @override
  String get otherVpnOnTitle => 'Another VPN Is On';

  @override
  String get otherVpnOnMessage =>
      'Another VPN is connected on this device, and Begzar can\'t turn it off. Turn it off in your device\'s VPN settings, then try again.';

  @override
  String get otherVpnContinueAnyway => 'Continue Anyway';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get accountInactiveSupportMessage =>
      'Hello, my Premium account has been deactivated and I need help.';

  @override
  String get premiumSupportMessage =>
      'Hello, I would like to purchase a Begzar Premium subscription.';

  @override
  String get conn_connecting => 'Connecting';

  @override
  String get conn_disconnecting => 'Disconnecting';

  @override
  String get conn_connected => 'Protected';

  @override
  String get conn_error => 'Couldn\'t connect';

  @override
  String get conn_ready => 'Not protected';

  @override
  String get connSub_connecting => 'Tap to cancel';

  @override
  String get connSub_connectingDesktop => 'Click to cancel';

  @override
  String get connSub_disconnecting => 'Closing the tunnel';

  @override
  String get connSub_error => 'Tap to try again';

  @override
  String get connSub_errorDesktop => 'Click to try again';

  @override
  String get connSub_ready => 'Tap to auto-connect';

  @override
  String get connSub_readyDesktop => 'Click to auto-connect';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String get tapToTest => 'Tap to test';

  @override
  String get tapToTestDesktop => 'Click to test';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String get tapToRetryDesktop => 'Click to retry';

  @override
  String pingMs(int ms) {
    final intl.NumberFormat msNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String msString = msNumberFormat.format(ms);

    return '${msString}ms';
  }

  @override
  String get pingExcellent => 'Excellent';

  @override
  String get pingGood => 'Good';

  @override
  String get pingFair => 'Fair';

  @override
  String get pingPoor => 'Poor';

  @override
  String get settingsCategoryApp => 'App';

  @override
  String get settingsCategoryGeneral => 'General';

  @override
  String get settingsCategoryConnection => 'Connection';

  @override
  String get settingsCategoryNetwork => 'Network';

  @override
  String get settingsCategoryExperimental => 'Experimental';

  @override
  String get experimentalTitle => 'Experimental settings';

  @override
  String get experimentalEnabled => 'Free connections use Cloudflare WARP';

  @override
  String get experimentalDisabled => 'Free connections use Begzar\'s servers';

  @override
  String get warpModeTitle => 'WARP mode';

  @override
  String get warpModeMasque => 'MASQUE';

  @override
  String get warpModeWarp => 'WireGuard';

  @override
  String get warpModeGool => 'WARP in WARP';

  @override
  String get warpModeMasquePsiphon => 'Psiphon over MASQUE';

  @override
  String get warpModePsiphon => 'Psiphon over WARP';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Change app language';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appRoutingTitle => 'App Routing';

  @override
  String get appRoutingSubtitleNone => 'Choose which apps use the VPN';

  @override
  String appRoutingSubtitleAllExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All except $countString apps',
      one: 'All except 1 app',
    );
    return '$_temp0';
  }

  @override
  String appRoutingSubtitleOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $countString apps',
      one: 'Only 1 app',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingNeedsVpn => 'Turn off Proxy Only Mode to route apps';

  @override
  String get appRoutingModeAllExcept => 'All apps use VPN, except…';

  @override
  String get appRoutingModeAllExceptHint =>
      'Everything goes through the VPN. Apps you pick go direct.';

  @override
  String get appRoutingModeOnly => 'Only some apps use VPN';

  @override
  String get appRoutingModeOnlyHint =>
      'Nothing goes through the VPN except the apps you pick. With none picked, every app does.';

  @override
  String get appRoutingPickAllExcept => 'Pick apps that skip the VPN';

  @override
  String get appRoutingPickOnly => 'Pick apps that use the VPN';

  @override
  String appRoutingThroughVpn(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString apps through VPN',
      one: '1 app through VPN',
    );
    return '$_temp0';
  }

  @override
  String appRoutingDirect(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString apps direct',
      one: '1 app direct',
    );
    return '$_temp0';
  }

  @override
  String get appRoutingTagVpn => 'VPN';

  @override
  String get appRoutingTagDirect => 'Direct';

  @override
  String get dnsServerTitle => 'DNS Server';

  @override
  String dnsServerCurrent(String dns) {
    return 'Current: $dns';
  }

  @override
  String get proxyOnlyTitle => 'Proxy Only Mode';

  @override
  String proxyOnlyEnabled(int port) {
    return 'Using SOCKS proxy on port $port';
  }

  @override
  String get proxyOnlyDisabled => 'Use proxy mode instead of VPN';

  @override
  String get connectionModeTunnel => 'Tunnel';

  @override
  String get connectionModeTunnelHint =>
      'Every app goes through Begzar. Windows asks for admin permission each time you connect.';

  @override
  String get connectionModeSystemProxy => 'System proxy';

  @override
  String connectionModeSystemProxyHint(int port) {
    return 'Apps that follow Windows proxy settings use 127.0.0.1:$port';
  }

  @override
  String get connectionModeProxyOnly => 'Proxy only';

  @override
  String connectionModeProxyOnlyHint(int port) {
    return 'Point apps at SOCKS port $port yourself';
  }

  @override
  String get bypassLanTitle => 'Bypass LAN';

  @override
  String get bypassLanEnabled => 'SOCKS listens on all interfaces (0.0.0.0)';

  @override
  String get bypassLanDisabled =>
      'Allow other devices on your network to use this proxy';

  @override
  String get bypassLanRequiresProxy =>
      'Enable Proxy Only Mode to use Bypass LAN';

  @override
  String get bypassLanRequiresProxyMode =>
      'Choose Proxy only to use Bypass LAN';

  @override
  String get bypassLanAddressesTitle => 'Device addresses';

  @override
  String get bypassLanNoAddresses => 'No LAN address found';

  @override
  String bypassLanEndpoint(String ip, int port) {
    return 'socks5://$ip:$port';
  }

  @override
  String get routingRulesTitle => 'Site & IP Rules';

  @override
  String get routingRulesSubtitle => 'Route or block sites and IPs';

  @override
  String routingRulesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString custom rules',
      one: '1 custom rule',
    );
    return '$_temp0';
  }

  @override
  String get routingRulesScreenTitle => 'Site & IP Rules';

  @override
  String get routingRulesHint =>
      'Custom rules apply on the next connection. Reconnect VPN to apply changes.';

  @override
  String get routingTabDirect => 'Direct';

  @override
  String get routingTabBlock => 'Block';

  @override
  String get routingTabProxy => 'Proxy';

  @override
  String get routingAddRule => 'Add Rule';

  @override
  String get routingEntryDomain => 'Domain';

  @override
  String get routingEntryIp => 'IP';

  @override
  String get routingDomainHint => 'example.com';

  @override
  String get routingIpHint => '10.0.0.0/8 or 8.8.8.8';

  @override
  String get routingInvalidInput => 'Invalid domain or IP address';

  @override
  String get routingEmptyDirect => 'No direct routes yet';

  @override
  String get routingAlreadyListed => 'That rule is already in the list';

  @override
  String get routingEmptyBlock => 'No blocked routes yet';

  @override
  String get routingEmptyProxy => 'No proxy routes yet';

  @override
  String get settingsInfoReconnect =>
      'Changes will apply after reconnecting VPN';

  @override
  String get dnsDialogTitle => 'DNS Server';

  @override
  String get dnsDialogPrompt => 'Enter DNS server IP address:';

  @override
  String get dnsDialogCommon => 'Common DNS servers:';

  @override
  String get dnsDialogInvalid => 'Enter an IP address, such as 8.8.8.8';

  @override
  String get languageDialogTitle => 'Select Language';

  @override
  String get languageChoiceHint => 'You can change this later in Settings';

  @override
  String get languageContinue => 'Continue';

  @override
  String dnsChipLabel(String label, String dns) {
    return '$label ($dns)';
  }

  @override
  String get dnsGoogle => 'Google';

  @override
  String get dnsCloudflare => 'Cloudflare';

  @override
  String get dnsLevel3 => 'Level3';

  @override
  String get dnsOpenDns => 'OpenDNS';

  @override
  String get clearAll => 'Clear All';

  @override
  String get searchAppsHint => 'Search apps...';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get noSearchResults => 'No results';

  @override
  String get premiumHeroTitle => 'Begzar Premium';

  @override
  String get premiumHeroSubtitle =>
      'Sign in to access premium servers and manage your subscription';

  @override
  String get signInToPremium => 'Sign in to Premium';

  @override
  String get usePremiumCredentials => 'Use your premium account credentials';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get emailOrUsername => 'Email or username';

  @override
  String get createAccountLink => 'No account yet? Create one';

  @override
  String get signInLink => 'Already have an account? Sign in';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountHint => 'We\'ll email you a code to confirm it';

  @override
  String get email => 'Email';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get createAccount => 'Create account';

  @override
  String get creatingAccount => 'Creating account...';

  @override
  String get signUpPrivacyNotice =>
      'By creating an account you accept the Privacy Policy';

  @override
  String get verifyEmailTitle => 'Check your email';

  @override
  String get verifyEmailHint => 'Enter the 6-digit code we sent to:';

  @override
  String get confirmationCode => 'Code';

  @override
  String get confirmCode => 'Confirm';

  @override
  String get confirmingCode => 'Confirming...';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendCodeIn(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Resend in $secondsString seconds',
      one: 'Resend in 1 second',
    );
    return '$_temp0';
  }

  @override
  String get changeEmail => 'Change email';

  @override
  String get errEmailFormat => 'Enter a valid email address';

  @override
  String errPasswordLength(int min) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);

    String _temp0 = intl.Intl.pluralLogic(
      min,
      locale: localeName,
      other: 'Use at least $minString characters',
      one: 'Use at least 1 character',
    );
    return '$_temp0';
  }

  @override
  String get errPasswordMismatch => 'Passwords don\'t match';

  @override
  String get errCodeFormat => 'Enter the 6-digit code';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountMessage =>
      'This deletes your account, its linked devices and any paid time left on it, right away. It can\'t be undone.';

  @override
  String get deleteAccountPlayNote =>
      'Deleting your account does not cancel a Google Play subscription.';

  @override
  String get manageGooglePlaySubscription => 'Manage in Google Play';

  @override
  String get deleteAccountConfirm => 'Delete';

  @override
  String get deletingAccount => 'Deleting...';

  @override
  String get accountDeleted => 'Your account was deleted';

  @override
  String paywallDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String paywallMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get paywallTitle => 'Go Premium';

  @override
  String get paywallCompareHeading => 'What you get';

  @override
  String get paywallRowAds => 'Ads';

  @override
  String get paywallBasicAds => 'Every time';

  @override
  String get paywallPremiumAds => 'None';

  @override
  String get paywallRowCountry => 'Country';

  @override
  String get paywallBasicCountry => 'Automatic';

  @override
  String get paywallIncluded => 'Included';

  @override
  String get paywallRowServers => 'Servers';

  @override
  String get paywallBasicServers => 'Shared';

  @override
  String get paywallPremiumServers => 'Full speed';

  @override
  String get paywallRowDevices => 'Devices';

  @override
  String get paywallNotIncluded => 'Not included';

  @override
  String paywallPremiumDevices(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $countString',
      one: '1',
    );
    return '$_temp0';
  }

  @override
  String get paywallDevicesHint => 'At the same time';

  @override
  String get paywallFewerDevices => 'Fewer devices';

  @override
  String get paywallMoreDevices => 'More devices';

  @override
  String paywallPerMonth(String price) {
    return '$price / month';
  }

  @override
  String paywallSave(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Save $percentString%';
  }

  @override
  String get paywallBestValue => 'Best value';

  @override
  String paywallContinue(String period, String price, int months) {
    final intl.NumberFormat monthsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.selectLogic(period, {
      'month': 'Continue — $price a month',
      'year': 'Continue — $price a year',
      'other': 'Continue — $price for $monthsString months',
    });
    return '$_temp0';
  }

  @override
  String get subscriptionAutoRenews =>
      'Renews automatically. Cancel anytime in Google Play.';

  @override
  String get paymentProblemsLink => 'Having payment problems?';

  @override
  String get purchasePending =>
      'Your payment is pending. Premium starts once Google Play confirms it.';

  @override
  String get purchaseConfirmLater =>
      'Payment received. Premium starts as soon as we confirm it.';

  @override
  String get purchaseGranted => 'Premium is active';

  @override
  String get signInToSubscribe => 'Sign in or create an account to subscribe';

  @override
  String get premiumActive => 'Premium Active';

  @override
  String get premiumAccountInactive => 'Account Inactive';

  @override
  String get premiumNoSubscription => 'No subscription yet';

  @override
  String get premiumNoSubscriptionHint =>
      'Premium unlocks faster servers with no ads. After you buy, tap Refresh.';

  @override
  String get premiumNoSubscriptionHintDesktop =>
      'Premium unlocks faster servers with no ads. After you buy, click Refresh.';

  @override
  String get premiumExpiredHint =>
      'Your subscription has ended. Renew it to use premium servers again.';

  @override
  String get premiumInactiveHint =>
      'This account is disabled. Contact support to restore it.';

  @override
  String get premiumPerkServers => 'Premium servers';

  @override
  String get planFree => 'Free';

  @override
  String get premiumPerkStaticIp => 'Static IP';

  @override
  String get premiumPerkNoAds => 'No ads';

  @override
  String get homeFactMode => 'Mode';

  @override
  String get homeFactDns => 'DNS';

  @override
  String get homeFactApps => 'Apps';

  @override
  String get homeModeVpn => 'VPN';

  @override
  String get homeSupport => 'Support';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHome => 'Home';

  @override
  String get navPremium => 'Premium';

  @override
  String get homeAppsAll => 'All apps';

  @override
  String homeAppsExcept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'All but $countString';
  }

  @override
  String homeAppsOnly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Only $countString';
  }

  @override
  String get expires => 'Expires';

  @override
  String get remaining => 'Days Remaining';

  @override
  String get accountStatus => 'Account Status';

  @override
  String get userStatusActive => 'Active';

  @override
  String get userStatusExpired => 'Expired';

  @override
  String get userStatusInactive => 'Inactive';

  @override
  String get userStatusDisabled => 'Disabled';

  @override
  String get userStatusSuspended => 'Suspended';

  @override
  String get userStatusBanned => 'Banned';

  @override
  String get expired => 'Expired';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signingOut => 'Signing out...';

  @override
  String get deviceBindingInfo =>
      'Your account is bound to this device. Premium configs are protected by device locking.';

  @override
  String get linkedDevices => 'Linked Devices';

  @override
  String get linkedDevicesHint => 'Loading connected devices...';

  @override
  String devicesCount(int active, int max) {
    final intl.NumberFormat activeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String activeString = activeNumberFormat.format(active);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$activeString of $maxString devices';
  }

  @override
  String get noLinkedDevices => 'No linked devices found';

  @override
  String get thisDevice => 'This device';

  @override
  String deviceLoggedInAt(String date) {
    return 'Signed in $date';
  }

  @override
  String get removeDevice => 'Remove';

  @override
  String get removeDeviceTitle => 'Remove Device';

  @override
  String removeDeviceMessage(String name) {
    return 'Remove \"$name\" from your Premium account? It will be signed out immediately.';
  }

  @override
  String get deviceRemovedSuccess => 'Device removed successfully';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get tunnelStalledTitle => 'No traffic getting through';

  @override
  String get tunnelStalledHint => 'This server stopped answering';

  @override
  String get tunnelStalledSwitch => 'Switch server';

  @override
  String get notifTunnelTitle => 'Begzar is Connected';

  @override
  String get notifTunnelVpnMode => 'VPN mode';

  @override
  String get notifTunnelProxyMode => 'Proxy mode';

  @override
  String get notifTunnelChannelName => 'Connection';

  @override
  String get notifTunnelChannelDescription =>
      'Shows while the tunnel is connected';

  @override
  String get premiumServersTitle => 'Premium Servers';

  @override
  String get premiumServersSubtitle => 'Choose a server to connect';

  @override
  String get premiumServersConnectedHint =>
      'Tap connected server to disconnect';

  @override
  String get premiumServersConnectedHintDesktop =>
      'Click connected server to disconnect';

  @override
  String get lastConnected => 'Last connected';

  @override
  String get configConnected => 'Connected';

  @override
  String get premiumServersEmpty => 'No premium servers available';

  @override
  String premiumServerConfigsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString configs';
  }

  @override
  String get serverRowChoose => 'Choose a server';

  @override
  String get serverRowChooseHint => 'Tap to see what is available';

  @override
  String get serverRowChooseHintDesktop => 'Click to see what is available';

  @override
  String get serverRowWithdrawn => 'Removed · pick another server';

  @override
  String get serverRowPremium => 'Premium servers';

  @override
  String get serverRowPremiumHint => 'Choose your location, skip the ads';

  @override
  String get serverRowExpired => 'Subscription expired';

  @override
  String get serverRowExpiredHint => 'Renew to choose a server again';

  @override
  String get serverRowInactive => 'Account disabled';

  @override
  String get serverRowInactiveHint => 'Contact support to restore it';

  @override
  String get notificationPermissionTitle => 'Notification Permission Required';

  @override
  String get notificationPermissionMessage =>
      'Notifications must be enabled to use Begzar. This keeps you informed about important updates and service messages.';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get openNotificationSettings => 'Open Settings';

  @override
  String get notificationPermissionSettingsHint =>
      'Notifications are turned off. Enable them in your device settings to continue.';

  @override
  String get macOsPermissionsTitle => 'Permissions Required';

  @override
  String get macOsPermissionsMessage =>
      'Begzar needs Secure Storage and System Proxy access on macOS. Grant both to continue.';

  @override
  String get macOsPermissionSecureStorage => 'Secure Storage';

  @override
  String get macOsPermissionSecureStorageHint =>
      'Stores your device key and account data securely.';

  @override
  String get macOsPermissionSystemProxy => 'System Proxy';

  @override
  String get macOsPermissionSystemProxyHint =>
      'Routes browser and app traffic through Begzar.';

  @override
  String get macOsPermissionGrant => 'Grant';

  @override
  String get macOsPermissionGrantAll => 'Grant All Permissions';

  @override
  String get macOsPermissionContinue => 'Continue';

  @override
  String get macOsPermissionsBlockedHint =>
      'You cannot use the app until both permissions are granted.';

  @override
  String get updateRequired => 'Update Required';

  @override
  String get updateDescription =>
      'A new version of the app is available. Please update to continue using the app.';

  @override
  String get currentVersion => 'Current Version';

  @override
  String get requiredVersion => 'Required Version';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateOpenFailed =>
      'Unable to open update page. Please visit the app store manually.';

  @override
  String updateError(String e) {
    return 'Error opening update page: $e';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableVersions(String latest, String installed) {
    return 'New version $latest · you have $installed';
  }

  @override
  String get adBadge => 'ADS';

  @override
  String adCloseCountdown(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'You can close in ${secondsString}s';
  }

  @override
  String adCloseSeconds(int seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString';
  }

  @override
  String get adSkipWarningTitle => 'Connection Disconnected';

  @override
  String get adSkipWarningMessage =>
      'Your connection was disconnected because you did not watch the ad until the end. To remove ads, purchase the Premium version.';

  @override
  String get close => 'Close';

  @override
  String get linkOpenFailed => 'Unable to open link';

  @override
  String get errSubscriptionRequired =>
      'Sign in with an active Premium subscription first';

  @override
  String get errCredentialsRequired => 'Username and password are required';

  @override
  String loginFailed(String e) {
    return 'Login failed: $e';
  }

  @override
  String get errRefreshFailed => 'Failed to refresh subscription';

  @override
  String get errSignOutFailed => 'Sign out failed. Please try again.';

  @override
  String get errLoginFailed => 'Login failed';

  @override
  String get errLoadSubscription => 'Failed to load subscription';

  @override
  String get errLogoutFailed => 'Logout failed';

  @override
  String get errSessionNotFound =>
      'Premium session not found. Please sign in again.';

  @override
  String get errUnexpectedConfigs => 'Unexpected premium configs response';

  @override
  String get errConfigsRequestFailed => 'Premium configs request failed';

  @override
  String get errNoConfigsFound =>
      'No premium configs found (decryption or parsing failed)';

  @override
  String loadConfigsFailed(String e) {
    return 'Failed to load premium configs: $e';
  }

  @override
  String loadDevicesFailed(String e) {
    return 'Failed to load devices: $e';
  }

  @override
  String loadPremiumServersFailed(String e) {
    return 'Failed to load premium servers: $e';
  }

  @override
  String removeDeviceFailed(String e) {
    return 'Failed to remove device: $e';
  }

  @override
  String get errLoadDevices => 'Failed to load devices';

  @override
  String get errLoadPremiumServers => 'Failed to load premium servers';

  @override
  String get errRemoveDevice => 'Failed to remove device';

  @override
  String get errDeviceNotFound => 'Device not found';

  @override
  String get errInvalidCredentials => 'Invalid username or password';

  @override
  String get errDeviceBound => 'This account is bound to another device';

  @override
  String get errTooManyAttempts => 'Too many attempts. Please try again later';

  @override
  String get errEmailTaken => 'An account with this email already exists';

  @override
  String get errWrongPassword => 'That password is not right';

  @override
  String get errPasswordRequired => 'Enter your password';

  @override
  String get errCodeInvalid => 'That code is not right';

  @override
  String get errCodeExpired => 'That code has expired. Send a new one';

  @override
  String get errSignUpFailed => 'Could not create the account';

  @override
  String get errVerifyFailed => 'Could not confirm the code';

  @override
  String get errDeleteAccountFailed => 'Could not delete the account';

  @override
  String get errPlansUnavailable =>
      'Plans could not be loaded. Try again later';

  @override
  String get errPurchaseFailed => 'The purchase did not go through';

  @override
  String get errPlayAlreadyOwned =>
      'This Google account already pays for a Begzar subscription. Sign in to the account that bought it';

  @override
  String get errRateLimit => 'Too many requests. Please try again later';

  @override
  String get errAccessDenied =>
      'Access denied. Please sign in again or contact support';

  @override
  String get errNoResponse => 'Could not reach the server';

  @override
  String get errNoStorageAccess => 'Storage access is unavailable';

  @override
  String get errEngineLogUnavailable => 'The engine log could not be read';

  @override
  String get errEngineMissing =>
      'This build doesn\'t include the Begzar engine, so it can\'t connect';

  @override
  String get engineLogTitle => 'Engine log';

  @override
  String get engineLogAll => 'All';

  @override
  String get engineLogEngine => 'Engine';

  @override
  String get engineLogClear => 'Clear';

  @override
  String get engineLogExport => 'Export';

  @override
  String get engineLogEmpty => 'Nothing logged yet';

  @override
  String get engineLogDropped => 'Older lines were dropped';

  @override
  String get engineLogSaved => 'Log saved';

  @override
  String get engineLogClose => 'Close';

  @override
  String get errConnectionTimeout => 'Connection timed out. Please try again';

  @override
  String get errNetworkError => 'Network error. Check your internet connection';

  @override
  String get errNoConfigsFromServer => 'No servers received from the service';

  @override
  String get errNoConfigsAvailable => 'No servers available to connect';

  @override
  String get errNoWorkingConfig => 'No working server found. Try again later';

  @override
  String get errApiV2Unavailable => 'Connection service is unavailable';

  @override
  String get errPremiumApiUnavailable => 'Premium service is unavailable';

  @override
  String get errProxyTestFailed => 'Could not connect to any server';

  @override
  String get errInvalidConfig => 'Server configuration is invalid';

  @override
  String get errDisconnectFailed => 'Disconnect failed';

  @override
  String get errConnectionFailed => 'Connection failed. Please try again';

  @override
  String get errElevationDeclined =>
      'Tunnel mode needs admin permission. Allow it when Windows asks, or choose System proxy in Settings.';

  @override
  String get errTunnelUnavailable =>
      'Tunnel mode couldn\'t start. Try again, or choose System proxy in Settings.';

  @override
  String get errTunnelStopped => 'The tunnel stopped. Connect again.';

  @override
  String get errUnauthorized => 'Session expired. Please restart the app';

  @override
  String get errForbidden => 'Access to this service is not allowed';

  @override
  String get errDeviceInitFailed =>
      'Could not register this device with the server';

  @override
  String get errFetchConfigsFailed => 'Could not load server list';

  @override
  String get errSecureConnectionFailed =>
      'Secure connection to the server failed';

  @override
  String get errClockSkew => 'This device\'s date or time is wrong';

  @override
  String get errClockSkewHint =>
      'Turn on automatic date, time, and timezone, then try again';

  @override
  String get errRequestUnverified => 'Could not verify this request';

  @override
  String get errRequestUnverifiedHint =>
      'Close the app fully and open it again';

  @override
  String get errReplayDetected => 'That request was already used';

  @override
  String get errReplayDetectedHint => 'Wait a moment and try again';

  @override
  String get errIpBlocked => 'This network cannot create a new session';

  @override
  String get errIpBlockedHint =>
      'Try a different connection, or wait and try tomorrow';

  @override
  String get errMissingSession => 'This device has no session on the server';

  @override
  String get errMissingSessionHint =>
      'Try connecting again. If it keeps failing, close the app fully and retry';

  @override
  String get errDeviceInitFailedHint => 'Check your internet, then try again';

  @override
  String get errInvalidCredentialsHint =>
      'If you forgot it, change it in the Premium bot';

  @override
  String get errDeviceLimit => 'This account has no free device slots';

  @override
  String get errDeviceLimitHint =>
      'Reset your registered devices in the Premium bot, then sign in again';

  @override
  String get errDeviceNotRegistered => 'This device is not on the account';

  @override
  String get errDeviceNotRegisteredHint =>
      'Sign out and sign in again to register it';

  @override
  String get errAccountDisabled => 'Your account has been deactivated';

  @override
  String get errAccountDisabledHint => 'Contact the Premium bot for help';

  @override
  String get errAccountExpired => 'Your Premium subscription has expired';

  @override
  String get errAccountExpiredHint => 'Renew it in the Premium bot';

  @override
  String get errRateLimitHint => 'Wait a minute and try again';

  @override
  String errRateLimitWait(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    return 'Try again in $nString seconds';
  }

  @override
  String get errSessionCredentials => 'Sign in again to continue';

  @override
  String get errSessionCredentialsHint =>
      'If you cannot sign in, change your password in the Premium bot';

  @override
  String get getHelp => 'Get help';

  @override
  String daysLeft(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days',
      one: '$daysString day',
    );
    return '$_temp0';
  }
}
