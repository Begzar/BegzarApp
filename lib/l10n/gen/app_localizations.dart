import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('zh'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BEGZAR'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @basic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basic;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'-'**
  String get unknown;

  /// No description provided for @planPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremium;

  /// No description provided for @planBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get planBasic;

  /// No description provided for @premiumDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Subscription'**
  String get premiumDialogTitle;

  /// No description provided for @premiumDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in or purchase Premium to unlock premium server configs.'**
  String get premiumDialogMessage;

  /// No description provided for @buyPremium.
  ///
  /// In en, this message translates to:
  /// **'Buy Premium'**
  String get buyPremium;

  /// No description provided for @subscriptionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription Expired'**
  String get subscriptionExpiredTitle;

  /// No description provided for @subscriptionExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Premium subscription has expired. Renew to continue using premium servers.'**
  String get subscriptionExpiredMessage;

  /// No description provided for @renewSubscription.
  ///
  /// In en, this message translates to:
  /// **'Renew Subscription'**
  String get renewSubscription;

  /// No description provided for @accountInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Inactive'**
  String get accountInactiveTitle;

  /// No description provided for @accountInactiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deactivated. Please contact Telegram support.'**
  String get accountInactiveMessage;

  /// No description provided for @otherVpnTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Another VPN was connected on your device, so Begzar disconnected it.'**
  String get otherVpnTurnedOff;

  /// No description provided for @otherVpnOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Another VPN Is On'**
  String get otherVpnOnTitle;

  /// No description provided for @otherVpnOnMessage.
  ///
  /// In en, this message translates to:
  /// **'Another VPN is connected on this device, and Begzar can\'t turn it off. Turn it off in your device\'s VPN settings, then try again.'**
  String get otherVpnOnMessage;

  /// No description provided for @otherVpnContinueAnyway.
  ///
  /// In en, this message translates to:
  /// **'Continue Anyway'**
  String get otherVpnContinueAnyway;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @accountInactiveSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, my Premium account has been deactivated and I need help.'**
  String get accountInactiveSupportMessage;

  /// No description provided for @premiumSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Hello, I would like to purchase a Begzar Premium subscription.'**
  String get premiumSupportMessage;

  /// No description provided for @conn_connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get conn_connecting;

  /// No description provided for @conn_disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get conn_disconnecting;

  /// No description provided for @conn_connected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get conn_connected;

  /// No description provided for @conn_error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect'**
  String get conn_error;

  /// No description provided for @conn_ready.
  ///
  /// In en, this message translates to:
  /// **'Not protected'**
  String get conn_ready;

  /// No description provided for @connSub_connecting.
  ///
  /// In en, this message translates to:
  /// **'Tap to cancel'**
  String get connSub_connecting;

  /// No description provided for @connSub_connectingDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to cancel'**
  String get connSub_connectingDesktop;

  /// No description provided for @connSub_disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Closing the tunnel'**
  String get connSub_disconnecting;

  /// No description provided for @connSub_error.
  ///
  /// In en, this message translates to:
  /// **'Tap to try again'**
  String get connSub_error;

  /// No description provided for @connSub_errorDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to try again'**
  String get connSub_errorDesktop;

  /// No description provided for @connSub_ready.
  ///
  /// In en, this message translates to:
  /// **'Tap to auto-connect'**
  String get connSub_ready;

  /// No description provided for @connSub_readyDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to auto-connect'**
  String get connSub_readyDesktop;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// No description provided for @tapToTest.
  ///
  /// In en, this message translates to:
  /// **'Tap to test'**
  String get tapToTest;

  /// No description provided for @tapToTestDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to test'**
  String get tapToTestDesktop;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @tapToRetryDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to retry'**
  String get tapToRetryDesktop;

  /// No description provided for @pingMs.
  ///
  /// In en, this message translates to:
  /// **'{ms}ms'**
  String pingMs(int ms);

  /// No description provided for @pingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get pingExcellent;

  /// No description provided for @pingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get pingGood;

  /// No description provided for @pingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get pingFair;

  /// No description provided for @pingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get pingPoor;

  /// No description provided for @settingsCategoryApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsCategoryApp;

  /// No description provided for @settingsCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsCategoryGeneral;

  /// No description provided for @settingsCategoryConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsCategoryConnection;

  /// No description provided for @settingsCategoryNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsCategoryNetwork;

  /// No description provided for @settingsCategoryExperimental.
  ///
  /// In en, this message translates to:
  /// **'Experimental'**
  String get settingsCategoryExperimental;

  /// No description provided for @experimentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental settings'**
  String get experimentalTitle;

  /// No description provided for @experimentalEnabled.
  ///
  /// In en, this message translates to:
  /// **'Free connections use Cloudflare WARP'**
  String get experimentalEnabled;

  /// No description provided for @experimentalDisabled.
  ///
  /// In en, this message translates to:
  /// **'Free connections use Begzar\'s servers'**
  String get experimentalDisabled;

  /// No description provided for @warpModeTitle.
  ///
  /// In en, this message translates to:
  /// **'WARP mode'**
  String get warpModeTitle;

  /// No description provided for @warpModeMasque.
  ///
  /// In en, this message translates to:
  /// **'MASQUE'**
  String get warpModeMasque;

  /// No description provided for @warpModeWarp.
  ///
  /// In en, this message translates to:
  /// **'WireGuard'**
  String get warpModeWarp;

  /// No description provided for @warpModeGool.
  ///
  /// In en, this message translates to:
  /// **'WARP in WARP'**
  String get warpModeGool;

  /// No description provided for @warpModeMasquePsiphon.
  ///
  /// In en, this message translates to:
  /// **'Psiphon over MASQUE'**
  String get warpModeMasquePsiphon;

  /// No description provided for @warpModePsiphon.
  ///
  /// In en, this message translates to:
  /// **'Psiphon over WARP'**
  String get warpModePsiphon;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageSubtitle;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appRoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'App Routing'**
  String get appRoutingTitle;

  /// No description provided for @appRoutingSubtitleNone.
  ///
  /// In en, this message translates to:
  /// **'Choose which apps use the VPN'**
  String get appRoutingSubtitleNone;

  /// Persian keeps two spaces before the count: ز curls left under one, and the count reads as joined to it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{All except 1 app} other{All except {count} apps}}'**
  String appRoutingSubtitleAllExcept(int count);

  /// No description provided for @appRoutingSubtitleOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 app} other{Only {count} apps}}'**
  String appRoutingSubtitleOnly(int count);

  /// No description provided for @appRoutingNeedsVpn.
  ///
  /// In en, this message translates to:
  /// **'Turn off Proxy Only Mode to route apps'**
  String get appRoutingNeedsVpn;

  /// No description provided for @appRoutingModeAllExcept.
  ///
  /// In en, this message translates to:
  /// **'All apps use VPN, except…'**
  String get appRoutingModeAllExcept;

  /// No description provided for @appRoutingModeAllExceptHint.
  ///
  /// In en, this message translates to:
  /// **'Everything goes through the VPN. Apps you pick go direct.'**
  String get appRoutingModeAllExceptHint;

  /// No description provided for @appRoutingModeOnly.
  ///
  /// In en, this message translates to:
  /// **'Only some apps use VPN'**
  String get appRoutingModeOnly;

  /// No description provided for @appRoutingModeOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing goes through the VPN except the apps you pick. With none picked, every app does.'**
  String get appRoutingModeOnlyHint;

  /// No description provided for @appRoutingPickAllExcept.
  ///
  /// In en, this message translates to:
  /// **'Pick apps that skip the VPN'**
  String get appRoutingPickAllExcept;

  /// No description provided for @appRoutingPickOnly.
  ///
  /// In en, this message translates to:
  /// **'Pick apps that use the VPN'**
  String get appRoutingPickOnly;

  /// No description provided for @appRoutingThroughVpn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app through VPN} other{{count} apps through VPN}}'**
  String appRoutingThroughVpn(int count);

  /// No description provided for @appRoutingDirect.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app direct} other{{count} apps direct}}'**
  String appRoutingDirect(int count);

  /// No description provided for @appRoutingTagVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get appRoutingTagVpn;

  /// No description provided for @appRoutingTagDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get appRoutingTagDirect;

  /// No description provided for @dnsServerTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS Server'**
  String get dnsServerTitle;

  /// No description provided for @dnsServerCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {dns}'**
  String dnsServerCurrent(String dns);

  /// No description provided for @proxyOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Proxy Only Mode'**
  String get proxyOnlyTitle;

  /// No description provided for @proxyOnlyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Using SOCKS proxy on port {port}'**
  String proxyOnlyEnabled(int port);

  /// No description provided for @proxyOnlyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Use proxy mode instead of VPN'**
  String get proxyOnlyDisabled;

  /// No description provided for @connectionModeTunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get connectionModeTunnel;

  /// No description provided for @connectionModeTunnelHint.
  ///
  /// In en, this message translates to:
  /// **'Every app goes through Begzar. Windows asks for admin permission each time you connect.'**
  String get connectionModeTunnelHint;

  /// No description provided for @connectionModeSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'System proxy'**
  String get connectionModeSystemProxy;

  /// No description provided for @connectionModeSystemProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Apps that follow Windows proxy settings use 127.0.0.1:{port}'**
  String connectionModeSystemProxyHint(int port);

  /// No description provided for @connectionModeProxyOnly.
  ///
  /// In en, this message translates to:
  /// **'Proxy only'**
  String get connectionModeProxyOnly;

  /// No description provided for @connectionModeProxyOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Point apps at SOCKS port {port} yourself'**
  String connectionModeProxyOnlyHint(int port);

  /// No description provided for @bypassLanTitle.
  ///
  /// In en, this message translates to:
  /// **'Bypass LAN'**
  String get bypassLanTitle;

  /// No description provided for @bypassLanEnabled.
  ///
  /// In en, this message translates to:
  /// **'SOCKS listens on all interfaces (0.0.0.0)'**
  String get bypassLanEnabled;

  /// No description provided for @bypassLanDisabled.
  ///
  /// In en, this message translates to:
  /// **'Allow other devices on your network to use this proxy'**
  String get bypassLanDisabled;

  /// No description provided for @bypassLanRequiresProxy.
  ///
  /// In en, this message translates to:
  /// **'Enable Proxy Only Mode to use Bypass LAN'**
  String get bypassLanRequiresProxy;

  /// No description provided for @bypassLanRequiresProxyMode.
  ///
  /// In en, this message translates to:
  /// **'Choose Proxy only to use Bypass LAN'**
  String get bypassLanRequiresProxyMode;

  /// No description provided for @bypassLanAddressesTitle.
  ///
  /// In en, this message translates to:
  /// **'Device addresses'**
  String get bypassLanAddressesTitle;

  /// No description provided for @bypassLanNoAddresses.
  ///
  /// In en, this message translates to:
  /// **'No LAN address found'**
  String get bypassLanNoAddresses;

  /// No description provided for @bypassLanEndpoint.
  ///
  /// In en, this message translates to:
  /// **'socks5://{ip}:{port}'**
  String bypassLanEndpoint(String ip, int port);

  /// No description provided for @routingRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Site & IP Rules'**
  String get routingRulesTitle;

  /// No description provided for @routingRulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route or block sites and IPs'**
  String get routingRulesSubtitle;

  /// No description provided for @routingRulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 custom rule} other{{count} custom rules}}'**
  String routingRulesCount(int count);

  /// No description provided for @routingRulesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Site & IP Rules'**
  String get routingRulesScreenTitle;

  /// No description provided for @routingRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Custom rules apply on the next connection. Reconnect VPN to apply changes.'**
  String get routingRulesHint;

  /// No description provided for @routingTabDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get routingTabDirect;

  /// No description provided for @routingTabBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get routingTabBlock;

  /// No description provided for @routingTabProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get routingTabProxy;

  /// No description provided for @routingAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get routingAddRule;

  /// No description provided for @routingEntryDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get routingEntryDomain;

  /// No description provided for @routingEntryIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get routingEntryIp;

  /// No description provided for @routingDomainHint.
  ///
  /// In en, this message translates to:
  /// **'example.com'**
  String get routingDomainHint;

  /// No description provided for @routingIpHint.
  ///
  /// In en, this message translates to:
  /// **'10.0.0.0/8 or 8.8.8.8'**
  String get routingIpHint;

  /// No description provided for @routingInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid domain or IP address'**
  String get routingInvalidInput;

  /// No description provided for @routingEmptyDirect.
  ///
  /// In en, this message translates to:
  /// **'No direct routes yet'**
  String get routingEmptyDirect;

  /// No description provided for @routingAlreadyListed.
  ///
  /// In en, this message translates to:
  /// **'That rule is already in the list'**
  String get routingAlreadyListed;

  /// No description provided for @routingEmptyBlock.
  ///
  /// In en, this message translates to:
  /// **'No blocked routes yet'**
  String get routingEmptyBlock;

  /// No description provided for @routingEmptyProxy.
  ///
  /// In en, this message translates to:
  /// **'No proxy routes yet'**
  String get routingEmptyProxy;

  /// No description provided for @settingsInfoReconnect.
  ///
  /// In en, this message translates to:
  /// **'Changes will apply after reconnecting VPN'**
  String get settingsInfoReconnect;

  /// No description provided for @dnsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'DNS Server'**
  String get dnsDialogTitle;

  /// No description provided for @dnsDialogPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter DNS server IP address:'**
  String get dnsDialogPrompt;

  /// No description provided for @dnsDialogCommon.
  ///
  /// In en, this message translates to:
  /// **'Common DNS servers:'**
  String get dnsDialogCommon;

  /// No description provided for @dnsDialogInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an IP address, such as 8.8.8.8'**
  String get dnsDialogInvalid;

  /// No description provided for @languageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get languageDialogTitle;

  /// No description provided for @languageChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings'**
  String get languageChoiceHint;

  /// No description provided for @languageContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languageContinue;

  /// No description provided for @dnsChipLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} ({dns})'**
  String dnsChipLabel(String label, String dns);

  /// No description provided for @dnsGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get dnsGoogle;

  /// No description provided for @dnsCloudflare.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare'**
  String get dnsCloudflare;

  /// No description provided for @dnsLevel3.
  ///
  /// In en, this message translates to:
  /// **'Level3'**
  String get dnsLevel3;

  /// No description provided for @dnsOpenDns.
  ///
  /// In en, this message translates to:
  /// **'OpenDNS'**
  String get dnsOpenDns;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @searchAppsHint.
  ///
  /// In en, this message translates to:
  /// **'Search apps...'**
  String get searchAppsHint;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noAppsFound;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noSearchResults;

  /// No description provided for @premiumHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Begzar Premium'**
  String get premiumHeroTitle;

  /// No description provided for @premiumHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access premium servers and manage your subscription'**
  String get premiumHeroSubtitle;

  /// No description provided for @signInToPremium.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Premium'**
  String get signInToPremium;

  /// No description provided for @usePremiumCredentials.
  ///
  /// In en, this message translates to:
  /// **'Use your premium account credentials'**
  String get usePremiumCredentials;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @emailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get emailOrUsername;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get createAccountLink;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get signInLink;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// No description provided for @createAccountHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a code to confirm it'**
  String get createAccountHint;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @creatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccount;

  /// No description provided for @signUpPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you accept the Privacy Policy'**
  String get signUpPrivacyNotice;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to:'**
  String get verifyEmailHint;

  /// No description provided for @confirmationCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get confirmationCode;

  /// No description provided for @confirmCode.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmCode;

  /// No description provided for @confirmingCode.
  ///
  /// In en, this message translates to:
  /// **'Confirming...'**
  String get confirmingCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Resend in 1 second} other{Resend in {seconds} seconds}}'**
  String resendCodeIn(int seconds);

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @errEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get errEmailFormat;

  /// No description provided for @errPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'{min, plural, =1{Use at least 1 character} other{Use at least {min} characters}}'**
  String errPasswordLength(int min);

  /// No description provided for @errPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get errPasswordMismatch;

  /// No description provided for @errCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get errCodeFormat;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account, its linked devices and any paid time left on it, right away. It can\'t be undone.'**
  String get deleteAccountMessage;

  /// No description provided for @deleteAccountPlayNote.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account does not cancel a Google Play subscription.'**
  String get deleteAccountPlayNote;

  /// No description provided for @manageGooglePlaySubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage in Google Play'**
  String get manageGooglePlaySubscription;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirm;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deletingAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted'**
  String get accountDeleted;

  /// No description provided for @paywallDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device} other{{count} devices}}'**
  String paywallDevices(int count);

  /// No description provided for @paywallMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String paywallMonths(int count);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get paywallTitle;

  /// No description provided for @paywallCompareHeading.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get paywallCompareHeading;

  /// No description provided for @paywallRowAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get paywallRowAds;

  /// No description provided for @paywallBasicAds.
  ///
  /// In en, this message translates to:
  /// **'Every time'**
  String get paywallBasicAds;

  /// No description provided for @paywallPremiumAds.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get paywallPremiumAds;

  /// No description provided for @paywallRowCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get paywallRowCountry;

  /// No description provided for @paywallBasicCountry.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get paywallBasicCountry;

  /// No description provided for @paywallIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get paywallIncluded;

  /// No description provided for @paywallRowServers.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get paywallRowServers;

  /// No description provided for @paywallBasicServers.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get paywallBasicServers;

  /// No description provided for @paywallPremiumServers.
  ///
  /// In en, this message translates to:
  /// **'Full speed'**
  String get paywallPremiumServers;

  /// No description provided for @paywallRowDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get paywallRowDevices;

  /// No description provided for @paywallNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get paywallNotIncluded;

  /// No description provided for @paywallPremiumDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1} other{Up to {count}}}'**
  String paywallPremiumDevices(int count);

  /// No description provided for @paywallDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'At the same time'**
  String get paywallDevicesHint;

  /// No description provided for @paywallFewerDevices.
  ///
  /// In en, this message translates to:
  /// **'Fewer devices'**
  String get paywallFewerDevices;

  /// No description provided for @paywallMoreDevices.
  ///
  /// In en, this message translates to:
  /// **'More devices'**
  String get paywallMoreDevices;

  /// No description provided for @paywallPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String paywallPerMonth(String price);

  /// No description provided for @paywallSave.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallSave(int percent);

  /// No description provided for @paywallBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get paywallBestValue;

  /// The paywall's button. period is month for a monthly plan, year for a yearly one, and other for any other length, which months then names.
  ///
  /// In en, this message translates to:
  /// **'{period, select, month{Continue — {price} a month} year{Continue — {price} a year} other{Continue — {price} for {months} months}}'**
  String paywallContinue(String period, String price, int months);

  /// No description provided for @subscriptionAutoRenews.
  ///
  /// In en, this message translates to:
  /// **'Renews automatically. Cancel anytime in Google Play.'**
  String get subscriptionAutoRenews;

  /// No description provided for @paymentProblemsLink.
  ///
  /// In en, this message translates to:
  /// **'Having payment problems?'**
  String get paymentProblemsLink;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending. Premium starts once Google Play confirms it.'**
  String get purchasePending;

  /// No description provided for @purchaseConfirmLater.
  ///
  /// In en, this message translates to:
  /// **'Payment received. Premium starts as soon as we confirm it.'**
  String get purchaseConfirmLater;

  /// No description provided for @purchaseGranted.
  ///
  /// In en, this message translates to:
  /// **'Premium is active'**
  String get purchaseGranted;

  /// No description provided for @signInToSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to subscribe'**
  String get signInToSubscribe;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium Active'**
  String get premiumActive;

  /// No description provided for @premiumAccountInactive.
  ///
  /// In en, this message translates to:
  /// **'Account Inactive'**
  String get premiumAccountInactive;

  /// No description provided for @premiumNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No subscription yet'**
  String get premiumNoSubscription;

  /// No description provided for @premiumNoSubscriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocks faster servers with no ads. After you buy, tap Refresh.'**
  String get premiumNoSubscriptionHint;

  /// No description provided for @premiumNoSubscriptionHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocks faster servers with no ads. After you buy, click Refresh.'**
  String get premiumNoSubscriptionHintDesktop;

  /// No description provided for @premiumExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has ended. Renew it to use premium servers again.'**
  String get premiumExpiredHint;

  /// No description provided for @premiumInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Contact support to restore it.'**
  String get premiumInactiveHint;

  /// No description provided for @premiumPerkServers.
  ///
  /// In en, this message translates to:
  /// **'Premium servers'**
  String get premiumPerkServers;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planFree;

  /// No description provided for @premiumPerkStaticIp.
  ///
  /// In en, this message translates to:
  /// **'Static IP'**
  String get premiumPerkStaticIp;

  /// No description provided for @premiumPerkNoAds.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get premiumPerkNoAds;

  /// No description provided for @homeFactMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get homeFactMode;

  /// No description provided for @homeFactDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get homeFactDns;

  /// No description provided for @homeFactApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get homeFactApps;

  /// No description provided for @homeModeVpn.
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get homeModeVpn;

  /// No description provided for @homeSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get homeSupport;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get navPremium;

  /// No description provided for @homeAppsAll.
  ///
  /// In en, this message translates to:
  /// **'All apps'**
  String get homeAppsAll;

  /// Persian keeps two spaces before the count: ز curls left under one, and the count reads as joined to it.
  ///
  /// In en, this message translates to:
  /// **'All but {count}'**
  String homeAppsExcept(int count);

  /// No description provided for @homeAppsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only {count}'**
  String homeAppsOnly(int count);

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Days Remaining'**
  String get remaining;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account Status'**
  String get accountStatus;

  /// No description provided for @userStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get userStatusActive;

  /// No description provided for @userStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get userStatusExpired;

  /// No description provided for @userStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get userStatusInactive;

  /// No description provided for @userStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get userStatusDisabled;

  /// No description provided for @userStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get userStatusSuspended;

  /// No description provided for @userStatusBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get userStatusBanned;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get signingOut;

  /// No description provided for @deviceBindingInfo.
  ///
  /// In en, this message translates to:
  /// **'Your account is bound to this device. Premium configs are protected by device locking.'**
  String get deviceBindingInfo;

  /// No description provided for @linkedDevices.
  ///
  /// In en, this message translates to:
  /// **'Linked Devices'**
  String get linkedDevices;

  /// No description provided for @linkedDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'Loading connected devices...'**
  String get linkedDevicesHint;

  /// No description provided for @devicesCount.
  ///
  /// In en, this message translates to:
  /// **'{active} of {max} devices'**
  String devicesCount(int active, int max);

  /// No description provided for @noLinkedDevices.
  ///
  /// In en, this message translates to:
  /// **'No linked devices found'**
  String get noLinkedDevices;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @deviceLoggedInAt.
  ///
  /// In en, this message translates to:
  /// **'Signed in {date}'**
  String deviceLoggedInAt(String date);

  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeDevice;

  /// No description provided for @removeDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Device'**
  String get removeDeviceTitle;

  /// No description provided for @removeDeviceMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from your Premium account? It will be signed out immediately.'**
  String removeDeviceMessage(String name);

  /// No description provided for @deviceRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device removed successfully'**
  String get deviceRemovedSuccess;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @tunnelStalledTitle.
  ///
  /// In en, this message translates to:
  /// **'No traffic getting through'**
  String get tunnelStalledTitle;

  /// No description provided for @tunnelStalledHint.
  ///
  /// In en, this message translates to:
  /// **'This server stopped answering'**
  String get tunnelStalledHint;

  /// No description provided for @tunnelStalledSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get tunnelStalledSwitch;

  /// No description provided for @notifTunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Begzar is Connected'**
  String get notifTunnelTitle;

  /// No description provided for @notifTunnelVpnMode.
  ///
  /// In en, this message translates to:
  /// **'VPN mode'**
  String get notifTunnelVpnMode;

  /// No description provided for @notifTunnelProxyMode.
  ///
  /// In en, this message translates to:
  /// **'Proxy mode'**
  String get notifTunnelProxyMode;

  /// No description provided for @notifTunnelChannelName.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get notifTunnelChannelName;

  /// No description provided for @notifTunnelChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows while the tunnel is connected'**
  String get notifTunnelChannelDescription;

  /// No description provided for @premiumServersTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Servers'**
  String get premiumServersTitle;

  /// No description provided for @premiumServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a server to connect'**
  String get premiumServersSubtitle;

  /// No description provided for @premiumServersConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap connected server to disconnect'**
  String get premiumServersConnectedHint;

  /// No description provided for @premiumServersConnectedHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click connected server to disconnect'**
  String get premiumServersConnectedHintDesktop;

  /// No description provided for @lastConnected.
  ///
  /// In en, this message translates to:
  /// **'Last connected'**
  String get lastConnected;

  /// Badge at the end of the premium config row the tunnel is up through.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get configConnected;

  /// No description provided for @premiumServersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No premium servers available'**
  String get premiumServersEmpty;

  /// No description provided for @premiumServerConfigsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} configs'**
  String premiumServerConfigsCount(int count);

  /// No description provided for @serverRowChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get serverRowChoose;

  /// No description provided for @serverRowChooseHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to see what is available'**
  String get serverRowChooseHint;

  /// No description provided for @serverRowChooseHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click to see what is available'**
  String get serverRowChooseHintDesktop;

  /// No description provided for @serverRowWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Removed · pick another server'**
  String get serverRowWithdrawn;

  /// No description provided for @serverRowPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium servers'**
  String get serverRowPremium;

  /// No description provided for @serverRowPremiumHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your location, skip the ads'**
  String get serverRowPremiumHint;

  /// No description provided for @serverRowExpired.
  ///
  /// In en, this message translates to:
  /// **'Subscription expired'**
  String get serverRowExpired;

  /// No description provided for @serverRowExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'Renew to choose a server again'**
  String get serverRowExpiredHint;

  /// No description provided for @serverRowInactive.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get serverRowInactive;

  /// No description provided for @serverRowInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'Contact support to restore it'**
  String get serverRowInactiveHint;

  /// No description provided for @notificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Required'**
  String get notificationPermissionTitle;

  /// No description provided for @notificationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Notifications must be enabled to use Begzar. This keeps you informed about important updates and service messages.'**
  String get notificationPermissionMessage;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @openNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openNotificationSettings;

  /// No description provided for @notificationPermissionSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off. Enable them in your device settings to continue.'**
  String get notificationPermissionSettingsHint;

  /// No description provided for @macOsPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get macOsPermissionsTitle;

  /// No description provided for @macOsPermissionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Begzar needs Secure Storage and System Proxy access on macOS. Grant both to continue.'**
  String get macOsPermissionsMessage;

  /// No description provided for @macOsPermissionSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure Storage'**
  String get macOsPermissionSecureStorage;

  /// No description provided for @macOsPermissionSecureStorageHint.
  ///
  /// In en, this message translates to:
  /// **'Stores your device key and account data securely.'**
  String get macOsPermissionSecureStorageHint;

  /// No description provided for @macOsPermissionSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'System Proxy'**
  String get macOsPermissionSystemProxy;

  /// No description provided for @macOsPermissionSystemProxyHint.
  ///
  /// In en, this message translates to:
  /// **'Routes browser and app traffic through Begzar.'**
  String get macOsPermissionSystemProxyHint;

  /// No description provided for @macOsPermissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get macOsPermissionGrant;

  /// No description provided for @macOsPermissionGrantAll.
  ///
  /// In en, this message translates to:
  /// **'Grant All Permissions'**
  String get macOsPermissionGrantAll;

  /// No description provided for @macOsPermissionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get macOsPermissionContinue;

  /// No description provided for @macOsPermissionsBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'You cannot use the app until both permissions are granted.'**
  String get macOsPermissionsBlockedHint;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// No description provided for @updateDescription.
  ///
  /// In en, this message translates to:
  /// **'A new version of the app is available. Please update to continue using the app.'**
  String get updateDescription;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current Version'**
  String get currentVersion;

  /// No description provided for @requiredVersion.
  ///
  /// In en, this message translates to:
  /// **'Required Version'**
  String get requiredVersion;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open update page. Please visit the app store manually.'**
  String get updateOpenFailed;

  /// No description provided for @updateError.
  ///
  /// In en, this message translates to:
  /// **'Error opening update page: {e}'**
  String updateError(String e);

  /// The settings row offering a newer release the user does not have to install, and what a screen reader hears on the settings tab while that release waits.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// Under the update row: the release it offers, then the build that is running. Versions are identifiers rather than quantities, so they keep their own digits in every locale.
  ///
  /// In en, this message translates to:
  /// **'New version {latest} · you have {installed}'**
  String updateAvailableVersions(String latest, String installed);

  /// No description provided for @adBadge.
  ///
  /// In en, this message translates to:
  /// **'ADS'**
  String get adBadge;

  /// The post-connect ad wait, in words. The gate row states it as a filling rail rather than a sentence, so this is what the close control offers a screen reader.
  ///
  /// In en, this message translates to:
  /// **'You can close in {seconds}s'**
  String adCloseCountdown(int seconds);

  /// The seconds left on the post-connect ad wait, shown alone inside the close control. A bare number in every locale, and a message rather than a raw interpolation so it is written in the digits that locale uses.
  ///
  /// In en, this message translates to:
  /// **'{seconds}'**
  String adCloseSeconds(int seconds);

  /// No description provided for @adSkipWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Disconnected'**
  String get adSkipWarningTitle;

  /// No description provided for @adSkipWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Your connection was disconnected because you did not watch the ad until the end. To remove ads, purchase the Premium version.'**
  String get adSkipWarningMessage;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open link'**
  String get linkOpenFailed;

  /// No description provided for @errSubscriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an active Premium subscription first'**
  String get errSubscriptionRequired;

  /// No description provided for @errCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Username and password are required'**
  String get errCredentialsRequired;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {e}'**
  String loginFailed(String e);

  /// No description provided for @errRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh subscription'**
  String get errRefreshFailed;

  /// No description provided for @errSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed. Please try again.'**
  String get errSignOutFailed;

  /// No description provided for @errLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get errLoginFailed;

  /// No description provided for @errLoadSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to load subscription'**
  String get errLoadSubscription;

  /// No description provided for @errLogoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Logout failed'**
  String get errLogoutFailed;

  /// No description provided for @errSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Premium session not found. Please sign in again.'**
  String get errSessionNotFound;

  /// No description provided for @errUnexpectedConfigs.
  ///
  /// In en, this message translates to:
  /// **'Unexpected premium configs response'**
  String get errUnexpectedConfigs;

  /// No description provided for @errConfigsRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Premium configs request failed'**
  String get errConfigsRequestFailed;

  /// No description provided for @errNoConfigsFound.
  ///
  /// In en, this message translates to:
  /// **'No premium configs found (decryption or parsing failed)'**
  String get errNoConfigsFound;

  /// No description provided for @loadConfigsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load premium configs: {e}'**
  String loadConfigsFailed(String e);

  /// No description provided for @loadDevicesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load devices: {e}'**
  String loadDevicesFailed(String e);

  /// No description provided for @loadPremiumServersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load premium servers: {e}'**
  String loadPremiumServersFailed(String e);

  /// No description provided for @removeDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove device: {e}'**
  String removeDeviceFailed(String e);

  /// No description provided for @errLoadDevices.
  ///
  /// In en, this message translates to:
  /// **'Failed to load devices'**
  String get errLoadDevices;

  /// No description provided for @errLoadPremiumServers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load premium servers'**
  String get errLoadPremiumServers;

  /// No description provided for @errRemoveDevice.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove device'**
  String get errRemoveDevice;

  /// No description provided for @errDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found'**
  String get errDeviceNotFound;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get errInvalidCredentials;

  /// No description provided for @errDeviceBound.
  ///
  /// In en, this message translates to:
  /// **'This account is bound to another device'**
  String get errDeviceBound;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later'**
  String get errTooManyAttempts;

  /// No description provided for @errEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get errEmailTaken;

  /// No description provided for @errWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is not right'**
  String get errWrongPassword;

  /// No description provided for @errPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get errPasswordRequired;

  /// No description provided for @errCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is not right'**
  String get errCodeInvalid;

  /// No description provided for @errCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Send a new one'**
  String get errCodeExpired;

  /// No description provided for @errSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the account'**
  String get errSignUpFailed;

  /// No description provided for @errVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the code'**
  String get errVerifyFailed;

  /// No description provided for @errDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account'**
  String get errDeleteAccountFailed;

  /// No description provided for @errPlansUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans could not be loaded. Try again later'**
  String get errPlansUnavailable;

  /// No description provided for @errPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase did not go through'**
  String get errPurchaseFailed;

  /// No description provided for @errPlayAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This Google account already pays for a Begzar subscription. Sign in to the account that bought it'**
  String get errPlayAlreadyOwned;

  /// No description provided for @errRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later'**
  String get errRateLimit;

  /// No description provided for @errAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied. Please sign in again or contact support'**
  String get errAccessDenied;

  /// No description provided for @errNoResponse.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get errNoResponse;

  /// No description provided for @errNoStorageAccess.
  ///
  /// In en, this message translates to:
  /// **'Storage access is unavailable'**
  String get errNoStorageAccess;

  /// No description provided for @errEngineLogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The engine log could not be read'**
  String get errEngineLogUnavailable;

  /// No description provided for @errEngineMissing.
  ///
  /// In en, this message translates to:
  /// **'This build doesn\'t include the Begzar engine, so it can\'t connect'**
  String get errEngineMissing;

  /// No description provided for @engineLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Engine log'**
  String get engineLogTitle;

  /// No description provided for @engineLogAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get engineLogAll;

  /// No description provided for @engineLogEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engineLogEngine;

  /// No description provided for @engineLogClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get engineLogClear;

  /// No description provided for @engineLogExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get engineLogExport;

  /// No description provided for @engineLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get engineLogEmpty;

  /// No description provided for @engineLogDropped.
  ///
  /// In en, this message translates to:
  /// **'Older lines were dropped'**
  String get engineLogDropped;

  /// No description provided for @engineLogSaved.
  ///
  /// In en, this message translates to:
  /// **'Log saved'**
  String get engineLogSaved;

  /// No description provided for @engineLogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get engineLogClose;

  /// No description provided for @errConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please try again'**
  String get errConnectionTimeout;

  /// No description provided for @errNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection'**
  String get errNetworkError;

  /// No description provided for @errNoConfigsFromServer.
  ///
  /// In en, this message translates to:
  /// **'No servers received from the service'**
  String get errNoConfigsFromServer;

  /// No description provided for @errNoConfigsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No servers available to connect'**
  String get errNoConfigsAvailable;

  /// No description provided for @errNoWorkingConfig.
  ///
  /// In en, this message translates to:
  /// **'No working server found. Try again later'**
  String get errNoWorkingConfig;

  /// No description provided for @errApiV2Unavailable.
  ///
  /// In en, this message translates to:
  /// **'Connection service is unavailable'**
  String get errApiV2Unavailable;

  /// No description provided for @errPremiumApiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Premium service is unavailable'**
  String get errPremiumApiUnavailable;

  /// No description provided for @errProxyTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to any server'**
  String get errProxyTestFailed;

  /// No description provided for @errInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'Server configuration is invalid'**
  String get errInvalidConfig;

  /// No description provided for @errDisconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Disconnect failed'**
  String get errDisconnectFailed;

  /// No description provided for @errConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please try again'**
  String get errConnectionFailed;

  /// No description provided for @errElevationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Tunnel mode needs admin permission. Allow it when Windows asks, or choose System proxy in Settings.'**
  String get errElevationDeclined;

  /// No description provided for @errTunnelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Tunnel mode couldn\'t start. Try again, or choose System proxy in Settings.'**
  String get errTunnelUnavailable;

  /// No description provided for @errTunnelStopped.
  ///
  /// In en, this message translates to:
  /// **'The tunnel stopped. Connect again.'**
  String get errTunnelStopped;

  /// No description provided for @errUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please restart the app'**
  String get errUnauthorized;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'Access to this service is not allowed'**
  String get errForbidden;

  /// No description provided for @errDeviceInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not register this device with the server'**
  String get errDeviceInitFailed;

  /// No description provided for @errFetchConfigsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load server list'**
  String get errFetchConfigsFailed;

  /// No description provided for @errSecureConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Secure connection to the server failed'**
  String get errSecureConnectionFailed;

  /// No description provided for @errClockSkew.
  ///
  /// In en, this message translates to:
  /// **'This device\'s date or time is wrong'**
  String get errClockSkew;

  /// No description provided for @errClockSkewHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on automatic date, time, and timezone, then try again'**
  String get errClockSkewHint;

  /// No description provided for @errRequestUnverified.
  ///
  /// In en, this message translates to:
  /// **'Could not verify this request'**
  String get errRequestUnverified;

  /// No description provided for @errRequestUnverifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Close the app fully and open it again'**
  String get errRequestUnverifiedHint;

  /// No description provided for @errReplayDetected.
  ///
  /// In en, this message translates to:
  /// **'That request was already used'**
  String get errReplayDetected;

  /// No description provided for @errReplayDetectedHint.
  ///
  /// In en, this message translates to:
  /// **'Wait a moment and try again'**
  String get errReplayDetectedHint;

  /// No description provided for @errIpBlocked.
  ///
  /// In en, this message translates to:
  /// **'This network cannot create a new session'**
  String get errIpBlocked;

  /// No description provided for @errIpBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different connection, or wait and try tomorrow'**
  String get errIpBlockedHint;

  /// No description provided for @errMissingSession.
  ///
  /// In en, this message translates to:
  /// **'This device has no session on the server'**
  String get errMissingSession;

  /// No description provided for @errMissingSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Try connecting again. If it keeps failing, close the app fully and retry'**
  String get errMissingSessionHint;

  /// No description provided for @errDeviceInitFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Check your internet, then try again'**
  String get errDeviceInitFailedHint;

  /// No description provided for @errInvalidCredentialsHint.
  ///
  /// In en, this message translates to:
  /// **'If you forgot it, change it in the Premium bot'**
  String get errInvalidCredentialsHint;

  /// No description provided for @errDeviceLimit.
  ///
  /// In en, this message translates to:
  /// **'This account has no free device slots'**
  String get errDeviceLimit;

  /// No description provided for @errDeviceLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Reset your registered devices in the Premium bot, then sign in again'**
  String get errDeviceLimitHint;

  /// No description provided for @errDeviceNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'This device is not on the account'**
  String get errDeviceNotRegistered;

  /// No description provided for @errDeviceNotRegisteredHint.
  ///
  /// In en, this message translates to:
  /// **'Sign out and sign in again to register it'**
  String get errDeviceNotRegisteredHint;

  /// No description provided for @errAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deactivated'**
  String get errAccountDisabled;

  /// No description provided for @errAccountDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Contact the Premium bot for help'**
  String get errAccountDisabledHint;

  /// No description provided for @errAccountExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Premium subscription has expired'**
  String get errAccountExpired;

  /// No description provided for @errAccountExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'Renew it in the Premium bot'**
  String get errAccountExpiredHint;

  /// No description provided for @errRateLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Wait a minute and try again'**
  String get errRateLimitHint;

  /// No description provided for @errRateLimitWait.
  ///
  /// In en, this message translates to:
  /// **'Try again in {n} seconds'**
  String errRateLimitWait(int n);

  /// No description provided for @errSessionCredentials.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue'**
  String get errSessionCredentials;

  /// No description provided for @errSessionCredentialsHint.
  ///
  /// In en, this message translates to:
  /// **'If you cannot sign in, change your password in the Premium bot'**
  String get errSessionCredentialsHint;

  /// No description provided for @getHelp.
  ///
  /// In en, this message translates to:
  /// **'Get help'**
  String get getHelp;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{{days} day} other{{days} days}}'**
  String daysLeft(int days);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
