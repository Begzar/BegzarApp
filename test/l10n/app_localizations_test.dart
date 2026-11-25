import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/gen/app_localizations_en.dart';
import 'package:begzar/l10n/gen/app_localizations_ru.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platforms a person reaches the dial on with a mouse.
const _desktops = [
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
];

/// The platforms a person reaches the dial on with a finger.
const _phones = [
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
];

void main() {
  final l10n = AppLocalizationsEn();

  group('AppLocalizationsX.connectionSubtitle', () {
    test('should ask a desktop to click to connect', () {
      for (final platform in _desktops) {
        expect(
          l10n.connectionSubtitle('ready', platform),
          l10n.connSub_readyDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to connect', () {
      for (final platform in _phones) {
        expect(
          l10n.connectionSubtitle('ready', platform),
          l10n.connSub_ready,
          reason: '$platform',
        );
      }
    });

    test('should ask a desktop to click to try again', () {
      for (final platform in _desktops) {
        expect(
          l10n.connectionSubtitle('error', platform),
          l10n.connSub_errorDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to try again', () {
      for (final platform in _phones) {
        expect(
          l10n.connectionSubtitle('error', platform),
          l10n.connSub_error,
          reason: '$platform',
        );
      }
    });

    test('should ask a desktop to click to cancel a connect', () {
      for (final platform in _desktops) {
        expect(
          l10n.connectionSubtitle('connecting', platform),
          l10n.connSub_connectingDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to cancel a connect', () {
      for (final platform in _phones) {
        expect(
          l10n.connectionSubtitle('connecting', platform),
          l10n.connSub_connecting,
          reason: '$platform',
        );
      }
    });

    test(
      'should fall back to the ready line for a status it does not know',
      () {
        expect(
          l10n.connectionSubtitle('unknown', TargetPlatform.macOS),
          l10n.connSub_readyDesktop,
        );
        expect(
          l10n.connectionSubtitle('unknown', TargetPlatform.android),
          l10n.connSub_ready,
        );
      },
    );

    test('should say the same thing on every platform while nothing waits '
        'on a press', () {
      expect(
        l10n.connectionSubtitle('disconnecting', TargetPlatform.macOS),
        l10n.connectionSubtitle('disconnecting', TargetPlatform.android),
      );
    });
  });

  group('AppLocalizationsX.serverRowChooseHintFor', () {
    test('should ask a desktop to click to see the servers', () {
      for (final platform in _desktops) {
        expect(
          l10n.serverRowChooseHintFor(platform),
          l10n.serverRowChooseHintDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to see the servers', () {
      for (final platform in _phones) {
        expect(
          l10n.serverRowChooseHintFor(platform),
          l10n.serverRowChooseHint,
          reason: '$platform',
        );
      }
    });
  });

  group('AppLocalizationsX.tapToTestFor', () {
    test('should ask a desktop to click to measure the ping', () {
      for (final platform in _desktops) {
        expect(
          l10n.tapToTestFor(platform),
          l10n.tapToTestDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to measure the ping', () {
      for (final platform in _phones) {
        expect(
          l10n.tapToTestFor(platform),
          l10n.tapToTest,
          reason: '$platform',
        );
      }
    });
  });

  group('AppLocalizationsX.tapToRetryFor', () {
    test('should ask a desktop to click to measure the ping again', () {
      for (final platform in _desktops) {
        expect(
          l10n.tapToRetryFor(platform),
          l10n.tapToRetryDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap to measure the ping again', () {
      for (final platform in _phones) {
        expect(
          l10n.tapToRetryFor(platform),
          l10n.tapToRetry,
          reason: '$platform',
        );
      }
    });
  });

  group('AppLocalizationsX.premiumServersConnectedHintFor', () {
    test('should ask a desktop to click the connected server', () {
      for (final platform in _desktops) {
        expect(
          l10n.premiumServersConnectedHintFor(platform),
          l10n.premiumServersConnectedHintDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap the connected server', () {
      for (final platform in _phones) {
        expect(
          l10n.premiumServersConnectedHintFor(platform),
          l10n.premiumServersConnectedHint,
          reason: '$platform',
        );
      }
    });
  });

  group('AppLocalizationsX.premiumNoSubscriptionHintFor', () {
    test('should ask a desktop to click Refresh after buying', () {
      for (final platform in _desktops) {
        expect(
          l10n.premiumNoSubscriptionHintFor(platform),
          l10n.premiumNoSubscriptionHintDesktop,
          reason: '$platform',
        );
      }
    });

    test('should ask a phone to tap Refresh after buying', () {
      for (final platform in _phones) {
        expect(
          l10n.premiumNoSubscriptionHintFor(platform),
          l10n.premiumNoSubscriptionHint,
          reason: '$platform',
        );
      }
    });
  });

  // A key with no case of its own falls through to the generic connection
  // failure, which is a sentence about the tunnel shown for anything at all.
  group('AppLocalizationsX.translateError', () {
    test('should give every user-facing key a sentence of its own', () {
      final generic = l10n.translateError(UserFacingErrorKeys.connectionFailed);
      for (final key in UserFacingErrorKeys.all) {
        if (key == UserFacingErrorKeys.connectionFailed) continue;
        expect(l10n.translateError(key), isNot(generic), reason: key);
      }
    });

    test('should name a removed device the way the server refusal does', () {
      expect(
        l10n.translateError(UserFacingErrorKeys.deviceRemoved),
        l10n.translateError(UserFacingErrorKeys.deviceNotRegistered),
      );
    });
  });

  // The same sentence reaches two readers: one the server refused while still
  // signed in, and one the app has already signed out because the seat was
  // taken away. Only the first has a sign-out button to press.
  group('AppLocalizationsX.errorHint', () {
    test('should tell a removed device to sign in again', () {
      expect(
        l10n.errorHint(UserFacingErrorKeys.deviceRemoved),
        l10n.errSessionCredentials,
      );
    });

    test('should still tell a signed-in device to sign out first', () {
      expect(
        l10n.errorHint(UserFacingErrorKeys.deviceNotRegistered),
        l10n.errDeviceNotRegisteredHint,
      );
    });
  });

  // The routing labels once shipped in Russian with English words left in
  // them, whole or inside a sentence, so a Russian reader met English on two
  // screens.
  group('AppLocalizationsRu', () {
    final russian = AppLocalizationsRu();
    final latinLetter = RegExp('[A-Za-z]');

    test('should write the routing labels without a Latin letter', () {
      final labels = <String, String Function(AppLocalizations)>{
        'appRoutingTagDirect': (strings) => strings.appRoutingTagDirect,
        'routingTabDirect': (strings) => strings.routingTabDirect,
        'routingTabBlock': (strings) => strings.routingTabBlock,
        'routingTabProxy': (strings) => strings.routingTabProxy,
        'routingEmptyDirect': (strings) => strings.routingEmptyDirect,
        'routingEmptyBlock': (strings) => strings.routingEmptyBlock,
        'routingEmptyProxy': (strings) => strings.routingEmptyProxy,
      };
      for (final MapEntry(key: name, value: read) in labels.entries) {
        expect(read(russian), isNot(contains(latinLetter)), reason: name);
      }
    });
  });
}
