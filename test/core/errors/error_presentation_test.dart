import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  group('ErrorPresentation.fromKey', () {
    test('clock skew has a timezone hint and no premium help', () {
      final shown = ErrorPresentation.fromKey(
        UserFacingErrorKeys.clockSkew,
        l10n,
      );
      expect(shown.message, l10n.errClockSkew);
      expect(shown.hint, l10n.errClockSkewHint);
      expect(shown.showPremiumHelp, isFalse);
    });

    test('free-tier keys never open the premium bot', () {
      const freeKeys = [
        UserFacingErrorKeys.clockSkew,
        UserFacingErrorKeys.requestUnverified,
        UserFacingErrorKeys.replayDetected,
        UserFacingErrorKeys.ipBlocked,
        UserFacingErrorKeys.missingSession,
        UserFacingErrorKeys.deviceInitFailed,
        UserFacingErrorKeys.rateLimit,
      ];
      for (final key in freeKeys) {
        expect(
          ErrorPresentation.fromKey(key, l10n).showPremiumHelp,
          isFalse,
          reason: key,
        );
        expect(
          ErrorPresentation.fromKey(key, l10n).hint,
          isNotNull,
          reason: key,
        );
      }
    });

    test('premium account keys show Get help', () {
      const helpKeys = [
        UserFacingErrorKeys.invalidCredentials,
        UserFacingErrorKeys.sessionCredentials,
        UserFacingErrorKeys.deviceLimit,
        UserFacingErrorKeys.accountDisabled,
        UserFacingErrorKeys.accountExpired,
      ];
      for (final key in helpKeys) {
        final shown = ErrorPresentation.fromKey(key, l10n);
        expect(shown.showPremiumHelp, isTrue, reason: key);
        expect(shown.hint, isNotNull, reason: key);
      }
    });

    test('rate limit uses retry_after seconds when provided', () {
      final shown = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
        retryAfterSeconds: 42,
      );
      expect(shown.hint, l10n.errRateLimitWait(42));
    });
  });
}
