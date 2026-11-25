import 'dart:async';

import 'package:begzar/modules/premium/data/datasources/google_play_billing_data_source.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'fake_premium_backend.dart';

/// Google Play as it would answer, without a Play Store or a Play Console
/// listing, for running a Play build against [FakePremiumBackend].
///
/// It sells every plan the fake backend lists, in US dollars, and answers by
/// device count so each state the paywall shows can be reached on a device:
///
/// - [pendingDevices]: pending, then paid once [_clearingDelay] has passed;
/// - [ownedDevices] for a year: already owned by this Google account;
/// - anything else: paid.
///
/// A paid purchase stays with it until the app acknowledges it, and a restore
/// hands it back, the way Play does.
class FakeGooglePlayBilling extends GooglePlayBillingDataSource {
  static const pendingDevices = 4;
  static const ownedDevices = 5;
  static const _ownedMonths = 12;

  /// How long the pretend sheet stays up before answering.
  static const _sheetDelay = Duration(milliseconds: 600);

  /// How long a pending payment takes to clear.
  static const _clearingDelay = Duration(seconds: 5);

  /// One device for a month; longer periods cost a little less per month.
  static const _dollarsPerDeviceMonth = 2.0;
  static const _priceFactorByMonths = {1: 1.0, 3: 0.95, 6: 0.9, 12: 0.8};
  static const _isoPeriodByMonths = {1: 'P1M', 3: 'P3M', 6: 'P6M', 12: 'P1Y'};
  static const _microsPerDollar = 1000000;
  static const _packageName = 'cloud.begzar.begzar';
  static const _source = 'google_play';

  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// Paid and not yet acknowledged, by purchase token.
  final Map<String, PurchaseWrapper> _held = {};
  int _serial = 0;

  static SubscriptionOfferDetailsWrapper _basePlan(FakePlan plan) {
    final dollars =
        plan.devices *
        plan.months *
        _dollarsPerDeviceMonth *
        _priceFactorByMonths[plan.months]!;
    return SubscriptionOfferDetailsWrapper(
      basePlanId: plan.basePlanId,
      offerTags: const [],
      offerIdToken: '${plan.basePlanId}-token',
      pricingPhases: [
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: _isoPeriodByMonths[plan.months]!,
          formattedPrice: '\$${dollars.toStringAsFixed(2)}',
          priceAmountMicros: (dollars * _microsPerDollar).round(),
          priceCurrencyCode: 'USD',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    );
  }

  static List<GooglePlayProductDetails> _product(String productId) =>
      GooglePlayProductDetails.fromProductDetails(
        ProductDetailsWrapper(
          description: '',
          name: 'Premium',
          productId: productId,
          productType: ProductType.subs,
          subscriptionOfferDetails: [
            for (final plan in FakePremiumBackend.plans)
              if (plan.productId == productId) _basePlan(plan),
          ],
          title: 'Premium',
        ),
      );

  PurchaseWrapper _purchaseOf({
    required String productId,
    required String token,
    required String accountTag,
    required PurchaseStateWrapper state,
  }) => PurchaseWrapper(
    orderId: 'fake-order-$_serial',
    packageName: _packageName,
    purchaseTime: DateTime.now().millisecondsSinceEpoch,
    purchaseToken: token,
    signature: '',
    products: [productId],
    isAutoRenewing: true,
    originalJson: '{}',
    isAcknowledged: false,
    purchaseState: state,
    obfuscatedAccountId: accountTag,
  );

  void _emit(PurchaseWrapper purchase, {PurchaseStatus? status}) {
    final details = GooglePlayPurchaseDetails.fromPurchase(purchase);
    if (status != null) {
      for (final detail in details) {
        detail.status = status;
      }
    }
    _purchases.add(details);
  }

  /// Play reports an owned product as a failed purchase, naming the reason
  /// only in the error's message.
  void _emitAlreadyOwned(String productId) {
    _purchases.add([
      PurchaseDetails(
          productID: productId,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: _source,
          ),
          transactionDate: null,
          status: PurchaseStatus.error,
        )
        ..error = IAPError(
          source: _source,
          code: 'purchase_error',
          message: 'BillingResponse.itemAlreadyOwned',
        ),
    ]);
  }

  Future<void> _answer({
    required FakePlan plan,
    required String token,
    required String accountTag,
  }) async {
    await Future<void>.delayed(_sheetDelay);
    if (plan.devices == ownedDevices && plan.months == _ownedMonths) {
      _emitAlreadyOwned(plan.productId);
      return;
    }

    PurchaseWrapper purchaseIn(PurchaseStateWrapper state) => _purchaseOf(
      productId: plan.productId,
      token: token,
      accountTag: accountTag,
      state: state,
    );
    if (plan.devices == pendingDevices) {
      _emit(purchaseIn(PurchaseStateWrapper.pending));
      await Future<void>.delayed(_clearingDelay);
    }
    final paid = purchaseIn(PurchaseStateWrapper.purchased);
    _held[token] = paid;
    _emit(paid);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<GooglePlayProductDetails>> queryProducts(Set<String> ids) async =>
      [
        for (final productId in {
          for (final plan in FakePremiumBackend.plans) plan.productId,
        })
          if (ids.contains(productId)) ..._product(productId),
      ];

  @override
  Future<bool> buy(
    GooglePlayProductDetails product, {
    required String accountTag,
  }) async {
    final offer = product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!];
    final plan = FakePremiumBackend.plans.firstWhere(
      (plan) =>
          plan.productId == product.id && plan.basePlanId == offer.basePlanId,
    );
    _serial++;
    unawaited(
      _answer(
        plan: plan,
        token: FakePremiumBackend.purchaseTokenFor(plan.basePlanId, _serial),
        accountTag: accountTag,
      ),
    );
    return true;
  }

  @override
  Stream<List<PurchaseDetails>> get purchases => _purchases.stream;

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    _held.remove(purchase.verificationData.serverVerificationData);
  }

  @override
  Future<void> restore() async {
    for (final purchase in _held.values) {
      _emit(purchase, status: PurchaseStatus.restored);
    }
  }
}
