import 'package:begzar/modules/premium/domain/purchase_region.dart';

/// The Telegram channel the home bar's support button opens.
///
/// Placed by where the device is rather than the language it reads, by the
/// same reading that decides where premium is sold: the Persian channel is
/// written for users inside Iran, and a user anywhere else is better served by
/// the English one.
enum NewsChannel {
  persian('https://t.me/BegzarVPN'),
  english('https://t.me/BegzarEnglish');

  const NewsChannel(this.url);

  final String url;

  static NewsChannel forRegion(PurchaseRegion region) => switch (region) {
    PurchaseRegion.iran => persian,
    PurchaseRegion.international => english,
  };
}
