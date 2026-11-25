import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// Measures proxy real delay for premium configs through the engine.
///
/// Each config URL is probed through a throwaway Xray instance — not a raw TCP
/// connect to the remote host, and not through the live tunnel. On iOS the call
/// stays in the Runner process; on Android and Windows it uses the local relay
/// gateway only.
class PremiumPingDataSource {
  PremiumPingDataSource({BegzarEngine? engine}) : _engine = engine ?? BegzarEngine.ins;

  static const _probeUrl = 'https://www.google.com/generate_204';

  final BegzarEngine _engine;

  /// Latencies in input order; null when that config failed or timed out.
  Future<List<int?>> measureBatch(List<PremiumServerConfig> configs) async {
    if (configs.isEmpty) return const [];

    final samples = await _engine.realDelayAll(
      configs.map((c) => c.url).toList(),
      endpoint: _probeUrl,
    );

    return List<int?>.generate(configs.length, (index) {
      RealDelaySample? match;
      for (final sample in samples) {
        if (sample.index == index) {
          match = sample;
          break;
        }
      }
      if (match == null || !match.succeeded) return null;
      return match.elapsedMs;
    });
  }
}
