import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Google Play Billing, through the `in_app_purchase` plugin.
///
/// A thin door and nothing more: what a plan is and what to do with a
/// purchase are decided above it. Only Play builds construct one, and the
/// plugin is not touched until a method is called, so other builds never
/// reach a billing client they do not have.
class GooglePlayBillingDataSource {
  GooglePlayBillingDataSource({InAppPurchase? store}) : _store = store;

  final InAppPurchase? _store;

  InAppPurchase get _plugin => _store ?? InAppPurchase.instance;

  /// False on a device without the Play Store, or signed out of it.
  Future<bool> isAvailable() => _plugin.isAvailable();

  /// One entry per base plan and per offer of every product asked for.
  Future<List<GooglePlayProductDetails>> queryProducts(Set<String> ids) async {
    final response = await _plugin.queryProductDetails(ids);
    return response.productDetails
        .whereType<GooglePlayProductDetails>()
        .toList();
  }

  /// Opens Play's purchase sheet for [product], bound to [accountTag]. True
  /// when the sheet opened; what the buyer did arrives on [purchases].
  Future<bool> buy(
    GooglePlayProductDetails product, {
    required String accountTag,
  }) => _plugin.buyNonConsumable(
    purchaseParam: GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: accountTag,
    ),
  );

  Stream<List<PurchaseDetails>> get purchases => _plugin.purchaseStream;

  /// Acknowledges [purchase]. Play refunds one left unacknowledged for three
  /// days.
  Future<void> complete(PurchaseDetails purchase) =>
      _plugin.completePurchase(purchase);

  /// Asks Play to report every purchase it still holds, on [purchases].
  Future<void> restore() => _plugin.restorePurchases();
}
