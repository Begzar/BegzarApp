import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/ip_info/application/services/ip_info_service.dart';
import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the repository's lifetime: it holds a Dio client and a five-minute
/// cache, so one instance per container is the point.
final ipInfoRepositoryProvider = Provider<IpInfoRepository>((ref) {
  return IpInfoRepository();
});

/// The port reader is `read` at call time, not `watch`ed: the repository is a
/// long-lived object whose port changes without the provider rebuilding, and
/// watching it would rebuild the service for no reason while still handing it
/// a number captured too early.
final ipInfoServiceProvider = Provider<IpInfoService>((ref) {
  return IpInfoService(
    ref.watch(ipInfoRepositoryProvider),
    socksPort: () => ref.read(connectionRepositoryProvider).activeSocksPort,
  );
});
