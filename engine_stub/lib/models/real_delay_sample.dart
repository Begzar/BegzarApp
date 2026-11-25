// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// One real-delay probe result from [BegzarEngine.realDelayAll].
class RealDelaySample {
  const RealDelaySample({required this.index, required this.elapsedMs});

  /// Position in the input link list.
  final int index;

  /// Round-trip latency in milliseconds, or `-1` when the probe failed.
  final int elapsedMs;

  bool get succeeded => elapsedMs >= 0;
}
