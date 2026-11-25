/// Whether a connected tunnel still carries traffic, as the checks made on it
/// so far say.
///
/// One failed check is a moment of bad network as often as a dead server, so
/// the tunnel is called dead only after [deadAfterFailures] of them in a row,
/// checked sooner than usual once one has failed. Any check that passes starts
/// the count again.
class TunnelLiveness {
  const TunnelLiveness({this.failuresInARow = 0});

  /// How long a tunnel that carries traffic waits before it is checked again.
  static const healthyInterval = Duration(seconds: 30);

  /// How soon a check runs again after one has failed.
  static const firstRetryIn = Duration(seconds: 5);

  /// How soon a check runs again after two or more failed in a row, a dead
  /// tunnel's included, so one that recovers is noticed quickly.
  static const laterRetryIn = Duration(seconds: 10);

  /// How many failed checks in a row make a tunnel dead.
  static const deadAfterFailures = 3;

  final int failuresInARow;

  bool get isDead => failuresInARow >= deadAfterFailures;

  /// When the next check is due, counted from the last one.
  Duration get nextCheckIn => switch (failuresInARow) {
    0 => healthyInterval,
    1 => firstRetryIn,
    _ => laterRetryIn,
  };

  /// What the checks say once one more has run.
  TunnelLiveness after({required bool passed}) => passed
      ? const TunnelLiveness()
      : TunnelLiveness(failuresInARow: failuresInARow + 1);
}
