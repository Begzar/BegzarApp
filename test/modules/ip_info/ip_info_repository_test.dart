import 'dart:convert';
import 'dart:typed_data';

import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

/// Answers every request the repository makes without touching a socket.
///
/// The repository asks up to seven sources, so a test that wants "no
/// source answered" has to refuse all seven — [answer] returning null is how it
/// says so, and [requests] records which were actually tried.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.answer);

  /// Returns the JSON body for a URL, or null to fail that request.
  final String? Function(String url) answer;

  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requests.add(url);

    final body = answer(url);
    if (body == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'scripted refusal',
      );
    }

    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

IpInfoRepository _repositoryThat(_ScriptedAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return IpInfoRepository(dio: dio, backend: _BegzarSource(adapter));
}

/// Where this test pretends Begzar's reading comes from, so [_ScriptedAdapter]
/// can script it alongside the public providers. The engine fetches the real
/// one; nothing here names it.
const String _begzarGeoPath = 'begzar.invalid/exit';

/// Begzar's reading as the engine would hand it over, read from whatever the
/// adapter answers for [_begzarGeoPath]: the backend's nested shapes and the
/// flat one, and the release a top-level `version` names.
class _BegzarSource implements BegzarBackend {
  _BegzarSource(this.adapter);

  final _ScriptedAdapter adapter;

