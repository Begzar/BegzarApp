import 'package:begzar/modules/ads/data/dtos/advertisement_dto.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _adJson(String title) {
  return {
    'id': 4,
    'title': title,
    'description': 'description',
    'banner_url': 'https://example.invalid/$title.png',
    'click_url': 'https://example.invalid/$title',
    'position': 'post_connect',
    'priority': 1,
    'start_date': '2000-01-01',
    'end_date': '2099-01-01',
    'type': 'banner',
    'duration': 15,
  };
}

void main() {
  group('AdvertisementDto.fromJson', () {
    test('should read each language version from by_lang', () {
      final ad = AdvertisementDto.fromJson({
        ..._adJson('base'),
        'by_lang': {'FA': _adJson('fa'), 'EN': _adJson('en')},
      });

      expect(ad.byLanguage[Advertisement.persian]?.title, 'fa');
      expect(ad.byLanguage[Advertisement.english]?.title, 'en');
    });

    test('should read no languages when by_lang is absent', () {
      final ad = AdvertisementDto.fromJson(_adJson('base'));

      expect(ad.byLanguage, isEmpty);
    });

    // One broken translation must not cost the user the whole list.
    test('should skip a language version that is not an object', () {
      final ad = AdvertisementDto.fromJson({
        ..._adJson('base'),
        'by_lang': {'FA': 'nope', 'EN': _adJson('en')},
      });

      expect(ad.byLanguage.keys, [Advertisement.english]);
    });
  });

  group('AdvertisementDto.toJson', () {
    // The cache is read on the next launch to pick the ad before a connect, so
    // it must keep every version, not just the one this device would show.
    test('should keep each language version through the cache', () {
      final ad = AdvertisementDto.fromJson({
        ..._adJson('base'),
        'by_lang': {'FA': _adJson('fa'), 'EN': _adJson('en')},
      });

      final cached = AdvertisementDto.fromJson(AdvertisementDto.toJson(ad));

      expect(cached.byLanguage[Advertisement.persian]?.title, 'fa');
      expect(cached.byLanguage[Advertisement.english]?.title, 'en');
    });
  });
}
