import 'package:begzar/modules/main/domain/news_channel.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The channel follows where the device is, by the same reading that decides
  // where premium is sold, so a user abroad is not sent to a Persian feed of
  // news about Iran's filtering.
  group('NewsChannel.forRegion', () {
    test('should open the Persian channel for a device in Iran', () {
      expect(
        NewsChannel.forRegion(PurchaseRegion.iran).url,
        'https://t.me/BegzarVPN',
      );
    });

    test('should open the English channel for a device anywhere else', () {
      expect(
        NewsChannel.forRegion(PurchaseRegion.international).url,
        'https://t.me/BegzarEnglish',
      );
    });
  });
}
