import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/play_account_tag.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/play_purchase_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../premium_test_doubles.dart';

const _username = 'reader@example.com';

const _session = PremiumSession(
  accessKey: 'key',
  account: PremiumAccount(username: _username),
);

/// A container with the purchase listener started and the launch restore
/// settled.
Future<ProviderContainer> _started(
  FakePremiumRepository premium,
  FakeGooglePlayBillingRepository billing,
) async {
  final container = ProviderContainer(
    overrides: [
      premiumRepositoryProvider.overrideWithValue(premium),
      googlePlayBillingRepositoryProvider.overrideWithValue(billing),
    ],
  );
  addTearDown(container.dispose);
  container.read(playPurchaseProvider);
  await container.read(premiumProvider.notifier).ensureRestored();
  await pumpEventQueue();
  return container;
}

void main() {
  group('PlayPurchaseNotifier', () {
    test('should refresh the account once a purchase is granted', () async {
      final premium = FakePremiumRepository(session: _session);
      final billing = FakeGooglePlayBillingRepository();
      final container = await _started(premium, billing);
      final paidAccount = PremiumAccount(
        username: _username,
        expireDate: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      );
      premium.refreshResult = right(paidAccount);

      billing.purchaseUpdates.add([
        PlayPurchase(
          productId: 'premium_1_device',
          purchaseToken: 'token',
          state: PlayPurchaseState.purchased,
          accountTag: playAccountTag(_username),
          isAcknowledged: false,
        ),
      ]);
      await pumpEventQueue();

      expect(container.read(premiumProvider).account, paidAccount);
    });

    test('should restore when started', () async {
      final billing = FakeGooglePlayBillingRepository();

      await _started(FakePremiumRepository(), billing);

      expect(billing.restoreCount, 1);
    });

    test('should restore after a fresh sign-in', () async {
      final premium = FakePremiumRepository(signInResult: right(_session));
      final billing = FakeGooglePlayBillingRepository();
      final container = await _started(premium, billing);

      await container
          .read(premiumProvider.notifier)
          .login(_username, 'correct horse');
      await pumpEventQueue();

      expect(billing.restoreCount, 2);
    });
  });
}
