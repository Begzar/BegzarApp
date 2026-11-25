// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// One latency measurement from [BegzarEngine.measureLatency].
class LatencySample {
  const LatencySample({required this.url, required this.elapsedMs});

  /// The URL that was measured.
  final String url;

  /// Round-trip latency in milliseconds, or `-1` when the measurement failed.
  final int elapsedMs;

  bool get succeeded => elapsedMs >= 0;
}
