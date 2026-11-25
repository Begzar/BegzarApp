import 'package:begzar/modules/main/domain/ping_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grades a latency into its band', () {
    expect(PingQuality.forLatency(0), PingQuality.excellent);
    expect(PingQuality.forLatency(120), PingQuality.excellent);
    expect(PingQuality.forLatency(600), PingQuality.good);
    expect(PingQuality.forLatency(900), PingQuality.fair);
    expect(PingQuality.forLatency(4000), PingQuality.poor);
  });

  // Each boundary belongs to the slower band, which is what the two `if`
  // ladders in the widget did and what a user would expect: 500ms is not
  // excellent.
  test('a boundary falls into the slower band', () {
    expect(PingQuality.forLatency(499), PingQuality.excellent);
    expect(PingQuality.forLatency(500), PingQuality.good);
    expect(PingQuality.forLatency(799), PingQuality.good);
    expect(PingQuality.forLatency(800), PingQuality.fair);
    expect(PingQuality.forLatency(999), PingQuality.fair);
    expect(PingQuality.forLatency(1000), PingQuality.poor);
  });

  // A failed probe reports -1. Grading it by the same ladder would have made
  // it the fastest possible connection.
  test('a failed measurement is poor, not excellent', () {
    expect(PingQuality.forLatency(-1), PingQuality.poor);
    expect(PingQuality.forLatency(-9999), PingQuality.poor);
  });

  test('every band is reachable', () {
    final graded = [
      for (final ms in [100, 600, 900, 2000]) PingQuality.forLatency(ms),
    ];

    expect(graded.toSet(), PingQuality.values.toSet());
  });
}
