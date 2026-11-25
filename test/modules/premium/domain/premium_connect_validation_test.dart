import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
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
  test('an active account with time left is allowed', () {
    final verdict = PremiumConnectValidation.forAccount(
      _account(expireDate: _activeExpiry(), statusLabel: 'true'),
    );

    expect(verdict, PremiumConnectValidation.allowed);
  });

  test('a lapsed subscription is rejected as expired', () {
    final verdict = PremiumConnectValidation.forAccount(
      _account(expireDate: _lapsedExpiry(), statusLabel: 'true'),
    );

    expect(verdict, PremiumConnectValidation.subscriptionExpired);
  });

  test('a disabled account reports the disabling, not the expiry', () {
    final verdict = PremiumConnectValidation.forAccount(
      _account(expireDate: _activeExpiry(), statusLabel: 'disabled'),
    );

    expect(verdict, PremiumConnectValidation.accountInactive);
  });

  test('a disabled account that has also lapsed still reports inactive', () {
    final verdict = PremiumConnectValidation.forAccount(
      _account(expireDate: _lapsedExpiry(), statusLabel: 'disabled'),
    );

    expect(
      verdict,
      PremiumConnectValidation.accountInactive,
      reason: 'renewing would not help; the account itself is disabled',
    );
  });

  group('PremiumConnectValidation.forAccount on a never-paid account', () {
    test('should refuse a never-subscribed account as not subscribed', () {
      final verdict = PremiumConnectValidation.forAccount(
        const PremiumAccount(username: 'user', statusLabel: 'true'),
      );

      expect(verdict, PremiumConnectValidation.notSubscribed);
    });

    test('should report a disabled never-subscribed account as inactive', () {
      final verdict = PremiumConnectValidation.forAccount(
        const PremiumAccount(username: 'user', statusLabel: 'disabled'),
      );

      expect(verdict, PremiumConnectValidation.accountInactive);
    });
  });
}
