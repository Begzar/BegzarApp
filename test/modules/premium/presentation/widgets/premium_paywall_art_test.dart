import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_art.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paywallDeviceKinds', () {
    test('should draw one phone for one device', () {
      expect(paywallDeviceKinds(1), [PaywallDevice.phone]);
    });

    test('should add a laptop, then a tablet, as the count grows', () {
      expect(paywallDeviceKinds(2), [
        PaywallDevice.laptop,
        PaywallDevice.phone,
      ]);
      expect(paywallDeviceKinds(3), [
        PaywallDevice.laptop,
        PaywallDevice.tablet,
        PaywallDevice.phone,
      ]);
    });

    test('should draw as many devices as the count, up to five', () {
      for (var count = 1; count <= 5; count++) {
        expect(paywallDeviceKinds(count), hasLength(count));
      }
    });

    test('should draw five for a count past five', () {
      expect(paywallDeviceKinds(8), paywallDeviceKinds(5));
    });
  });
}
