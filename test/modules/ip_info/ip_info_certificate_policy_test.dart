import 'dart:io';
import 'dart:typed_data';

import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_begzar_backend.dart';

/// The adapter the repository is currently routing through.
IOHttpClientAdapter _adapterOf(Dio dio) =>
    dio.httpClientAdapter as IOHttpClientAdapter;

/// A repository whose Dio the test can reach into, on the route [configure]
/// selects.
Dio _dioRoutedBy(void Function(IpInfoRepository repository) configure) {
  final dio = Dio();
  configure(IpInfoRepository(dio: dio));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final routes = <String, Dio Function()>{
    'through the tunnel': () =>
        _dioRoutedBy((r) => r.enableProxy(host: '127.0.0.1', port: 10808)),
    'direct': () => _dioRoutedBy((r) => r.disableProxy()),
  };

  for (final route in routes.entries) {
    test('the exit-IP lookup ${route.key} leaves the public providers to the '
        'platform trust store', () {
      // None of them has a pin. Begzar's own endpoint, which does, is asked
      // through the engine, which holds it to its key.
      expect(_adapterOf(route.value()).validateCertificate, isNull);
    });
  }

  test('the direct route builds a stock client and configures nothing on it', () {
    final adapter = _adapterOf(_dioRoutedBy((r) => r.disableProxy()));

    // What stood here was a closure setting
    // `badCertificateCallback = (cert, host, port) => true`, which accepted any
    // certificate from any host on an ordinary HTTPS request. The trust store
    // only gets the decision back while nothing is configured on the client at
    // all, so this holds the route to the bare constructor.
    expect(adapter.createHttpClient, same(HttpClient.new));
  });

  group("Begzar's own reading", () {
    late List<String> asked;
    late Dio dio;
    late IpInfoRepository repository;

    setUp(() {
      asked = [];
      dio = Dio()..httpClientAdapter = _Refusing();
      repository = IpInfoRepository(
        dio: dio,
        backend: FakeBegzarBackend(
          onLookupExit: (viaSocks5) async {
            asked.add(viaSocks5);
            throw const BackendException(BackendFailureKind.pinning);
          },
        ),
      );
    });

    test('is asked of the engine through the tunnel', () async {
      repository.enableProxy(host: '127.0.0.1', port: 10808);
      await repository.getIpInfo();

      expect(asked, ['127.0.0.1:10808']);
    });

    test('is asked directly once the tunnel is gone', () async {
      repository.disableProxy();
      // Going direct installs a real client; keep the public providers
      // refusing, so nothing leaves the machine.
      dio.httpClientAdapter = _Refusing();
      await repository.getIpInfo();

      expect(asked.single, isEmpty);
    });

    test('a pin failure costs only its own reading', () async {
      // Every source refuses here, so the result is the repository's
      // "nothing answered"; the point is that the pin failure did not throw
      // out of it.
      final result = await repository.getIpInfo();
      expect(result.isLeft(), isTrue);
    });
  });
}

/// Refuses every request, so the public providers never touch a socket.
class _Refusing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused in tests',
    );
  }

  @override
  void close({bool force = false}) {}
}
