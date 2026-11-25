import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:flutter_test/flutter_test.dart';

Advertisement _ad(
  String title, {
  String description = 'description',
  Map<String, Advertisement> byLanguage = const {},
}) {
  return Advertisement(
    id: 4,
    title: title,
    description: description,
    bannerUrl: 'https://example.invalid/$title.png',
    clickUrl: 'https://example.invalid/$title',
    position: 'post_connect',
    priority: 1,
    startDate: DateTime(2000),
    endDate: DateTime(2099),
    type: 'banner',
    action: 'view',
    buttonColor: '#FFA500',
    duration: 15,
    byLanguage: byLanguage,
  );
}

void main() {
  group('Advertisement.forRegion', () {
    // A server that sends no translations is one that predates them: the ad
    // it sends is the one everyone saw before, and still sees.
    test('should serve the ad itself everywhere when it has no languages', () {
      final ad = _ad('base');

      expect(ad.forRegion(PurchaseRegion.iran, language: 'en')?.title, 'base');
      expect(
        ad.forRegion(PurchaseRegion.international, language: 'en')?.title,
        'base',
      );
    });

    // Inside Iran the app's language does not matter: the ad is Persian.
    test('should serve the Persian version inside Iran', () {
      final ad = _ad(
        'base',
        byLanguage: {
          Advertisement.persian: _ad('fa'),
          Advertisement.english: _ad('en'),
        },
      );

      expect(ad.forRegion(PurchaseRegion.iran, language: 'en')?.title, 'fa');
    });

    test('should serve the ad itself inside Iran when it has no Persian', () {
      final ad = _ad('base', byLanguage: {Advertisement.english: _ad('en')});

      expect(ad.forRegion(PurchaseRegion.iran, language: 'en')?.title, 'base');
    });

    test('should serve the app language version outside Iran', () {
      final ad = _ad(
        'base',
        byLanguage: {'RU': _ad('ru'), Advertisement.english: _ad('en')},
      );

      expect(
        ad.forRegion(PurchaseRegion.international, language: 'ru')?.title,
        'ru',
      );
    });

    // A Persian speaker abroad reads Persian, wherever they are.
    test('should serve Persian outside Iran when the app is in Persian', () {
      final ad = _ad(
        'base',
        byLanguage: {
          Advertisement.persian: _ad('fa'),
          Advertisement.english: _ad('en'),
        },
      );

      expect(
        ad.forRegion(PurchaseRegion.international, language: 'fa')?.title,
        'fa',
      );
    });

    test('should fall back to English outside Iran when the app language '
        'is missing', () {
      final ad = _ad(
        'base',
        byLanguage: {
          Advertisement.persian: _ad('fa'),
          Advertisement.english: _ad('en'),
        },
      );

      expect(
        ad.forRegion(PurchaseRegion.international, language: 'zh')?.title,
        'en',
      );
    });

    // A translated ad with neither the app's language nor English is one the
    // user cannot read, and nothing is better than that.
    test('should serve nothing outside Iran when the app language and '
        'English are both missing', () {
      final ad = _ad('base', byLanguage: {Advertisement.persian: _ad('fa')});

      expect(
        ad.forRegion(PurchaseRegion.international, language: 'zh'),
        isNull,
      );
    });
  });

  group('Advertisement.readsRightToLeft', () {
    test('should read right to left when the copy is Persian', () {
      final ad = _ad(
        'کانال تلگرام',
        description:
            'برای دریافت آخرین اخبار و تخفیف‌ها عضو کانال رسمی شوید 👇',
      );

      expect(ad.readsRightToLeft, isTrue);
    });

    test('should read left to right when the copy is English', () {
      final ad = _ad(
        'Telegram channel',
        description:
            'Subscribe to the official channel to get the latest '
            'news and discounts 👇',
      );

      expect(ad.readsRightToLeft, isFalse);
    });

    // A brand name or handle inside Persian copy does not turn it around.
    test('should read right to left when Persian copy names a Latin brand', () {
      final ad = _ad(
        'کانال تلگرام Begzar',
        description: 'عضو کانال @BegzarVPN شوید تا آخرین اخبار را ببینید',
      );

      expect(ad.readsRightToLeft, isTrue);
    });

    test('should read left to right when the copy is Russian', () {
      final ad = _ad(
        'Канал в Telegram',
        description: 'Подпишитесь на официальный канал',
      );

      expect(ad.readsRightToLeft, isFalse);
    });
  });
}
