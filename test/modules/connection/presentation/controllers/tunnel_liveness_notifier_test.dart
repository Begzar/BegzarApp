import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/tunnel_liveness.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/tunnel_liveness_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_analytics.dart';
import '../../connection_test_doubles.dart';

void main() {
  late FakeConnectionRepository connections;
  late ProviderContainer container;

  /// A container on the fakes with a live tunnel already adopted, which is the
  /// state every check runs in.
  Future<void> buildConnected() async {
    connections = FakeConnectionRepository(connectionActive: true);
    container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
      ],
    );
    addTearDown(container.dispose);
    container.read(tunnelLivenessProvider);
    await container.read(connectionProvider.notifier).reconcileWithNative();
  }

  Future<void> checkTimes(int count) async {
    for (var check = 0; check < count; check++) {
      await container.read(tunnelLivenessProvider.notifier).checkNow();
    }
  }

  group('TunnelLivenessNotifier', () {
    test(
      'should call a tunnel dead after the threshold of failed checks',
      () async {
        await buildConnected();
        connections.passingTraffic = false;

        await checkTimes(TunnelLiveness.deadAfterFailures);

        expect(container.read(tunnelLivenessProvider).isDead, isTrue);
      },
    );

    test('should not call it dead one failed check short', () async {
      await buildConnected();
      connections.passingTraffic = false;

      await checkTimes(TunnelLiveness.deadAfterFailures - 1);

      expect(container.read(tunnelLivenessProvider).isDead, isFalse);
    });

    test('should clear once traffic flows again', () async {
      await buildConnected();
      connections.passingTraffic = false;
      await checkTimes(TunnelLiveness.deadAfterFailures);

      connections.passingTraffic = true;
      await checkTimes(1);

      expect(container.read(tunnelLivenessProvider).isDead, isFalse);
    });

    // A warning about a tunnel that is gone would sit on the next one.
    test('should forget the checks once the tunnel is down', () async {
      await buildConnected();
      connections.passingTraffic = false;
      await checkTimes(TunnelLiveness.deadAfterFailures);

      await container.read(connectionProvider.notifier).disconnect();

      expect(container.read(tunnelLivenessProvider).isDead, isFalse);
    });

    test('should not check while nothing is connected', () async {
      await buildConnected();
      await container.read(connectionProvider.notifier).disconnect();
      final before = connections.trafficChecks;

      await checkTimes(1);

      expect(connections.trafficChecks, before);
    });
  });
}
