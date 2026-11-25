import 'dart:convert';

import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';

Map<String, dynamic> _adJson({
  required int id,
  required int priority,
  String startDate = '2000-01-01',
  String endDate = '2099-01-01',
}) {
  return {
    'id': id,
    'title': 'ad $id',
    'description': 'description $id',
    'banner_url': 'https://example.invalid/$id.png',
    'click_url': 'https://example.invalid/$id',
    'position': 'post_connect',
    'priority': priority,
    'start_date': startDate,
    'end_date': endDate,
    'type': 'banner',
    'duration': 15,
  };
}

void _seed(
  MemoryKeyedStorage store,
  List<Map<String, dynamic>> ads, {
  required DateTime expiry,
}) {
  store.values[AdsRepository.cacheKeyAds] = jsonEncode(ads);
  store.values[AdsRepository.cacheKeyExpiry] = expiry.toIso8601String();
}

void main() {
  test(
    'readCachedAds returns the stored list highest priority first',
    () async {
      final store = MemoryKeyedStorage();
      _seed(store, [
        _adJson(id: 1, priority: 5),
        _adJson(id: 2, priority: 9),
      ], expiry: DateTime.now().add(const Duration(hours: 1)));

      final ads = await AdsRepository(storage: store).readCachedAds();

      expect(ads.map((ad) => ad.id), [2, 1]);
    },
  );

  test('readCachedAds drops an ad whose end date has passed', () async {
    final store = MemoryKeyedStorage();
    _seed(store, [
      _adJson(id: 1, priority: 5, endDate: '2001-01-01'),
      _adJson(id: 2, priority: 1),
    ], expiry: DateTime.now().add(const Duration(hours: 1)));

    final ads = await AdsRepository(storage: store).readCachedAds();

    expect(ads.map((ad) => ad.id), [2]);
  });

  test('readCachedAds returns nothing once the stamp has lapsed', () async {
    final store = MemoryKeyedStorage();
    _seed(store, [
      _adJson(id: 1, priority: 5),
    ], expiry: DateTime.now().subtract(const Duration(minutes: 1)));

    final ads = await AdsRepository(storage: store).readCachedAds();

    expect(ads, isEmpty);
  });

  test('readCachedAds returns nothing when no stamp was written', () async {
    final store = MemoryKeyedStorage();
    store.values[AdsRepository.cacheKeyAds] = jsonEncode([
      _adJson(id: 1, priority: 5),
    ]);

    final ads = await AdsRepository(storage: store).readCachedAds();

    expect(ads, isEmpty);
  });

  test('readCachedAds returns nothing when the entry is unreadable', () async {
    final store = MemoryKeyedStorage();
    store.values[AdsRepository.cacheKeyAds] = 'not json';
    store.values[AdsRepository.cacheKeyExpiry] = DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String();

    final ads = await AdsRepository(storage: store).readCachedAds();

    expect(ads, isEmpty);
  });

  test('clearCache removes both entries', () async {
    final store = MemoryKeyedStorage();
    _seed(store, [
      _adJson(id: 1, priority: 5),
    ], expiry: DateTime.now().add(const Duration(hours: 1)));

    await AdsRepository(storage: store).clearCache();

    expect(store.values, isEmpty);
  });
}
