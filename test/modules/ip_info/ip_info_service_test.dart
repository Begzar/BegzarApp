import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/ip_info/application/services/ip_info_service.dart';
import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Records what the service asked of it. No network, no Dio.
class _RecordingRepository extends IpInfoRepository {
  _RecordingRepository(this.answer);

  final Either<IpInfoFailure, IpInfo> answer;

  bool proxyEnabled = false;
  bool proxyDisabled = false;
  bool cacheCleared = false;
  String? host;
  int? port;

  @override
  void enableProxy({required String host, required int port}) {
    proxyEnabled = true;
    this.host = host;
    this.port = port;
  }

  @override
  void disableProxy() => proxyDisabled = true;

  @override
  void clearCache() => cacheCleared = true;

  @override
  Future<Either<IpInfoFailure, IpInfo>> getIpInfo({
    bool forceRefresh = false,
  }) async => answer;
}

void main() {
  const anExit = IpInfo(
    ip: '203.0.113.7',
    country: 'Sweden',
    countryCode: 'SE',
  );
  final found = right<IpInfoFailure, IpInfo>(anExit);
  final nothingAnswered = left<IpInfoFailure, IpInfo>(
    const NoSourceAnsweredFailure(),
  );

  group('while the tunnel is down', () {
    test('reports nothing rather than the last known exit', () async {
      final repository = _RecordingRepository(found);

      final result = await IpInfoService(repository).lookup(tunnelIsUp: false);

      expect(
        result,
        isNull,
        reason:
            'a stale country under a "disconnected" label is worse '
            'than a blank one',
      );
    });

    test('answers null rather than a failure', () async {
      final repository = _RecordingRepository(nothingAnswered);

      final result = await IpInfoService(repository).lookup(tunnelIsUp: false);

      expect(
        result,
        isNull,
        reason:
            'a disconnected app is at rest, not broken — a left here '
            'would put an error on a healthy screen',
      );
    });

    test(
      'clears the cache so a reconnect cannot serve the old answer',
      () async {
        final repository = _RecordingRepository(found);

        await IpInfoService(repository).lookup(tunnelIsUp: false);

        expect(repository.cacheCleared, isTrue);
        expect(repository.proxyDisabled, isTrue);
      },
    );
  });

  group('while the tunnel is up', () {
    test('asks through the local proxy, never directly', () async {
      final repository = _RecordingRepository(found);

      await IpInfoService(repository).lookup(tunnelIsUp: true);

      expect(
        repository.proxyEnabled,
        isTrue,
        reason: 'a direct lookup reports the address the tunnel exists to hide',
      );
      expect(repository.host, kLocalhostListen);
      expect(repository.port, kDefaultProxyPort);
    });

    test('returns what the repository found', () async {
      final repository = _RecordingRepository(found);

      final result = await IpInfoService(repository).lookup(tunnelIsUp: true);

      expect(result, found);
    });

    test('passes a failure through instead of flattening it to null', () async {
      final repository = _RecordingRepository(nothingAnswered);

      final result = await IpInfoService(repository).lookup(tunnelIsUp: true);

      expect(
        result,
        nothingAnswered,
        reason:
            'null already means "not asked"; a failed lookup that '
            'answered null would be indistinguishable from a tunnel still '
            'coming up, which is what left the pill shimmering forever',
      );
    });
  });
}
