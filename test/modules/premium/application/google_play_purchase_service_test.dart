import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/application/services/google_play_purchase_service.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/play_account_tag.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../premium_test_doubles.dart';

const _username = 'reader@example.com';

const _plan = PremiumPlan(
  devices: 1,
  productId: 'premium_1_device',
  basePlanId: 'monthly',
);

final _ownTag = playAccountTag(_username);

PlayPurchase _purchase({
  PlayPurchaseState state = PlayPurchaseState.purchased,
  String? accountTag,
  bool acknowledged = false,
}) => PlayPurchase(
  productId: 'premium_1_device',
  purchaseToken: 'token',
  state: state,
  accountTag: accountTag ?? _ownTag,
  isAcknowledged: acknowledged,
);

FakePremiumRepository _signedIn() => FakePremiumRepository(
  session: const PremiumSession(
    accessKey: 'key',
    account: PremiumAccount(username: _username),
  ),
);

/// A signed-in repository whose storage gives way while a purchase is
/// reported.
class _ThrowingReportRepository extends FakePremiumRepository {
  _ThrowingReportRepository()
    : super(
        session: const PremiumSession(
          accessKey: 'key',
          account: PremiumAccount(username: _username),
        ),
      );

  @override
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async => throw StateError('storage unavailable');
}

/// A billing client that drops the connection while acknowledging.
class _ThrowingCompleteBilling extends FakeGooglePlayBillingRepository {
  @override
  Future<void> complete(PlayPurchase purchase) async =>
      throw StateError('billing client disconnected');
}

/// A started service with its outcomes collected.
Future<(GooglePlayPurchaseService, List<PlayPurchaseOutcome>)> _started(
  FakeGooglePlayBillingRepository billing,
  FakePremiumRepository premium,
) async {
  final service = GooglePlayPurchaseService(billing: billing, premium: premium);
  addTearDown(service.dispose);
  final outcomes = <PlayPurchaseOutcome>[];
  service.outcomes.listen(outcomes.add);
  await service.start();
  return (service, outcomes);
}

/// Pushes [purchase] and waits for the service to have dealt with it.
Future<void> _deliver(
  FakeGooglePlayBillingRepository billing,
  PlayPurchase purchase,
) async {
  billing.purchaseUpdates.add([purchase]);
  await pumpEventQueue();
}

void main() {
  group('GooglePlayPurchaseService', () {
    test(
      'should report, complete and announce a purchase the server granted',
      () async {
        final billing = FakeGooglePlayBillingRepository();
        final premium = _signedIn();
        final (_, outcomes) = await _started(billing, premium);

        await _deliver(billing, _purchase());

        expect(premium.reportedPurchases, [('premium_1_device', 'token')]);
        expect(billing.completed, hasLength(1));
        expect(outcomes, [PlayPurchaseOutcome.granted]);
      },
    );

    test('should leave a purchase uncompleted when the report fails', () async {
      final billing = FakeGooglePlayBillingRepository();
      final premium = _signedIn()
        ..purchaseReportResult = left(const NetworkFailure());
      final (_, outcomes) = await _started(billing, premium);

      await _deliver(billing, _purchase());

      expect(billing.completed, isEmpty);
      expect(outcomes, [PlayPurchaseOutcome.confirmLater]);
    });

    test(
      'should announce failed when the server refuses the purchase',
      () async {
        final billing = FakeGooglePlayBillingRepository();
        final premium = _signedIn()
          ..purchaseReportResult = left(
            const ServerFailure(
              'invalid_purchase',
              statusCode: 422,
              serverError: 'invalid_purchase',
            ),
          );
        final (_, outcomes) = await _started(billing, premium);

        await _deliver(billing, _purchase());

        expect(billing.completed, isEmpty);
        expect(outcomes, [PlayPurchaseOutcome.failed]);
      },
    );

    test(
      'should announce confirm-later when reporting the purchase throws',
      () async {
        final billing = FakeGooglePlayBillingRepository();
        final (_, outcomes) = await _started(
          billing,
          _ThrowingReportRepository(),
        );

        await _deliver(billing, _purchase());

        expect(billing.completed, isEmpty);
        expect(outcomes, [PlayPurchaseOutcome.confirmLater]);
      },
    );

    test(
      'should announce a granted purchase whose acknowledgement throws',
      () async {
        final billing = _ThrowingCompleteBilling();
        final (_, outcomes) = await _started(billing, _signedIn());

        await _deliver(billing, _purchase());

        expect(outcomes, [PlayPurchaseOutcome.granted]);
      },
    );

    test("should leave another account's purchase alone", () async {
      final billing = FakeGooglePlayBillingRepository();
      final premium = _signedIn();
      final (_, outcomes) = await _started(billing, premium);

      await _deliver(
        billing,
        _purchase(accountTag: playAccountTag('other@example.com')),
      );

      expect(premium.reportedPurchases, isEmpty);
      expect(billing.completed, isEmpty);
      expect(outcomes, isEmpty);
    });

    test('should leave a purchase alone with nobody signed in', () async {
      final billing = FakeGooglePlayBillingRepository();
      final premium = FakePremiumRepository();
      final (_, outcomes) = await _started(billing, premium);

      await _deliver(billing, _purchase());

      expect(billing.completed, isEmpty);
      expect(outcomes, isEmpty);
    });

    test('should leave an acknowledged purchase alone', () async {
      final billing = FakeGooglePlayBillingRepository();
      final premium = _signedIn();
      final (_, outcomes) = await _started(billing, premium);

      await _deliver(billing, _purchase(acknowledged: true));

      expect(premium.reportedPurchases, isEmpty);
      expect(outcomes, isEmpty);
    });

    test('should announce a pending purchase', () async {
      final billing = FakeGooglePlayBillingRepository();
      final (_, outcomes) = await _started(billing, _signedIn());

      await _deliver(billing, _purchase(state: PlayPurchaseState.pending));

      expect(outcomes, [PlayPurchaseOutcome.pending]);
    });

    test('should announce already owned', () async {
      final billing = FakeGooglePlayBillingRepository();
      final (_, outcomes) = await _started(billing, _signedIn());

      await _deliver(billing, _purchase(state: PlayPurchaseState.alreadyOwned));

      expect(outcomes, [PlayPurchaseOutcome.alreadyOwned]);
    });

    test("should buy with the signed-in account's tag", () async {
      final billing = FakeGooglePlayBillingRepository();
      final (service, _) = await _started(billing, _signedIn());

      final started = await service.buy(_plan);

      expect(started, isTrue);
      expect(billing.bought, [(_plan, _ownTag)]);
    });

    test('should not buy with nobody signed in', () async {
      final billing = FakeGooglePlayBillingRepository();
      final (service, _) = await _started(billing, FakePremiumRepository());

      expect(await service.buy(_plan), isFalse);
      expect(billing.bought, isEmpty);
    });

    test('should restore when started', () async {
      final billing = FakeGooglePlayBillingRepository();

      await _started(billing, _signedIn());

      expect(billing.restoreCount, 1);
    });
  });
}
