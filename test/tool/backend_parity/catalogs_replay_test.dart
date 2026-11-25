import 'dart:typed_data';

import 'package:begzar/modules/ads/data/dtos/advertisement_dto.dart';
import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:begzar/modules/app_update/data/repositories/app_version_repository.dart';
import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:begzar/modules/premium/data/repositories/purchase_region_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';
import 'backend_replay.dart';

/// Every provider but the engine refuses, so the badge reading is Begzar's.
class _Unreachable implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'unreachable in this test',
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  final replay = BackendReplay.load('catalogs');

  test('promotions, the release catalog and the address reach every outcome '
      'they reached before the engine took their calls over', () async {
    for (final c in replay!.cases) {
      switch (c['op']) {
        case 'fetchPromotions':
          await replay.checkOutcome(
            c,
            call: (backend) async => {
              'ok': (await AdsRepository(
                backend: backend,
              ).getAds())?.map(AdvertisementDto.toJson).toList(),
            },
          );
        case 'appVersionCatalog':
          await replay.checkOutcome(
            c,
            call: (backend) async {
              try {
                final catalog = await AppVersionRepository(
                  backend: backend,
                ).fetch();
                return {
                  'ok': catalog?.platforms.map(
                    (platform, sources) => MapEntry(platform, {
                      for (final MapEntry(:key, :value) in sources.entries)
                        key: {
                          'version': value.version,
                          'latestVersion': value.latestVersion,
                          'url': value.url,
                        },
                    }),
                  ),
                };
              } catch (e) {
                return {'threw': 'DioException'};
              }
            },
          );
        case 'lookupRegionCountry':
          await replay.check(
            c,
            call: (backend) => PurchaseRegionRepository(
              storage: MemoryKeyedStorage(),
              backend: backend,
            ).addressCountry(),
            describe: (country) => {'country': country},
          );
        case 'lookupExit':
          await replay.checkOutcome(
            c,
            call: (backend) async {
              final unreachable = Dio()..httpClientAdapter = _Unreachable();
              final repository = IpInfoRepository(
                dio: unreachable,
                backend: backend,
              );
              final via =
                  ((c['sent']! as List).firstOrNull as Map?)?['viaSocks5'];
              if (via == '') {
                repository.disableProxy();
                unreachable.httpClientAdapter = _Unreachable();
              }
              final result = await repository.getIpInfo();
              return result.match(
                (failure) => {
                  'failure': {'type': failure.runtimeType.toString()},
                },
                (info) => {
                  'ok': {
                    'ip': info.ip,
                    'country': info.country,
                    'countryCode': info.countryCode,
                  },
                },
              );
            },
          );
        default:
          fail('no call replays ${c['op']}');
      }
    }
  }, skip: replay == null ? 'the private engine is not checked out' : false);
}
