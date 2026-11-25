import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Disk cache for public artwork — server flags, ad banners — that does not
/// go through the pinned API client.
///
/// Keep-alive is off and a failed fetch is tried once on a new socket. The
/// same LTE middleboxes that stall reused API connections do it to a list of
/// images on one CDN host: some flags arrive, the rest die with
/// "connection closed before full header was received".
class BegzarImageCache {
  BegzarImageCache._();

  static final CacheManager instance = CacheManager(
    Config('begzarImages', fileService: BegzarImageFileService()),
  );
}

/// Fetches one URL without pooling the socket, and retries a transport
/// failure once. HTTP errors (404, 403) are responses, not throws, and are
/// not retried.
class BegzarImageFileService extends FileService {
  BegzarImageFileService({FileService? inner, this.maxRetries = 1})
    : _inner = inner ?? HttpFileService(httpClient: _httpClient()) {
    // A server list can be a dozen flags at once. Four at a time keeps LTE
    // from opening a burst of TLS sessions that the middlebox then resets.
    concurrentFetches = 4;
  }

  final FileService _inner;
  final int maxRetries;

  static http.Client _httpClient() {
    final io = HttpClient()..idleTimeout = Duration.zero;
    return IOClient(io);
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final closed = <String, String>{
      ...?headers,
      HttpHeaders.connectionHeader: 'close',
    };

    var attempt = 0;
    while (true) {
      try {
        return await _inner.get(url, headers: closed);
      } on Exception {
        if (attempt >= maxRetries) rethrow;
        attempt++;
      }
    }
  }
}
