/// How good a round-trip time is, as the home screen reports it.
///
/// The thresholds were previously written out twice in the ping widget —
/// once to pick a colour and once to pick a label — as two `if` ladders over
/// the same three numbers. Nothing kept them in step, and a change to one
/// would have silently produced a green pill reading "Poor".
///
/// The bands are wide because this measures a proxied round trip through a
/// tunnel, often to a server on another continent. What counts as excellent
/// here is not what would count on a local network.
enum PingQuality {
  /// Under [_excellentBelowMs]. Usable for anything, video calls included.
  excellent,

  /// Noticeable on a call, fine for browsing.
  good,

  /// Slow enough to feel, still workable.
  fair,

  /// At or over [_fairBelowMs], or a measurement that never came back.
  poor;

  static const _excellentBelowMs = 500;
  static const _goodBelowMs = 800;
  static const _fairBelowMs = 1000;

  /// Grades a latency in milliseconds.
  ///
  /// A negative value is what a failed probe reports, and it grades as [poor]
  /// rather than wrapping around into [excellent].
  static PingQuality forLatency(int latencyMs) {
    if (latencyMs < 0) return poor;
    if (latencyMs < _excellentBelowMs) return excellent;
    if (latencyMs < _goodBelowMs) return good;
    if (latencyMs < _fairBelowMs) return fair;
    return poor;
  }
}
