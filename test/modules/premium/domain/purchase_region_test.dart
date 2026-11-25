import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:flutter_test/flutter_test.dart';

/// A device that says nothing about Iran on any axis: a Berlin clock, an
/// English system locale, no SIM.
DeviceRegionSignals _abroad({
  Duration utcOffset = const Duration(hours: 1),
  String? timeZoneId = 'Europe/Berlin',
  String? localeLanguage = 'en',
  String? localeRegion = 'DE',
  String? simCountry,
  String? networkCountry,
}) => DeviceRegionSignals(
  utcOffset: utcOffset,
  timeZoneId: timeZoneId,
  localeLanguage: localeLanguage,
  localeRegion: localeRegion,
  simCountry: simCountry,
  networkCountry: networkCountry,
);

void main() {
  group('placing the device', () {
    test('a device with no Iranian reading is international', () {
      expect(purchaseRegionFor(_abroad()), PurchaseRegion.international);
      expect(iranSignalIn(_abroad()), isNull);
    });

    test('the Tehran zone id places it, whatever the offset reads', () {
      // A tz database from before 2022 still moves Tehran to +04:30 in
      // summer, which is Kabul's offset too; the id is what settles it.
      final device = _abroad(
        timeZoneId: 'Asia/Tehran',
        utcOffset: const Duration(hours: 4, minutes: 30),
      );

      expect(iranSignalIn(device), IranSignal.timeZone);
      expect(purchaseRegionFor(device), PurchaseRegion.iran);
    });

    test('the legacy Iran alias counts as the Tehran zone', () {
      expect(iranSignalIn(_abroad(timeZoneId: 'Iran')), IranSignal.timeZone);
    });

    test('+03:30 places it without a zone id', () {
      final device = _abroad(
        timeZoneId: null,
        utcOffset: const Duration(hours: 3, minutes: 30),
      );

      expect(iranSignalIn(device), IranSignal.utcOffset);
    });

    test('+04:30 alone does not, because Kabul shares it', () {
      final device = _abroad(
        timeZoneId: null,
        utcOffset: const Duration(hours: 4, minutes: 30),
      );

      expect(purchaseRegionFor(device), PurchaseRegion.international);
    });

    test('an Iranian SIM places it, in any letter case', () {
      expect(iranSignalIn(_abroad(simCountry: 'ir')), IranSignal.simCountry);
      expect(iranSignalIn(_abroad(simCountry: 'IR')), IranSignal.simCountry);
    });

    test('an Iranian network places it', () {
      expect(
        iranSignalIn(_abroad(networkCountry: 'ir')),
        IranSignal.networkCountry,
      );
    });

    test('an address in Iran places it', () {
      expect(iranSignalIn(_abroad(), addressCountry: 'IR'), IranSignal.address);
      expect(
        purchaseRegionFor(_abroad(), addressCountry: 'IR'),
        PurchaseRegion.iran,
      );
    });

    test('a foreign reading does not outvote an Iranian one', () {
      // A Tehran clock behind another VPN, on a foreign SIM.
      final device = _abroad(
        timeZoneId: 'Asia/Tehran',
        utcOffset: const Duration(hours: 3, minutes: 30),
        simCountry: 'de',
      );

      expect(
        purchaseRegionFor(device, addressCountry: 'DE'),
        PurchaseRegion.iran,
      );
    });
  });

  group('language is not location', () {
    test('Persian abroad is international', () {
      final device = _abroad(localeLanguage: 'fa', localeRegion: 'IR');

      expect(purchaseRegionFor(device), PurchaseRegion.international);
    });

    test('Dari in Kabul is international', () {
      final device = _abroad(
        timeZoneId: 'Asia/Kabul',
        utcOffset: const Duration(hours: 4, minutes: 30),
        localeLanguage: 'fa',
        localeRegion: 'AF',
      );

      expect(purchaseRegionFor(device), PurchaseRegion.international);
    });

    test('a region set to Iran under another language places it', () {
      final device = _abroad(localeLanguage: 'en', localeRegion: 'IR');

      expect(iranSignalIn(device), IranSignal.region);
    });
  });

  group('where the buyer is sent', () {
    test('Iran goes to the bot', () {
      for (final ready in [true, false]) {
        expect(
          purchaseDestinationFor(PurchaseRegion.iran, websiteReady: ready),
          PurchaseDestination.telegramBot,
        );
      }
    });

    test('abroad goes to the website once it is ready', () {
      expect(
        purchaseDestinationFor(
          PurchaseRegion.international,
          websiteReady: true,
        ),
        PurchaseDestination.website,
      );
    });

    test('abroad stays on the bot until the website is ready', () {
      expect(
        purchaseDestinationFor(
          PurchaseRegion.international,
          websiteReady: false,
        ),
        PurchaseDestination.telegramBot,
      );
    });
  });
}
