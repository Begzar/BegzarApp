/// Value object representing ping measurement results
class PingResult {
  final int latencyMs;
  final bool isSuccessful;
  final DateTime timestamp;
  final String? errorMessage;

  const PingResult({
    required this.latencyMs,
    required this.isSuccessful,
    required this.timestamp,
    this.errorMessage,
  });

  /// Create a successful ping result
  factory PingResult.success(int latencyMs) {
    return PingResult(
      latencyMs: latencyMs,
      isSuccessful: true,
      timestamp: DateTime.now(),
    );
  }

  /// Create a failed ping result
  factory PingResult.failure(String errorMessage) {
    return PingResult(
      latencyMs: -1,
      isSuccessful: false,
      timestamp: DateTime.now(),
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PingResult &&
        other.latencyMs == latencyMs &&
        other.isSuccessful == isSuccessful &&
        other.timestamp == timestamp &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(latencyMs, isSuccessful, timestamp, errorMessage);
  }

  @override
  String toString() {
    return 'PingResult(latencyMs: $latencyMs, isSuccessful: $isSuccessful, timestamp: $timestamp)';
  }
}
