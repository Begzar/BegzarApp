import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/controllers/pending_premium_plan_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = PremiumPlan(
  devices: 2,
  productId: 'premium_2_devices',
  basePlanId: 'quarterly',
);

void main() {
  group('PendingPremiumPlanNotifier', () {
    test('should hand the remembered plan over once', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final pending = container.read(pendingPremiumPlanProvider.notifier);

      pending.remember(_plan);

      expect(pending.take(), _plan);
      expect(pending.take(), isNull);
      expect(container.read(pendingPremiumPlanProvider), isNull);
    });

    // A second tap on the same plan is a second request to sign in, and the
    // root screen only moves to the sign-in form when it is told.
    test('should tell listeners about the same plan remembered twice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var requests = 0;
      container.listen(pendingPremiumPlanProvider, (_, next) {
        if (next != null) requests++;
      });
      final pending = container.read(pendingPremiumPlanProvider.notifier);

      pending.remember(_plan);
      pending.remember(_plan);

      expect(requests, 2);
    });
  });
}
