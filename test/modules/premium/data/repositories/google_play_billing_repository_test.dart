import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/datasources/google_play_billing_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/repositories/google_play_billing_repository.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

const _monthly = PremiumPlan(
  devices: 1,
  productId: 'premium_1_device',
  basePlanId: 'monthly',
);

const _yearly = PremiumPlan(
  devices: 1,
  productId: 'premium_1_device',
  basePlanId: 'yearly',
);

SubscriptionOfferDetailsWrapper _offer({
  required String basePlanId,
  required String period,
  required String price,
  String? offerId,
  int priceMicros = 0,
  String currencyCode = 'USD',
}) => SubscriptionOfferDetailsWrapper(
  basePlanId: basePlanId,
  offerId: offerId,
  offerTags: const [],
  offerIdToken: '$basePlanId-${offerId ?? 'base'}',
  pricingPhases: [
    PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: period,
      formattedPrice: price,
      priceAmountMicros: priceMicros,
      priceCurrencyCode: currencyCode,
      recurrenceMode: RecurrenceMode.infiniteRecurring,
    ),
  ],
);

List<GooglePlayProductDetails> _product(
  List<SubscriptionOfferDetailsWrapper> offers,
) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: '',
    name: 'Premium',
    productId: 'premium_1_device',
    productType: ProductType.subs,
    subscriptionOfferDetails: offers,
    title: 'Premium',
  ),
);

GooglePlayPurchaseDetails _purchase({
  PurchaseStateWrapper state = PurchaseStateWrapper.purchased,
  bool acknowledged = false,
  String? accountTag = 'tag',
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: 'order',
    packageName: 'cloud.begzar.begzar',
    purchaseTime: 0,
    purchaseToken: 'token',
    signature: '',
    products: const ['premium_1_device'],
    isAutoRenewing: true,
    originalJson: '{}',
    isAcknowledged: acknowledged,
    purchaseState: state,
    obfuscatedAccountId: accountTag,
  ),
).single;

/// Answers as Play would, from a script, and keeps what was asked of it.
class _FakeBilling extends GooglePlayBillingDataSource {
  _FakeBilling({this.available = true, this.products = const []});

  final bool available;
  final List<GooglePlayProductDetails> products;
  final purchaseUpdates = StreamController<List<PurchaseDetails>>.broadcast();
  final List<(GooglePlayProductDetails, String)> bought = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<GooglePlayProductDetails>> queryProducts(Set<String> ids) async =>
      products;

  @override
  Future<bool> buy(
    GooglePlayProductDetails product, {
    required String accountTag,
  }) async {
    bought.add((product, accountTag));
    return true;
  }

  @override
  Stream<List<PurchaseDetails>> get purchases => purchaseUpdates.stream;
}

/// Answers the plan catalogue with whatever the test lists.
class _PlansRemote extends PremiumRemoteDataSource {
  _PlansRemote(this.plans);

  final List<PremiumPlan> plans;

  @override
  Future<Either<ApiFailure, List<PremiumPlan>>> fetchPlans() async =>
      right(plans);
}

GooglePlayBillingRepository _repository(
  _FakeBilling billing, [
  List<PremiumPlan> plans = const [_monthly, _yearly],
]) =>
    GooglePlayBillingRepository(billing: billing, remote: _PlansRemote(plans));

Future<List<PremiumPlanOffer>> _offers(
  GooglePlayBillingRepository repository,
) async =>
    (await repository.loadOffers()).getOrElse((failure) => fail('$failure'));