  @override
  Future<BackendAnswer<BackendExitReading>> lookupExit({
    String viaSocks5 = '',
  }) async {
    const url = 'https://$_begzarGeoPath';
    adapter.requests.add(url);
    final body = adapter.answer(url);
    if (body == null) {
      throw const BackendException(BackendFailureKind.network);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final nested = (json['network'] ?? json['data']) as Map<String, dynamic>?;
    final reading = nested == null
        ? BackendExitReading(
            ip: json['ip'] ?? json['query'],
            country: json['country'] ?? json['country_name'],
            countryCode: json['countryCode'] ?? json['country_code'],
          )
        : BackendExitReading(
            ip: nested['ip'],
            country: nested['country'],
            countryCode: nested['country_code'],
          );
    final version = json['version'] as String?;
    return BackendAnswer(
      reading,
      releaseHint: version == null
          ? null
          : BackendReleaseHint(version: version),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const BackendException(BackendFailureKind.network);
}

/// The public providers served from behind Cloudflare. Some exits cannot reach
/// anything Cloudflare serves, and through those every one of these fails at
/// once.
const Set<String> _cloudflareFronted = {
  'get.geojs.io',
  'ipwho.is',
  'freeipapi.com',
  'ipapi.co',
};

bool _isCloudflareFronted(String url) =>
    _cloudflareFronted.contains(Uri.parse(url).host);

/// An exit that cannot reach Cloudflare: Begzar's own endpoint and every
/// Cloudflare-fronted provider refuse, and whatever else is asked answers
/// with [body].
String? Function(String url) _exitWithoutCloudflare(String body) {
  return (url) {
    if (url.contains(_begzarGeoPath) || _isCloudflareFronted(url)) return null;
    return body;
  };
}

/// ident.me's shape, which names the country code `cc`.
const String _identMeSwedishExit =
    '{"ip":"203.0.113.7","cc":"SE",'
    '"country":"Sweden","continent":"EU","type":"hosting"}';

/// Begzar's v4 shape for the same exit, placed where its address block is
/// registered rather than where it is, as the live endpoint did for a Swedish
/// server. The top-level `version` is the legacy field the version bus reads.
const String _begzarBrazilianReading =
    '{"version":"9.9.9","network":'
    '{"ip":"203.0.113.7","country":"Brazil","country_code":"BR"}}';

/// geojs.io's shape, for telling a Cloudflare-fronted answer apart.
const String _geojsNorwegianExit =
    '{"ip":"203.0.113.7","country":"Norway",'
    '"country_code":"NO"}';

bool _isIdentMe(String url) =>
    const {'ident.me', 'tnedi.me'}.contains(Uri.parse(url).host);

void main() {
  // The Begzar source publishes into `ReleaseHintBus.latest` on its way
  // past — a process-wide static the connect path reads as the version to
  // enforce. Nothing answered here carries a version, so nothing lands there
  // today; a fixture that grew one would otherwise leave it set for every later
  // test in this isolate.
  setUp(() {
    ReleaseHintBus.latest = null;
  });

  const swedishExit =
      '{"query":"203.0.113.7","country":"Sweden",'
      '"countryCode":"SE"}';

  // Begzar and ident.me are asked together, and the Cloudflare-fronted four
  // only when both have nothing. [swedishExit] has no `cc`, so ident.me's
  // answer to it is no reading and an adapter that answers everything with it
  // is answered by Begzar. Getting to the last four takes refusing every
  // source, which is what the two tests that count requests do.
  test('an answered lookup comes back on the right', () async {
    final adapter = _ScriptedAdapter((_) => swedishExit);

    final result = await _repositoryThat(adapter).getIpInfo();

    expect(result.isRight(), isTrue);
    expect(
      result.getOrElse((_) => throw StateError('unreachable')).country,
      'Sweden',
    );
    expect(
      adapter.requests.where(_isCloudflareFronted),
      isEmpty,
      reason: 'Begzar answered, so the sources below it are never reached',
    );
  });

  test("takes the country from ident.me over Begzar's", () async {
    final adapter = _ScriptedAdapter((url) {
      if (url.contains(_begzarGeoPath)) return _begzarBrazilianReading;
      if (_isIdentMe(url)) return _identMeSwedishExit;
      return null;
    });

    final reading = (await _repositoryThat(
      adapter,
    ).getIpInfo()).getOrElse((_) => throw StateError('unreachable'));

    expect(
      reading.countryCode,
      'SE',
      reason:
          "Begzar's lookup placed a Swedish exit in Brazil, where its "
          'address block is registered, while every public source said Sweden',
    );
    expect(reading.country, 'Sweden');
  });

  test("still hands Begzar's release to the version bus", () async {
    final adapter = _ScriptedAdapter((url) {
      if (url.contains(_begzarGeoPath)) return _begzarBrazilianReading;
      if (_isIdentMe(url)) return _identMeSwedishExit;
      return null;
    });

    await _repositoryThat(adapter).getIpInfo();

    expect(
      ReleaseHintBus.latest?.version,
      '9.9.9',
      reason:
          'the connect path enforces the release this endpoint names, so '
          "it is asked even when ident.me's reading is the one shown",
    );
  });

  test(
    "falls back to Begzar's reading before the Cloudflare-fronted sources",
    () async {
      final adapter = _ScriptedAdapter((url) {
        if (url.contains(_begzarGeoPath)) return _begzarBrazilianReading;
        if (_isCloudflareFronted(url)) return _geojsNorwegianExit;
        return null;
      });

      final reading = (await _repositoryThat(
        adapter,
      ).getIpInfo()).getOrElse((_) => throw StateError('unreachable'));

      expect(
        reading.countryCode,
        'BR',
        reason:
            'with ident.me and its mirror both down, Begzar is the next '
            'source down, as it was before ident.me went first',
      );
      expect(adapter.requests.where(_isCloudflareFronted), isEmpty);
    },
  );

  test('every source refusing is a failure, not an empty answer', () async {
    final adapter = _ScriptedAdapter((_) => null);

    final result = await _repositoryThat(adapter).getIpInfo();

    expect(
      result,
      left<IpInfoFailure, IpInfo>(const NoSourceAnsweredFailure()),
      reason:
          'answering null here is what made an exhausted provider list '
          'indistinguishable from a tunnel that had not finished coming up',
    );
    expect(
      adapter.requests.length,
      greaterThan(1),
      reason: 'one provider refusing must not stop the next being asked',
    );
  });

  test('an exit that cannot reach Cloudflare still gets a reading', () async {
    final adapter = _ScriptedAdapter(
      _exitWithoutCloudflare(_identMeSwedishExit),
    );

    final result = await _repositoryThat(adapter).getIpInfo();
    final reading = result.getOrElse((_) => throw StateError('unreachable'));

    expect(
      reading.country,
      'Sweden',
      reason:
          'with every public provider behind one front, an exit that '
          'cannot reach it read "Location unavailable" on a tunnel that '
          'carried everything else',
    );
    expect(reading.countryCode, 'SE');
    expect(reading.ip, '203.0.113.7');
  });

  test('asks no Cloudflare-fronted provider before one that is not', () async {
    final adapter = _ScriptedAdapter(
      _exitWithoutCloudflare(_identMeSwedishExit),
    );

    await _repositoryThat(adapter).getIpInfo();

    expect(
      adapter.requests.where(_isCloudflareFronted),
      isEmpty,
      reason:
          'on an exit that cannot reach Cloudflare each of those is a '
          'refusal to sit through, up to the request timeout, before the '
          'badge has anything to show',
    );
  });

  test("ident.me's mirror stands in when ident.me does not answer", () async {
    final adapter = _ScriptedAdapter(
      (url) => Uri.parse(url).host == 'tnedi.me' ? _identMeSwedishExit : null,
    );

    final result = await _repositoryThat(adapter).getIpInfo();

    expect(
      result.getOrElse((_) => throw StateError('unreachable')).countryCode,
      'SE',
      reason:
          'the mirror runs on a separate host, so one of them being down '
          'must not cost the exits Cloudflare cannot serve their reading',
    );
    expect(
      adapter.requests.map((url) => Uri.parse(url).host),
      containsAllInOrder(['ident.me', 'tnedi.me']),
    );
  });

  test('asks every source over HTTPS, without exception', () async {
    final adapter = _ScriptedAdapter((_) => null);

    await _repositoryThat(adapter).getIpInfo();

    expect(adapter.requests, isNotEmpty);
    for (final url in adapter.requests) {
      expect(
        url,
        startsWith('https://'),
        reason:
            'a reading fetched over cleartext can be rewritten by anyone '
            'on the path, and the country badge is the one thing the screen '
            'exists to tell the user. A provider that cannot serve HTTPS '
            'belongs out of the list, not in it over http.',
      );
    }
  });

  test('a second read inside the cache window asks nobody', () async {
    final adapter = _ScriptedAdapter((_) => swedishExit);
    final repository = _repositoryThat(adapter);

    await repository.getIpInfo();
    final asked = adapter.requests.length;
    final second = await repository.getIpInfo();

    expect(second.isRight(), isTrue);
    expect(adapter.requests.length, asked);
  });

  test('forceRefresh asks again even with a fresh reading cached', () async {
    final adapter = _ScriptedAdapter((_) => swedishExit);
    final repository = _repositoryThat(adapter);

    await repository.getIpInfo();
    final asked = adapter.requests.length;
    await repository.getIpInfo(forceRefresh: true);

    expect(adapter.requests.length, greaterThan(asked));
  });

  test('a stale reading still beats a failure', () async {
    var reachable = true;
    final repository = _repositoryThat(
      _ScriptedAdapter((_) => reachable ? swedishExit : null),
    );

    await repository.getIpInfo();
    reachable = false;
    final result = await repository.getIpInfo(forceRefresh: true);

    expect(
      result.getOrElse((_) => throw StateError('unreachable')).country,
      'Sweden',
      reason:
          'an expired country beats a blank badge — the exit rarely '
          'moves while the same tunnel is up',
    );
  });

  test('clearing the cache drops the stale fallback too', () async {
    var reachable = true;
    final repository = _repositoryThat(
      _ScriptedAdapter((_) => reachable ? swedishExit : null),
    );

    await repository.getIpInfo();
    repository.clearCache();
    reachable = false;
    final result = await repository.getIpInfo();

    expect(
      result.isLeft(),
      isTrue,
      reason:
          'a disconnect clears the cache so a reconnect cannot serve the '
          'previous tunnel\'s exit',
    );
  });
}
