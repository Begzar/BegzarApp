import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/controllers/pending_premium_plan_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_paywall_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_paywall_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

const _session = PremiumSession(
  accessKey: 'key',
  account: PremiumAccount(username: 'reader@example.com'),
);

/// Two dollars a device a month, a little less a month for longer.
const _dollarsPerDeviceMonth = 2;
const _microsPerDollar = 1000000;
const _discountByMonths = {1: 1.0, 3: 0.95, 6: 0.9, 12: 0.8};

PremiumPlanOffer _offer(int devices, int months, {bool discounted = true}) =>
    PremiumPlanOffer(
      plan: PremiumPlan(
        devices: devices,
        productId: 'premium_${devices}_devices',
        basePlanId: 'every_${months}_months',
      ),
      price: '\$$devices.$months',
      months: months,
      priceMicros:
          (devices *
                  months *
                  _dollarsPerDeviceMonth *
                  _microsPerDollar *
                  (discounted ? _discountByMonths[months]! : 1))
              .round(),
      currencyCode: 'USD',
    );

/// Two device counts; only one device is sold for a year.
final _offers = [
  _offer(2, 3),
  _offer(1, 12),
  _offer(1, 3),
  _offer(2, 1),
  _offer(1, 1),
];

PlayPurchase _report(PlayPurchaseState state) => PlayPurchase(
  productId: 'premium_1_devices',
  purchaseToken: '',
  state: state,
  accountTag: null,
  isAcknowledged: false,
);

