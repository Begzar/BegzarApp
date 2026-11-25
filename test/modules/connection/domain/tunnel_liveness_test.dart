import 'package:begzar/modules/connection/domain/tunnel_liveness.dart';
import 'package:flutter_test/flutter_test.dart';

/// [start] after each check in [results], in order.
TunnelLiveness _after(List<bool> results, {TunnelLiveness? start}) {
  var liveness = start ?? const TunnelLiveness();
  for (final passed in results) {
    liveness = liveness.after(passed: passed);
  }
  return liveness;
}

void main() {
  group('TunnelLiveness', () {
    test('should start alive and check again after the healthy interval', () {
      const liveness = TunnelLiveness();

      expect(liveness.isDead, isFalse);
      expect(liveness.nextCheckIn, TunnelLiveness.healthyInterval);
    });

    test('should stay alive one check short of the threshold', () {
      final liveness = _after(
        List.filled(TunnelLiveness.deadAfterFailures - 1, false),
      );

      expect(liveness.isDead, isFalse);
    });

    test('should be dead once the threshold of failed checks is reached', () {
      final liveness = _after(
        List.filled(TunnelLiveness.deadAfterFailures, false),
      );

      expect(liveness.isDead, isTrue);
    });

    test('should come back alive on the first check that passes', () {
      final dead = _after(List.filled(TunnelLiveness.deadAfterFailures, false));

      final liveness = dead.after(passed: true);

      expect(liveness.isDead, isFalse);
      expect(liveness.nextCheckIn, TunnelLiveness.healthyInterval);
    });

    // A pass between failures is a tunnel that still carries traffic, so the
    // count starts again rather than adding up across it.
    test('should count only failures in a row', () {
      final liveness = _after([false, false, true, false, false]);

      expect(liveness.isDead, isFalse);
    });

    test(
      'should retry sooner after the first failure, then a little later',
      () {
        final once = _after([false]);
        final twice = _after([false, false]);
        final dead = _after(
          List.filled(TunnelLiveness.deadAfterFailures, false),
        );

        expect(once.nextCheckIn, TunnelLiveness.firstRetryIn);
        expect(twice.nextCheckIn, TunnelLiveness.laterRetryIn);
        expect(dead.nextCheckIn, TunnelLiveness.laterRetryIn);
        expect(
          TunnelLiveness.firstRetryIn < TunnelLiveness.laterRetryIn,
          isTrue,
        );
        expect(
          TunnelLiveness.laterRetryIn < TunnelLiveness.healthyInterval,
          isTrue,
        );
      },
    );
  });
}