void main() {
  group('GooglePlayBillingRepository.loadOffers', () {
    test('should price each plan from its base plan', () async {
      final repository = _repository(
        _FakeBilling(
          products: _product([
            _offer(basePlanId: 'monthly', period: 'P1M', price: r'$4.99'),
            _offer(basePlanId: 'yearly', period: 'P1Y', price: r'$39.99'),
          ]),
        ),
      );

      final offers = await _offers(repository);

      expect(offers.map((offer) => (offer.plan, offer.price, offer.months)), [
        (_monthly, r'$4.99', 1),
        (_yearly, r'$39.99', 12),
      ]);
    });

    // What a month costs is worked out from these, and Play's formatted
    // string cannot be read back into a number in every locale.
    test("should carry the base plan's amount and currency", () async {
      final repository = _repository(
        _FakeBilling(
          products: _product([
            _offer(
              basePlanId: 'yearly',
              period: 'P1Y',
              price: '€39,99',
              priceMicros: 39990000,
              currencyCode: 'EUR',
            ),
          ]),
        ),
        [_yearly],
      );

      final offer = (await _offers(repository)).single;

      expect(offer.priceMicros, 39990000);
      expect(offer.currencyCode, 'EUR');
    });

    test('should ignore a trial offer beside the base plan', () async {
      final repository = _repository(
        _FakeBilling(
          products: _product([
            _offer(
              basePlanId: 'monthly',
              period: 'P1M',
              price: 'Free',
              offerId: 'trial',
            ),
            _offer(basePlanId: 'monthly', period: 'P1M', price: r'$4.99'),
          ]),
        ),
        [_monthly],
      );

      final offers = await _offers(repository);

      expect(offers.single.price, r'$4.99');
    });

    test('should drop a plan Play does not know', () async {
      final repository = _repository(
        _FakeBilling(
          products: _product([
            _offer(basePlanId: 'monthly', period: 'P1M', price: r'$4.99'),
          ]),
        ),
      );

      final offers = await _offers(repository);

      expect(offers.map((offer) => offer.plan), [_monthly]);
    });

    test('should offer nothing when billing is unavailable', () async {
      final repository = _repository(
        _FakeBilling(
          available: false,
          products: _product([
            _offer(basePlanId: 'monthly', period: 'P1M', price: r'$4.99'),
          ]),
        ),
      );

      expect(await _offers(repository), isEmpty);
    });
  });

  group('GooglePlayBillingRepository.buy', () {
    test("should buy with the plan's own offer and the account tag", () async {
      final billing = _FakeBilling(
        products: _product([
          _offer(basePlanId: 'monthly', period: 'P1M', price: r'$4.99'),
          _offer(basePlanId: 'yearly', period: 'P1Y', price: r'$39.99'),
        ]),
      );
      final repository = _repository(billing);
      await _offers(repository);

      final started = await repository.buy(_yearly, 'tag');

      expect(started, isTrue);
      expect(billing.bought.single.$1.offerToken, 'yearly-base');
      expect(billing.bought.single.$2, 'tag');
    });

    test('should not buy a plan it has not priced', () async {
      final billing = _FakeBilling();
      final repository = _repository(billing);

      expect(await repository.buy(_yearly, 'tag'), isFalse);
      expect(billing.bought, isEmpty);
    });
  });

  group('GooglePlayBillingRepository.purchases', () {
    test('should read a restored purchase as purchased', () async {
      final billing = _FakeBilling();
      final repository = _repository(billing);
      final next = repository.purchases.first;

      billing.purchaseUpdates.add([
        _purchase(acknowledged: true)..status = PurchaseStatus.restored,
      ]);
      final purchase = (await next).single;

      expect(purchase.state, PlayPurchaseState.purchased);
      expect(purchase.isAcknowledged, isTrue);
      expect(purchase.accountTag, 'tag');
      expect(purchase.purchaseToken, 'token');
    });

    // The plugin marks everything a restore returns as restored, a payment
    // that has not cleared included; only Play's own state tells them apart.
    test('should read a restored purchase still clearing as pending', () async {
      final billing = _FakeBilling();
      final repository = _repository(billing);
      final next = repository.purchases.first;

      billing.purchaseUpdates.add([
        _purchase(state: PurchaseStateWrapper.pending)
          ..status = PurchaseStatus.restored,
      ]);
      final purchase = (await next).single;

      expect(purchase.state, PlayPurchaseState.pending);
    });

    test('should read itemAlreadyOwned as already owned', () async {
      final billing = _FakeBilling();
      final repository = _repository(billing);
      final next = repository.purchases.first;

      billing.purchaseUpdates.add([
        PurchaseDetails(
            productID: '',
            verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: '',
              source: 'google_play',
            ),
            transactionDate: null,
            status: PurchaseStatus.error,
          )
          ..error = IAPError(
            source: 'google_play',
            code: 'purchase_error',
            message: 'BillingResponse.itemAlreadyOwned',
          ),
      ]);

      expect((await next).single.state, PlayPurchaseState.alreadyOwned);
    });

    test('should read a pending purchase as pending', () async {
      final billing = _FakeBilling();
      final repository = _repository(billing);
      final next = repository.purchases.first;

      billing.purchaseUpdates.add([
        _purchase(state: PurchaseStateWrapper.pending),
      ]);

      expect((await next).single.state, PlayPurchaseState.pending);
    });
  });
}
