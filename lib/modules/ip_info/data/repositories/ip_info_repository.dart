import 'dart:io';

import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/ip_info/data/dtos/ip_info_dto.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fpdart/fpdart.dart';
import 'package:socks5_proxy/socks.dart';

/// The one door to "where does the internet think we are".
///
/// ident.me and Begzar's own reading are asked together, and ident.me's
/// country is the one shown. Begzar's answer stands in when ident.me and its
/// mirror both fail, and four more public sources after that, because the
/// country badge is worth showing even when the API is down. Every request goes
/// through the local SOCKS port while the tunnel is up — asking directly would
/// report the device's own address, which is the one the tunnel exists to hide.
///
/// Begzar's endpoint is not first for the country because its lookup places
/// some exits where their address block is registered rather than where they
/// are: a Swedish exit read Brazil there while ident.me, ipwho.is, geojs.io and
/// Cloudflare all said Sweden. It is still asked on every lookup, since its
/// answer also carries the release the connect path enforces
/// ([ReleaseHintBus]).
///
/// The public sources must not all share one front. geojs.io, ipwho.is,
/// freeipapi.com and ipapi.co are all behind Cloudflare, and some exits cannot
/// reach anything Cloudflare serves: through those, all four fail together
/// while the tunnel carries everything else, and the badge read "Location
/// unavailable" on a working connection. ident.me and its mirror tnedi.me are
/// served from their own hosts, and are asked before the Cloudflare four so
/// such an exit is answered without first sitting through four refusals.
///
/// Every source is asked over HTTPS, and a provider that cannot offer it does
/// not belong in the list. The badge is the one thing this screen exists to
/// tell the user, so a source anyone on the path can rewrite is worth less than
/// the next source down. That is what removed ip-api.com, whose free tier
/// answers `SSL unavailable for this endpoint` and served the badge over
/// cleartext — first in the chain, so the most likely to be believed.
///
/// Holds a Dio client and a five-minute cache, so it is meant to be long-lived.
/// `ipInfoRepositoryProvider` owns that lifetime; this was a singleton before
/// the provider existed, which also made it impossible to substitute in a test.
class IpInfoRepository {
  /// [dio] is for tests, which have no SOCKS port to reach and no business
  /// making five real requests. Production passes nothing and gets the
  /// proxy-aware client below, built lazily so constructing the repository
  /// costs no sockets.
  ///
  /// Begzar's own reading is the engine's to fetch, which owns its host and
  /// its pin; [backend] stands in for the engine in tests.
  IpInfoRepository({Dio? dio, BegzarBackend? backend})
    : _injectedDio = dio,
      _backendOverride = backend;

  final Dio? _injectedDio;
  final BegzarBackend? _backendOverride;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  /// The tunnel's SOCKS5 proxy, `host:port`, that Begzar's reading is asked
  /// through, or empty to ask it directly. It follows [enableProxy] and
  /// [disableProxy], as the client for every other provider does.
  String _viaSocks5 = '$kLocalhostListen:$kDefaultProxyPort';

  static const Duration _requestTimeout = Duration(seconds: 10);

  /// How long an answer is served before the exit is asked again.
  static const Duration _cacheDuration = Duration(minutes: 5);

  late final Dio _dio = _injectedDio ?? _createDioWithProxy();

  IpInfo? _cachedIpInfo;
  DateTime? _cacheTime;

