import 'package:begzar/core/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The free-tier API client.
///
/// It lives beside the service it builds rather than inside a feature module.
/// Connection is its main consumer, but the client itself is shared
/// infrastructure and a module's wiring is the wrong place to own it.
final apiV2ServiceProvider = Provider<ApiV2Service>((ref) {
  return ApiV2Service();
});