/// A container whose paywall stays alive between calls. It is auto-disposed,
/// and nothing on screen is listening in a test.
ProviderContainer _container({
  FakePremiumRepository? premium,
  required FakeGooglePlayBillingRepository billing,
  RecordingAnalytics? analytics,
}) {
  final container = ProviderContainer(
    overrides: [
      premiumRepositoryProvider.overrideWithValue(
        premium ?? FakePremiumRepository(session: _session),
      ),
      googlePlayBillingRepositoryProvider.overrideWithValue(billing),
      analyticsServiceProvider.overrideWithValue(
        analytics ?? RecordingAnalytics(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(premiumPaywallProvider, (_, _) {});
  return container;
}

void main() {
  group('PremiumPaywallNotifier.load', () {
    test('should open on three devices and their best value', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right([
          ..._offers,
          _offer(3, 1),
          _offer(3, 3),
          _offer(3, 12),
        ]),
      );
      final container = _container(billing: billing);

      await container.read(premiumPaywallProvider.notifier).load();

      expect(container.read(premiumPaywallProvider).selected, _offer(3, 12));
    });

    test('should open on the fewest devices when three are not sold', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing);

      await container.read(premiumPaywallProvider.notifier).load();

      final state = container.read(premiumPaywallProvider);
      expect(state.isLoading, isFalse);
      expect(state.selected, _offer(1, 12));
      expect(state.offers.keys, [1, 2]);
      expect(state.periods.map((offer) => offer.months), [1, 3, 12]);
    });

    test('should open on the shortest period when no period saves', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right([
          _offer(1, 12, discounted: false),
          _offer(1, 1, discounted: false),
        ]),
      );
      final container = _container(billing: billing);

      await container.read(premiumPaywallProvider.notifier).load();

      expect(
        container.read(premiumPaywallProvider).selected,
        _offer(1, 1, discounted: false),
      );
    });

    test('should open on the plan it was asked to select', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing);

      await container
          .read(premiumPaywallProvider.notifier)
          .load(selecting: _offer(2, 3).plan);

      expect(container.read(premiumPaywallProvider).selected, _offer(2, 3));
    });

    test('should show unavailable with no offers', () async {
      final container = _container(billing: FakeGooglePlayBillingRepository());

      await container.read(premiumPaywallProvider.notifier).load();

      expect(container.read(premiumPaywallProvider).isUnavailable, isTrue);
    });

    test('should show unavailable when the plans cannot be read', () async {
      final container = _container(
        billing: FakeGooglePlayBillingRepository(
          offersResult: left(const NetworkFailure()),
        ),
      );

      await container.read(premiumPaywallProvider.notifier).load();

      expect(container.read(premiumPaywallProvider).isUnavailable, isTrue);
    });
  });

  group('PremiumPaywallNotifier.selectDevices', () {
    test(
      'should keep the period when the device count changes if it is offered',
      () async {
        final container = _container(
          billing: FakeGooglePlayBillingRepository(
            offersResult: right(_offers),
          ),
        );
        final paywall = container.read(premiumPaywallProvider.notifier);
        await paywall.load();

        paywall.selectMonths(3);
        paywall.selectDevices(2);

        expect(container.read(premiumPaywallProvider).selected, _offer(2, 3));
      },
    );

    test('should fall back to the shortest period when the device count does '
        'not offer the one selected', () async {
      final container = _container(
        billing: FakeGooglePlayBillingRepository(offersResult: right(_offers)),
      );
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();

      paywall.selectMonths(12);
      paywall.selectDevices(2);

      expect(container.read(premiumPaywallProvider).selected, _offer(2, 1));
    });
  });

  group('PremiumPaywallNotifier.subscribe', () {
    test(
      'should remember the plan and ask for a sign-in when signed out',
      () async {
        final billing = FakeGooglePlayBillingRepository(
          offersResult: right(_offers),
        );
        final container = _container(
          premium: FakePremiumRepository(),
          billing: billing,
        );
        final paywall = container.read(premiumPaywallProvider.notifier);
        await paywall.load();

        final result = await paywall.subscribe();

        expect(result, PaywallSubscribe.needsSignIn);
        expect(container.read(pendingPremiumPlanProvider), _offer(1, 12).plan);
        expect(billing.bought, isEmpty);
        expect(container.read(premiumPaywallProvider).isPurchasing, isFalse);
      },
    );

    test('should start one purchase for a double tap', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      )..holdBuy = Completer<bool>();
      final container = _container(billing: billing);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();

      final first = paywall.subscribe();
      final second = paywall.subscribe();
      await pumpEventQueue();
      billing.holdBuy!.complete(true);

      expect(await first, PaywallSubscribe.started);
      expect(await second, PaywallSubscribe.started);
      expect(billing.bought, hasLength(1));
      expect(container.read(premiumPaywallProvider).isPurchasing, isTrue);
    });

    test('should report a failure when Play will not open', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      )..holdBuy = (Completer<bool>()..complete(false));
      final container = _container(billing: billing);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();

      final result = await paywall.subscribe();

      final state = container.read(premiumPaywallProvider);
      expect(result, PaywallSubscribe.refused);
      expect(state.isPurchasing, isFalse);
      expect(state.outcome, PlayPurchaseOutcome.failed);
    });
  });

  group('PremiumPaywallNotifier outcomes', () {
    test(
      "should stop purchasing quietly when the buyer closes Play's sheet",
      () async {
        final billing = FakeGooglePlayBillingRepository(
          offersResult: right(_offers),
        );
        final container = _container(billing: billing);
        final paywall = container.read(premiumPaywallProvider.notifier);
        await paywall.load();
        await paywall.subscribe();

        billing.purchaseUpdates.add([_report(PlayPurchaseState.canceled)]);
        await pumpEventQueue();

        final state = container.read(premiumPaywallProvider);
        expect(state.isPurchasing, isFalse);
        expect(state.outcome, isNull);
      },
    );

    test('should show a pending purchase', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();
      await paywall.subscribe();

      billing.purchaseUpdates.add([_report(PlayPurchaseState.pending)]);
      await pumpEventQueue();

      final state = container.read(premiumPaywallProvider);
      expect(state.isPurchasing, isFalse);
      expect(state.outcome, PlayPurchaseOutcome.pending);
    });

    // A restore at launch or after a sign-in reports purchases this paywall
    // never started; telling the buyer about those reads as news of theirs.
    test('should ignore an outcome of a purchase it did not start', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing);
      await container.read(premiumPaywallProvider.notifier).load();

      billing.purchaseUpdates.add([_report(PlayPurchaseState.pending)]);
      await pumpEventQueue();

      expect(container.read(premiumPaywallProvider).outcome, isNull);
    });

    test('should follow a pending purchase it started to its end', () async {
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();
      await paywall.subscribe();

      billing.purchaseUpdates.add([_report(PlayPurchaseState.pending)]);
      await pumpEventQueue();
      billing.purchaseUpdates.add([_report(PlayPurchaseState.failed)]);
      await pumpEventQueue();

      expect(
        container.read(premiumPaywallProvider).outcome,
        PlayPurchaseOutcome.failed,
      );
    });
  });

  group('what analytics is told', () {
    test(
      'should record the paywall opening with how many plans it had',
      () async {
        final analytics = RecordingAnalytics();
        final container = _container(
          billing: FakeGooglePlayBillingRepository(
            offersResult: right(_offers),
          ),
          analytics: analytics,
        );

        await container.read(premiumPaywallProvider.notifier).load();

        expect(analytics.callsTo(#logPaywallOpened), [
          {#plans: 5},
        ]);
      },
    );

    test('should record a checkout once Play has opened its sheet', () async {
      final analytics = RecordingAnalytics();
      final container = _container(
        billing: FakeGooglePlayBillingRepository(offersResult: right(_offers)),
        analytics: analytics,
      );
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();

      await paywall.subscribe();

      expect(analytics.callsTo(#logBeginCheckout), [
        {#devices: 1, #months: 12},
      ]);
    });

    test('should record a sheet that would not open as a failure', () async {
      final analytics = RecordingAnalytics();
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      )..holdBuy = (Completer<bool>()..complete(false));
      final container = _container(billing: billing, analytics: analytics);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();

      await paywall.subscribe();

      expect(analytics.callsTo(#logBeginCheckout), isEmpty);
      expect(analytics.callsTo(#logPlayPurchaseResult), [
        {#outcome: 'failed', #devices: 1, #months: 12},
      ]);
    });

    test('should record how a purchase it started ended', () async {
      final analytics = RecordingAnalytics();
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing, analytics: analytics);
      final paywall = container.read(premiumPaywallProvider.notifier);
      await paywall.load();
      await paywall.subscribe();

      billing.purchaseUpdates.add([_report(PlayPurchaseState.canceled)]);
      await pumpEventQueue();

      expect(analytics.callsTo(#logPlayPurchaseResult), [
        {#outcome: 'canceled', #devices: 1, #months: 12},
      ]);
    });

    test('should record nothing for a purchase it did not start', () async {
      final analytics = RecordingAnalytics();
      final billing = FakeGooglePlayBillingRepository(
        offersResult: right(_offers),
      );
      final container = _container(billing: billing, analytics: analytics);
      await container.read(premiumPaywallProvider.notifier).load();

      billing.purchaseUpdates.add([_report(PlayPurchaseState.pending)]);
      await pumpEventQueue();

      expect(analytics.callsTo(#logPlayPurchaseResult), isEmpty);
    });
  });
}