  Dio _createDioWithProxy() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
      ),
    );

    _configureSocks5Proxy(dio, kLocalhostListen, kDefaultProxyPort);

    return dio;
  }

  void _configureSocks5Proxy(Dio dio, String host, int port) {
    dio.httpClientAdapter = _adapterThrough(() {
      final client = HttpClient();

      SocksTCPClient.assignToHttpClient(client, [
        ProxySettings(InternetAddress(host), port),
      ]);

      return client;
    });
  }

  /// The certificate policy both routes share: the platform trust store and
  /// hostname verification decide the handshake. None of the public providers
  /// has a pin; Begzar's own endpoint, which does, is asked through the engine.
  ///
  /// Neither route sets `badCertificateCallback`, and neither needs to. Both
  /// used to set it to accept any certificate from any host. On the direct
  /// route that was the only thing standing between the country badge and
  /// anyone able to intercept the request — the badge is the one thing that
  /// screen exists to tell the user, so a spoofed one is worse than none. On
  /// the SOCKS route the callback was never consulted at all:
  /// [SocksTCPClient.assignToHttpClient] installs a `connectionFactory` that
  /// returns a socket it has already secured itself, and [HttpClient] neither
  /// re-runs its own TLS over such a socket nor asks the callback about it. The
  /// tunnel has always validated; the line only read as though it did not.
  IOHttpClientAdapter _adapterThrough(HttpClient Function() createHttpClient) {
    return IOHttpClientAdapter(createHttpClient: createHttpClient);
  }

  /// The current exit, the last one seen if the lookup fails, or a
  /// [NoSourceAnsweredFailure] when neither exists.
  ///
  /// A stale reading still wins over a left: an expired country beats a blank
  /// badge, and the exit rarely changes while the same tunnel is up.
  Future<Either<IpInfoFailure, IpInfo>> getIpInfo({
    bool forceRefresh = false,
  }) async {
    final cached = _cachedIpInfo;
    final cachedAt = _cacheTime;

    if (!forceRefresh && cached != null && cachedAt != null) {
      if (DateTime.now().difference(cachedAt) < _cacheDuration) {
        return right(cached);
      }
    }

    final ipInfo = await _askEverySource();
    if (ipInfo != null) {
      _cachedIpInfo = ipInfo;
      _cacheTime = DateTime.now();
      return right(ipInfo);
    }

    if (cached != null) {
      return right(cached);
    }

    return left(const NoSourceAnsweredFailure());
  }

  /// Returns the reading to show, or `null` when every source refused.
  ///
  /// Begzar's endpoint and ident.me are asked at the same time and both are
  /// awaited before choosing, ident.me's reading first. Waiting for Begzar
  /// even when ident.me has answered is what keeps its version reaching
  /// [ReleaseHintBus], and it costs nothing against the old order, which
  /// waited for Begzar before asking anyone else.
  ///
  /// Every provider is tried inside its own `catch`: one being unreachable,
  /// rate limited, or serving something unparseable must not stop the next
  /// from being asked. That also means no reason survives the loop, which is
  /// why the caller has only one failure to report.
  Future<IpInfo?> _askEverySource() async {
    final fromBegzar = _askBegzar();
    final fromIdentMe = await _askIdentMe();
    final begzarReading = await fromBegzar;
    return fromIdentMe ?? begzarReading ?? await _askCloudflareFronted();
  }

  /// Begzar's own reading, through the tunnel while one is up, publishing
  /// the release it names on the way. A refusal, a pin failure included,
  /// costs this reading and not the badge.
  Future<IpInfo?> _askBegzar() async {
    try {
      final answer = await _backend.lookupExit(viaSocks5: _viaSocks5);
      ReleaseHintBus.publish(answer.releaseHint);
      return IpInfoDto.fromBegzar(answer.value);
    } on BackendException catch (e) {
      ReleaseHintBus.publish(e.releaseHint);
    } catch (_) {
      // Fall through to fallback providers.
    }
    return null;
  }

  /// ident.me, then its mirror tnedi.me on a separate host (free for any use,
  /// no key, IPv4/IPv6). The only public sources here not behind Cloudflare.
  ///
  /// An answer without a country code is no reading: this is the source whose
  /// country is believed over Begzar's, so it does not get to fill the badge
  /// with a default.
  Future<IpInfo?> _askIdentMe() async {
    for (final host in const ['ident.me', 'tnedi.me']) {
      try {
        final response = await _dio.get('https://$host/json');
        final data = response.data;
        if (response.statusCode == 200 && data is Map && data['cc'] is String) {
          return IpInfo(
            ip: data['ip'] ?? 'Unknown',
            country: data['country'] ?? 'Unknown',
            countryCode: data['cc'] as String,
          );
        }
      } catch (_) {
        // Try the next provider.
      }
    }
    return null;
  }

  /// The four public sources served from behind Cloudflare, in turn.
  Future<IpInfo?> _askCloudflareFronted() async {
    // geojs.io (free, unlimited, complete data, IPv4/IPv6)
    try {
      final response = await _dio.get('https://get.geojs.io/v1/ip/geo.json');
      if (response.statusCode == 200) {
        return IpInfo(
          ip: response.data['ip'] ?? 'Unknown',
          country: response.data['country'] ?? 'Unknown',
          countryCode: response.data['country_code'] ?? 'US',
        );
      }
    } catch (_) {
      // Try the next provider.
    }

    // ipwhois.app (free, 10k req/month, complete data, IPv4/IPv6)
    try {
      final response = await _dio.get('https://ipwho.is/');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return IpInfo(
          ip: response.data['ip'] ?? 'Unknown',
          country: response.data['country'] ?? 'Unknown',
          countryCode: response.data['country_code'] ?? 'US',
        );
      }
    } catch (_) {
      // Try the next provider.
    }

    // freeipapi.com (free, complete data, IPv4/IPv6)
    try {
      final response = await _dio.get('https://freeipapi.com/api/json');
      if (response.statusCode == 200) {
        return IpInfo(
          ip: response.data['ipAddress'] ?? 'Unknown',
          country: response.data['countryName'] ?? 'Unknown',
          countryCode: response.data['countryCode'] ?? 'US',
        );
      }
    } catch (_) {
      // Try the next provider.
    }

    // ipapi.co, last resort: rate limited but reliable.
    try {
      final response = await _dio.get('https://ipapi.co/json/');
      if (response.statusCode == 200) {
        return IpInfoDto.fromJson(response.data);
      }
    } catch (_) {
      // Nothing left to try.
    }

    return null;
  }

  /// Route lookups through the tunnel. Called when a connection comes up.
  void enableProxy({required String host, required int port}) {
    _configureSocks5Proxy(_dio, host, port);
    _viaSocks5 = '$host:$port';
  }

  /// Go direct again. Called on disconnect, where there is no tunnel to use.
  void disableProxy() {
    _dio.httpClientAdapter = _adapterThrough(HttpClient.new);
    _viaSocks5 = '';
  }

  void clearCache() {
    _cachedIpInfo = null;
    _cacheTime = null;
  }
}
