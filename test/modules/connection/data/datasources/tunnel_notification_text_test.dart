import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_notification_text.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tunnelNotificationText', () {
    test('should take every string from the localizations it is given', () {
      final english = lookupAppLocalizations(const Locale('en'));

      final text = tunnelNotificationText(english, vpnMode: true);

      expect(text.title, english.notifTunnelTitle);
      expect(text.disconnectLabel, english.disconnect);
      expect(text.channelName, english.notifTunnelChannelName);
      expect(text.channelDescription, english.notifTunnelChannelDescription);
    });

    test('should name the mode the tunnel is running in', () {
      final english = lookupAppLocalizations(const Locale('en'));

      expect(
        tunnelNotificationText(english, vpnMode: true).body,
        english.notifTunnelVpnMode,
      );
      expect(
        tunnelNotificationText(english, vpnMode: false).body,
        english.notifTunnelProxyMode,
      );
    });

    test('should follow the locale rather than a baked-in language', () {
      final english = lookupAppLocalizations(const Locale('en'));
      final persian = lookupAppLocalizations(const Locale('fa'));

      final inEnglish = tunnelNotificationText(english, vpnMode: true);
      final inPersian = tunnelNotificationText(persian, vpnMode: true);

      expect(inPersian.title, persian.notifTunnelTitle);
      expect(inPersian.title, isNot(inEnglish.title));
      expect(inPersian.disconnectLabel, isNot(inEnglish.disconnectLabel));
    });
  });
}
