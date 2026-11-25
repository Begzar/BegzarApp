import 'dart:io';

import 'package:begzar/core/network/begzar_image_cache.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnceThenOk extends FileService {
  _OnceThenOk();

  int calls = 0;
  Map<String, String>? lastHeaders;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    lastHeaders = headers;
    calls++;
    if (calls == 1) {
      throw const HttpException('Connection closed before full header was received');
    }
    return _EmptyResponse();
  }
}

class _AlwaysFails extends FileService {
  int calls = 0;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls++;
    throw const HttpException('Connection closed before full header was received');
  }
}

class _EmptyResponse implements FileServiceResponse {
  @override
  Stream<List<int>> get content => const Stream.empty();

  @override
  int? get contentLength => 0;

  @override
  int get statusCode => 200;

  @override
  DateTime get validTill => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.png';
}

void main() {
  test('a closed connection is retried once and then succeeds', () async {
    final inner = _OnceThenOk();
    final service = BegzarImageFileService(inner: inner);

    final response = await service.get('https://example.invalid/flag.png');

    expect(inner.calls, 2);
    expect(response.statusCode, 200);
    expect(inner.lastHeaders, containsPair('connection', 'close'));
  });

  test('a second failure is not retried again', () async {
    final inner = _AlwaysFails();
    final service = BegzarImageFileService(inner: inner);

    await expectLater(
      service.get('https://example.invalid/flag.png'),
      throwsA(isA<HttpException>()),
    );
    expect(inner.calls, 2);
  });
}
