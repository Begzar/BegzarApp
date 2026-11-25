import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// The ongoing tunnel notification's wording, in the app's current language.
///
/// `begzar_engine` posts the notification but ships no locales and no product
/// name, so every string on it is resolved here and handed over. A default
/// inside the plugin would reach three quarters of our users in a language
/// they did not pick.
BegzarNotificationText tunnelNotificationText(
  AppLocalizations l10n, {
  required bool vpnMode,
}) {
  return BegzarNotificationText(
    title: l10n.notifTunnelTitle,
    body: vpnMode ? l10n.notifTunnelVpnMode : l10n.notifTunnelProxyMode,
    disconnectLabel: l10n.disconnect,
    channelName: l10n.notifTunnelChannelName,
    channelDescription: l10n.notifTunnelChannelDescription,
  );
}
