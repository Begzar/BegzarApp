import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:flutter_test/flutter_test.dart';

String _activeExpiry() =>
    DateTime.now().add(const Duration(days: 30)).toIso8601String();

String _lapsedExpiry() =>
    DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

PremiumAccount _account({required String expireDate, String? statusLabel}) =>
    PremiumAccount(
      username: 'user',
      expireDate: expireDate,
      statusLabel: statusLabel,
    );

void main() {
  group('AccountStatus.labelOf', () {
    test('normalizes the shapes the API sends', () {
      expect(AccountStatus.labelOf(true), 'true');
      expect(AccountStatus.labelOf(false), 'false');
      expect(AccountStatus.labelOf(1), 'true');
      expect(AccountStatus.labelOf(0), 'false');
      expect(AccountStatus.labelOf('  Active '), 'active');
      expect(AccountStatus.labelOf('DISABLED'), 'disabled');
    });

    test('treats an absent or blank status as no status at all', () {
      expect(AccountStatus.labelOf(null), isNull);
      expect(AccountStatus.labelOf('   '), isNull);
    });
  });

  group('AccountStatus.parse', () {
    test('an omitted status means active, for accounts that predate it', () {
      expect(AccountStatus.parse(null), AccountStatus.active);
      expect(AccountStatus.parse(''), AccountStatus.active);
    });

    test('recognizes every inactive label', () {
      for (final label in [
        'false',
        '0',
        'inactive',
        'disabled',
        'suspended',
        'banned',
        'expired',
      ]) {
        expect(
          AccountStatus.parse(label),
          AccountStatus.inactive,
          reason: label,
        );
      }
    });

    test('an unrecognized label is treated as active', () {
      expect(AccountStatus.parse('grandfathered'), AccountStatus.active);
    });
  });

  group('entitlement', () {
    test('active status and an unexpired subscription is entitled', () {
      final account = _account(
        expireDate: _activeExpiry(),
        statusLabel: 'true',
      );

      expect(account.isSubscriptionActive, isTrue);
      expect(account.isEntitled, isTrue);
    });

    test('a lapsed subscription is not entitled', () {
      final account = _account(
        expireDate: _lapsedExpiry(),
        statusLabel: 'true',
      );

      expect(account.isSubscriptionActive, isFalse);
      expect(account.isEntitled, isFalse);
    });

    test('a disabled account is not entitled even while paid up', () {
      final account = _account(
        expireDate: _activeExpiry(),
        statusLabel: 'disabled',
      );

      expect(account.isSubscriptionActive, isTrue);
      expect(account.isEntitled, isFalse);
    });

    test('an unparsable expiry date is not entitled', () {
      final account = _account(expireDate: 'soon', statusLabel: 'true');

      expect(account.expiresAt, isNull);
      expect(account.isEntitled, isFalse);
    });
  });

  // An account created in the app exists before anything has been paid for
  // it, and the server says so by sending no expiry at all.
  group('PremiumAccount.neverSubscribed', () {
    test('should read an account without an expiry as never subscribed', () {
      const account = PremiumAccount(username: 'user', statusLabel: 'true');

      expect(account.neverSubscribed, isTrue);
      expect(account.isSubscriptionActive, isFalse);
      expect(account.isEntitled, isFalse);
    });

    test('should not read a lapsed account as never subscribed', () {
      final account = _account(
        expireDate: _lapsedExpiry(),
        statusLabel: 'true',
      );

      expect(account.neverSubscribed, isFalse);
    });
  });
}
