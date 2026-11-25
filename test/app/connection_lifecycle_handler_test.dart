import 'package:begzar/app/connection_lifecycle_handler.dart';
import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/providers/api_provider.dart';
import 'package:begzar/core/providers/connection_state_storage_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/ads/presentation/states/post_connect_ad_state.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../modules/connection/connection_test_doubles.dart';
import '../modules/premium/premium_test_doubles.dart';
import '../support/memory_keyed_storage.dart';
import '../support/recording_analytics.dart';

const _waitSeconds = 15;

Advertisement _ad() {
  final now = DateTime.now();
  return Advertisement(
    id: 7,
    title: 'title',
    description: 'description',
    bannerUrl: 'https://example.invalid/banner.png',
    clickUrl: 'https://example.invalid/go',
    position: 'post_connect',
    priority: 1,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 1)),
    type: 'banner',
    action: 'action',
    buttonColor: '#7A3FD4',
    duration: _waitSeconds,
  );
}

/// An adapter with nothing to report: no engine events, no status changes.
class _QuietAdapter extends FakeProxyCoreAdapter {
  @override
  Stream<bool> watchVpnStatusEvents() => const Stream.empty();
}

/// A tunnel that is up, and goes down when asked to and not otherwise.
///
/// What a lost tunnel does is left real, so it is built on the real service.
class _LiveTunnel extends ConnectionNotifier {
  _LiveTunnel({required this.adopted});

  final bool adopted;

  @override
  ConnectionEntity build() {
    super.build();
    return ConnectionEntity.create().connected(adopted: adopted);
  }

  @override
  Future<void> reconcileWithNative() async {}

  @override
  Future<void> disconnect() async => state = state.disconnected();
}

class _ShowingAd extends PostConnectAdNotifier {
  @override
  PostConnectAdState? build() =>
      PostConnectAdState.ready(_ad(), enforceWait: true);
}

ProviderContainer _container({
  required RecordingAnalytics analytics,
  required bool adopted,
  FakeConnectionRepository? connections,
}) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
      premiumRepositoryProvider.overrideWithValue(FakePremiumRepository()),
      proxyCoreAdapterProvider.overrideWithValue(_QuietAdapter()),
      connectionRepositoryProvider.overrideWithValue(
        connections ?? FakeConnectionRepository(),
      ),
      apiV2ServiceProvider.overrideWithValue(FakeApiV2Service()),
      connectionProvider.overrideWith(() => _LiveTunnel(adopted: adopted)),
      postConnectAdProvider.overrideWith(_ShowingAd.new),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpHandler(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ConnectionLifecycleHandler(child: SizedBox()),
    ),
  );
  await tester.pump();
}

/// Lets the handler's storage reads and premium restore come back.
Future<void> _settle(WidgetTester tester) async {
  for (var turn = 0; turn < 5; turn++) {
    await tester.pump();
  }
}

void main() {
  group('ConnectionLifecycleHandler', () {
    testWidgets('should record leaving mid-wait as abandoned in background', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = _container(analytics: analytics, adopted: false);
      await _pumpHandler(tester, container);
      container
          .read(connectionAdGateProvider.notifier)
          .start(seconds: _waitSeconds);

      // Android walks through inactive and hidden on its way to paused, and
      // both hidden and paused run the background check.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _settle(tester);

      expect(analytics.callsTo(#logPromotionAbandoned), [
        {
          #cause: PromotionAbandonCause.background,
          #promotionId: 7,
          #promotionName: 'title',
          #secondsLeft: _waitSeconds,
        },
      ]);
    });

    testWidgets('should record nothing when the wait was already served', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = _container(analytics: analytics, adopted: false);
      await _pumpHandler(tester, container);
      container.read(connectionAdGateProvider.notifier).start(seconds: 1);
      await tester.pump(const Duration(seconds: 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _settle(tester);

      expect(analytics.callsTo(#logPromotionAbandoned), isEmpty);
    });

    // Being killed is not caught while it happens; the next launch finds the
    // flag the gate left and takes the tunnel back. Which ad it was went with
    // the process, so only the cause is known.
    testWidgets('should record a launch that takes the tunnel back', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = _container(analytics: analytics, adopted: true);
      await container
          .read(connectionStateStorageProvider)
          .setAdGateActive(true);

      await _pumpHandler(tester, container);
      await _settle(tester);

      expect(analytics.callsTo(#logPromotionAbandoned), [
        {
          #cause: PromotionAbandonCause.relaunch,
          #promotionId: null,
          #promotionName: null,
          #secondsLeft: null,
        },
      ]);
    });

    testWidgets('should record nothing on a launch with no unwatched ad', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      final container = _container(analytics: analytics, adopted: true);

      await _pumpHandler(tester, container);
      await _settle(tester);

      expect(analytics.callsTo(#logPromotionAbandoned), isEmpty);
    });

    testWidgets('should end the connection when the tunnel is lost', (
      tester,
    ) async {
      final connections = FakeConnectionRepository();
      final container = _container(
        analytics: RecordingAnalytics(),
        adopted: false,
        connections: connections,
      );
      await _pumpHandler(tester, container);
      await _settle(tester);

      connections.loseTunnel();
      await _settle(tester);

      final connection = container.read(connectionProvider);
      expect(connection.status, ConnectionStatus.error);
      expect(connection.errorMessage, UserFacingErrorKeys.tunnelStopped);
      expect(connections.disconnectCount, 1);
    });
  });
}
