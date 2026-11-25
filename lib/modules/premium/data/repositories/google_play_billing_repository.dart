import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/datasources/google_play_billing_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The paywall's door to Google Play: what the server says is for sale,
/// priced by Play, and what Play says was bought.
///
/// It keeps the plugin's own objects for the plans it priced and the
/// purchases still to finish, because buying and acknowledging need them
/// back; nothing above it sees a plugin type.
class GooglePlayBillingRepository {
  GooglePlayBillingRepository({
    required GooglePlayBillingDataSource billing,
    required PremiumRemoteDataSource remote,
  }) : _billing = billing,
       _remote = remote;

  /// The billing client names this response when the item is already owned.
  static const _alreadyOwnedResponse = 'itemAlreadyOwned';

  final GooglePlayBillingDataSource _billing;
  final PremiumRemoteDataSource _remote;
  final Map<PremiumPlan, GooglePlayProductDetails> _pricedPlans = {};
  final Map<String, PurchaseDetails> _unfinished = {};

  /// The base plan's own entry for [plan]: not a trial or promotion offered
  /// beside it, whose first price is not what the subscription costs.
  static GooglePlayProductDetails? _basePlanOf(
    List<GooglePlayProductDetails> products,
    PremiumPlan plan,
  ) {
    for (final product in products) {
      final index = product.subscriptionIndex;
      final offers = product.productDetails.subscriptionOfferDetails;
      if (product.id != plan.productId || index == null || offers == null) {
        continue;
      }
      final offer = offers[index];
      if (offer.basePlanId == plan.basePlanId && offer.offerId == null) {
        return product;
      }
    }
    return null;
  }

  /// The plugin marks everything a restore returns as restored, a payment
  /// still clearing included, so only Play's own state tells that one apart.
  /// Reading it as paid would report a purchase nobody has paid for yet.
  static bool _stillClearing(PurchaseDetails details) =>
      details is GooglePlayPurchaseDetails &&
      details.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.pending;

  static PlayPurchaseState _stateOf(PurchaseDetails details) =>
      switch (details.status) {
        PurchaseStatus.pending => PlayPurchaseState.pending,
        PurchaseStatus.restored when _stillClearing(details) =>
          PlayPurchaseState.pending,
        PurchaseStatus.purchased ||
        PurchaseStatus.restored => PlayPurchaseState.purchased,
        PurchaseStatus.canceled => PlayPurchaseState.canceled,
        PurchaseStatus.error
            when details.error?.message.contains(_alreadyOwnedResponse) ??
                false =>
          PlayPurchaseState.alreadyOwned,
        PurchaseStatus.error => PlayPurchaseState.failed,
      };

  PlayPurchase _playPurchaseFrom(PurchaseDetails details) {
    final token = details.verificationData.serverVerificationData;
    if (details.pendingCompletePurchase && token.isNotEmpty) {
      _unfinished[token] = details;
    }
    final purchase = details is GooglePlayPurchaseDetails
        ? details.billingClientPurchase
        : null;
    return PlayPurchase(
      productId: details.productID,
      purchaseToken: token,
      state: _stateOf(details),
      accountTag: purchase?.obfuscatedAccountId,
      isAcknowledged: purchase?.isAcknowledged ?? false,
    );
  }

  Future<List<PremiumPlanOffer>> _price(List<PremiumPlan> plans) async {
    if (plans.isEmpty || !await _billing.isAvailable()) return const [];

    final products = await _billing.queryProducts({
      for (final plan in plans) plan.productId,
    });
    _pricedPlans.clear();
    final offers = <PremiumPlanOffer>[];
    for (final plan in plans) {
      final product = _basePlanOf(products, plan);
      if (product == null) continue;
      final phase = product
          .productDetails
          .subscriptionOfferDetails![product.subscriptionIndex!]
          .pricingPhases
          .last;
      final months = billingPeriodMonths(phase.billingPeriod);
      if (months == null) continue;
      _pricedPlans[plan] = product;
      offers.add(
        PremiumPlanOffer(
          plan: plan,
          price: phase.formattedPrice,
          months: months,
          priceMicros: phase.priceAmountMicros,
          currencyCode: phase.priceCurrencyCode,
        ),
      );
    }
    return offers;
  }

  /// What is for sale here, priced by Play. Nothing — a right of an empty
  /// list — on a device where Play cannot sell, which is not a failure of
  /// the catalogue.
  Future<Either<ApiFailure, List<PremiumPlanOffer>>> loadOffers() async {
    final catalogue = await _remote.fetchPlans();
    switch (catalogue) {
      case Left(value: final failure):
        return left(failure);
      case Right(value: final plans):
        try {
          return right(await _price(plans));
        } catch (error) {
          return left(
            UnexpectedFailure(
              'Play could not price the plans',
              userFacingKey: UserFacingErrorKeys.plansUnavailable,
              cause: error,
            ),
          );
        }
    }
  }

  /// Opens Play's sheet for [plan], bound to [accountTag]. False for a plan
  /// [loadOffers] did not price, or when the sheet would not open.
  Future<bool> buy(PremiumPlan plan, String accountTag) async {
    final product = _pricedPlans[plan];
    if (product == null) return false;
    return _billing.buy(product, accountTag: accountTag);
  }

  Stream<List<PlayPurchase>> get purchases => _billing.purchases.map(
    (batch) => [for (final details in batch) _playPurchaseFrom(details)],
  );

  /// Acknowledges [purchase], if it is one still to finish.
  Future<void> complete(PlayPurchase purchase) async {
    final details = _unfinished.remove(purchase.purchaseToken);
    if (details != null) await _billing.complete(details);
  }

  Future<void> restore() => _billing.restore();
}
