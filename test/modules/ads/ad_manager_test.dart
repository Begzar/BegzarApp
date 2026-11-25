import 'package:begzar/modules/ads/application/services/ad_manager.dart';
import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';

class _FakeAdsRepository extends AdsRepository {
  _FakeAdsRepository({this.cached = const [], this.remote})
    : super(storage: MemoryKeyedStorage());

  List<Advertisement> cached;
  List<Advertisement>? remote;

  /// How often the server was asked. The promotions list doubles as the
  /// backend's record of a successful connect, so who asks and how often is
  /// part of the contract.
  int getAdsCalls = 0;

  @override
  Future<List<Advertisement>> readCachedAds() async => cached;

  @override
  Future<List<Advertisement>?> getAds() async {
    getAdsCalls++;
    return remote;
  }
}

Advertisement _ad({
  required int id,
  String? title,
  int priority = 1,
  DateTime? startDate,
  DateTime? endDate,
  Map<String, Advertisement> byLanguage = const {},
}) {
  return Advertisement(
    id: id,
    title: title ?? 'ad $id',
    description: 'description $id',
    bannerUrl: 'https://example.invalid/$id.png',
    clickUrl: 'https://example.invalid/$id',
    position: 'post_connect',
    priority: priority,
    startDate: startDate ?? DateTime(2000),
    endDate: endDate ?? DateTime(2099),
    type: 'banner',
    action: 'view',
    buttonColor: '#FFA500',
    duration: 15,
    byLanguage: byLanguage,
  );
}

/// A manager whose device sits in [region], Iran unless a test says otherwise,
/// with the app set to [language].
AdManager _manager(
  AdsRepository repository, {
  PurchaseRegion region = PurchaseRegion.iran,
  String language = 'en',
}) =>
    AdManager(repository, region: () async => region, language: () => language);

void main() {
  test('initialize prepares an ad from the cache', () async {
    final manager = _manager(_FakeAdsRepository(cached: [_ad(id: 1)]));

    await manager.initialize();

    expect(manager.preparedAd?.id, 1);
  });

  // The list request is what the backend counts as a successful connect, so a
  // launch must not make one. `ConnectionAdHandler` asks, once the tunnel is
  // up; everything here reads the cache.
  test('initialize asks the server nothing', () async {
    final repository = _FakeAdsRepository(cached: [_ad(id: 1)]);

    await _manager(repository).initialize();

    expect(repository.getAdsCalls, 0);
  });

  test('a server that cannot be reached keeps the cached ad', () async {
    final manager = _manager(_FakeAdsRepository(cached: [_ad(id: 1)]));

    await manager.initialize();
    await manager.refreshLocalAds();

    expect(manager.preparedAd?.id, 1, reason: 'null answer must not wipe it');
  });

  test('a server answer replaces the prepared ad', () async {
    final manager = _manager(
      _FakeAdsRepository(cached: [_ad(id: 1)], remote: [_ad(id: 2)]),
    );

    await manager.initialize();
    await manager.refreshLocalAds();

    expect(manager.preparedAd?.id, 2);
  });

  test('a server with no promotions clears the prepared ad', () async {
    final manager = _manager(
      _FakeAdsRepository(cached: [_ad(id: 1)], remote: []),
    );

    await manager.initialize();
    await manager.refreshLocalAds();

    expect(manager.preparedAd, isNull);
  });

  test('an ad that lapsed since it was prepared is not served', () async {
    final manager = _manager(
      _FakeAdsRepository(cached: [_ad(id: 1, endDate: DateTime(2001))]),
    );

    await manager.initialize();

    expect(manager.preparedAd, isNull);
  });

  group('AdManager.prepareNextAd', () {
    final translated = _ad(
      id: 4,
      title: 'base',
      byLanguage: {
        Advertisement.persian: _ad(id: 4, title: 'fa'),
        Advertisement.english: _ad(id: 4, title: 'en'),
      },
    );

    test('should prepare the Persian version inside Iran', () async {
      final manager = _manager(_FakeAdsRepository(cached: [translated]));

      await manager.initialize();

      expect(manager.preparedAd?.title, 'fa');
    });

    test('should prepare the English version outside Iran', () async {
      final manager = _manager(
        _FakeAdsRepository(cached: [translated]),
        region: PurchaseRegion.international,
      );

      await manager.initialize();

      expect(manager.preparedAd?.title, 'en');
    });

    test('should prepare the app language version outside Iran', () async {
      final manager = _manager(
        _FakeAdsRepository(
          cached: [
            _ad(
              id: 4,
              byLanguage: {
                'RU': _ad(id: 4, title: 'ru'),
                Advertisement.english: _ad(id: 4, title: 'en'),
              },
            ),
          ],
        ),
        region: PurchaseRegion.international,
        language: 'ru',
      );

      await manager.initialize();

      expect(manager.preparedAd?.title, 'ru');
    });

    test(
      'should prepare nothing outside Iran when no ad has English',
      () async {
        final manager = _manager(
          _FakeAdsRepository(
            cached: [
              _ad(
                id: 4,
                byLanguage: {Advertisement.persian: _ad(id: 4, title: 'fa')},
              ),
            ],
          ),
          region: PurchaseRegion.international,
        );

        await manager.initialize();

        expect(manager.preparedAd, isNull);
      },
    );

    // Only the ads this device can show are drawn from, so an untranslated
    // ad of lower priority still runs rather than nothing at all.
    test('should draw from the ads left once untranslated ones drop', () async {
      final manager = _manager(
        _FakeAdsRepository(
          cached: [
            _ad(
              id: 1,
              priority: 9,
              byLanguage: {Advertisement.persian: _ad(id: 1, title: 'fa')},
            ),
            _ad(id: 2, title: 'plain', priority: 1),
          ],
        ),
        region: PurchaseRegion.international,
      );

      await manager.initialize();

      expect(manager.preparedAd?.title, 'plain');
    });
  });
}
