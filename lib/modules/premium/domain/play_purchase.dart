/// Where a Play purchase stands, as the billing client last reported it.
enum PlayPurchaseState {
  /// Paid for with a method that clears later, such as cash at a shop. Play
  /// reports it again once it has cleared, or not at all if it never does.
  pending,

  /// Paid for, whether just now or found again on a later launch.
  purchased,

  /// The buyer closed Play's sheet.
  canceled,

  /// This Google account already pays for the product, usually bought for
  /// another Begzar account.
  alreadyOwned,

  failed,
}

/// What came of a purchase, for the paywall to tell the buyer.
enum PlayPurchaseOutcome {
  /// Paid with a method that clears later; premium starts when it does.
  pending,

  /// The server granted it and Play has been told.
  granted,

  /// Paid for, but the server could not be reached to grant it. Left
  /// unfinished, so the next launch reports it again.
  confirmLater,

  canceled,
  alreadyOwned,
  failed,
}

/// A purchase Play reported, in the app's own terms.
class PlayPurchase {
  const PlayPurchase({
    required this.productId,
    required this.purchaseToken,
    required this.state,
    required this.accountTag,
    required this.isAcknowledged,
  });

  final String productId;

  /// What the server checks with Google. Empty for a report that carried no
  /// purchase, such as a cancelled sheet.
  final String purchaseToken;

  final PlayPurchaseState state;

  /// The account tag the purchase was made with, or null when Play did not
  /// say.
  final String? accountTag;

  /// True once the purchase has been acknowledged, after which there is
  /// nothing left to report for it.
  final bool isAcknowledged;
}
