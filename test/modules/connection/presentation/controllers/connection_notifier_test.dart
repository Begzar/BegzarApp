import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/providers/api_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/recording_analytics.dart';
import '../../connection_test_doubles.dart';

void main() {
  late FakeConnectionRepository connections;
  late ProviderContainer container;
  late RecordingAnalytics analytics;

  /// Builds a container wired to the fakes, leaving the rest of the real
  /// use-case/service graph in place.
  void buildContainer({ApiV2Service? apiV2}) {
    analytics = RecordingAnalytics();
    container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        analyticsServiceProvider.overrideWithValue(analytics),
        if (apiV2 != null) apiV2ServiceProvider.overrideWithValue(apiV2),
      ],
    );
    addTearDown(container.dispose);
  }

  ConnectionStatus statusOf() => container.read(connectionProvider).status;

  group('connect fold', () {
    test('publishes the connected entity the repository returned', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(statusOf(), ConnectionStatus.connected);
      expect(container.read(connectionProvider).errorMessage, isNull);
    });

    test('maps a failure to an error state with a localisable key', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(false)});
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(statusOf(), ConnectionStatus.error);
      expect(
        container.read(connectionProvider).errorMessage,
        UserFacingErrorKeys.proxyTestFailed,
      );
    });

    test('never leaves a raw error string in the entity', () async {
      // testConfig carries a scheme the validator rejects, so this fails at
      // validation rather than at the tunnel — a different branch from the
      // test above, and the one most likely to leak a raw URL.
      connections = FakeConnectionRepository();
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(testConfig('rejected'));

      expect(
        UserFacingErrorKeys.all,
        contains(container.read(connectionProvider).errorMessage),
      );
    });
  });

  group('connectAuto fold', () {
    test('reports the no-working-config key when every config fails', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(false)});
      buildContainer();

      await container.read(connectionProvider.notifier).connectAuto([
        testConfig('a'),
      ]);

      expect(statusOf(), ConnectionStatus.error);
      expect(
        container.read(connectionProvider).errorMessage,
        UserFacingErrorKeys.noWorkingConfig,
      );
    });

    test(
      'reports the access-denied key when VPN permission is refused',
      () async {
        // Probing runs beside the tunnel and never asks for the permission,
        // so a refusal arrives from the dial of the config that answered.
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          connectResult: left(VpnPermissionFailure()),
        );
        buildContainer();

        await container.read(connectionProvider.notifier).connectAuto([
          testConfig('a'),
        ]);

        expect(
          container.read(connectionProvider).errorMessage,
          UserFacingErrorKeys.accessDenied,
        );
      },
    );
  });

  group('disconnect fold', () {
    test('returns to ready on success', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      await notifier.disconnect();

      expect(statusOf(), ConnectionStatus.ready);
    });

    test('surfaces an error rather than silently reporting ready', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'a': right(true)},
        disconnectResult: left(
          const TunnelFailure(
            'Disconnect failed',
            userFacingKey: UserFacingErrorKeys.connectionFailed,
          ),
        ),
      );
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      await notifier.disconnect();

      expect(statusOf(), ConnectionStatus.error);
    });
  });

  group('reconcileWithNative', () {
    test('does not promote to connected while still connecting', () async {
      connections = FakeConnectionRepository(connectionActive: true);
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      notifier.beginConnecting();
      await notifier.reconcileWithNative();

      expect(
        statusOf(),
        ConnectionStatus.connecting,
        reason: 'promoting mid-test would fire the post-connect ad early',
      );
    });

    test(
      'promotes to connected when the tunnel is up and state is idle',
      () async {
        connections = FakeConnectionRepository(connectionActive: true);
        buildContainer();

        await container.read(connectionProvider.notifier).reconcileWithNative();

        expect(statusOf(), ConnectionStatus.connected);
      },
    );

    test(
      'does not promote to connected after a failed connect left the tunnel up',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(false)},
        );
        buildContainer();

        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect(dialableConfig('a'));
        expect(statusOf(), ConnectionStatus.error);
        // Teardown raced or failed; native still reports up.
        connections.connectionActive = true;
        await notifier.reconcileWithNative();

        expect(statusOf(), ConnectionStatus.error);
      },
    );

    test('demotes to ready when the tunnel went down underneath us', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      connections.connectionActive = false;
      await notifier.reconcileWithNative();

      expect(statusOf(), ConnectionStatus.ready);
    });

    // The post-connect ad hangs off the transition into connected, and this is
    // the one route that reaches it without the user having asked for a
    // connection. Reopening the app over a live tunnel used to look exactly
    // like connecting, and charged the user a second ad for it.
    test('marks a tunnel it found rather than dialled', () async {
      connections = FakeConnectionRepository(connectionActive: true);
      buildContainer();

      await container.read(connectionProvider.notifier).reconcileWithNative();

      expect(container.read(connectionProvider).adopted, isTrue);
    });

    test('a connect this app performed is not adopted', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(container.read(connectionProvider).adopted, isFalse);
    });
  });

  // On Windows the tunnel is a helper in front of the engine, and either can
  // go on its own. The app must not read as connected while the helper is
  // gone, nor as merely disconnected while it still routes every app's
  // traffic into an engine that is gone.
  group('a lost tunnel', () {
    String? errorMessageOf() => container.read(connectionProvider).errorMessage;

    test(
      'should end a connected tunnel with tunnelStopped when it is lost',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          throughHelper: true,
        );
        buildContainer();
        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect(dialableConfig('a'));

        connections.loseTunnel();
        await notifier.endLostTunnel();

        expect(statusOf(), ConnectionStatus.error);
        expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
        expect(connections.disconnectCount, 1);
        expect(
          analytics.callsTo(#logUserDisconnected),
          isEmpty,
          reason: 'the user did not end this session',
        );
      },
    );

    test('should ignore a lost tunnel when not connected', () async {
      connections = FakeConnectionRepository(throughHelper: true);
      buildContainer();

      await container.read(connectionProvider.notifier).endLostTunnel();

      expect(statusOf(), ConnectionStatus.ready);
      expect(errorMessageOf(), isNull);
      expect(connections.disconnectCount, 0);
    });

    test(
      'should end the connection when the tunnel is lost before connected is published',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          throughHelper: true,
        )..holdTunnelStartedAt = Completer<void>();
        buildContainer();
        final seen = <ConnectionStatus>[];
        container.listen(
          connectionProvider,
          (_, next) => seen.add(next.status),
        );

        final notifier = container.read(connectionProvider.notifier);
        final pending = notifier.connect(dialableConfig('a'));
        await pumpEventQueue();
        // The helper said it was ready and went before the connect published.
        // The loss is reported while the connection still reads as
        // connecting, which leaves it nothing to end.
        connections.loseTunnel();
        await notifier.endLostTunnel();
        connections.holdTunnelStartedAt!.complete();
        await pending;

        expect(
          seen,
          isNot(contains(ConnectionStatus.connected)),
          reason: 'the post-connect ad hangs off connected',
        );
        expect(statusOf(), ConnectionStatus.error);
        expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
        expect(connections.disconnectCount, 1);
      },
    );

    test(
      'should end an auto connect whose tunnel is lost before connected is published',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          throughHelper: true,
        )..holdTunnelStartedAt = Completer<void>();
        buildContainer();
        final seen = <ConnectionStatus>[];
        container.listen(
          connectionProvider,
          (_, next) => seen.add(next.status),
        );

        final notifier = container.read(connectionProvider.notifier);
        final pending = notifier.connectAuto([testConfig('a')]);
        await pumpEventQueue();
        connections.loseTunnel();
        await notifier.endLostTunnel();
        connections.holdTunnelStartedAt!.complete();
        await pending;

        expect(seen, isNot(contains(ConnectionStatus.connected)));
        expect(statusOf(), ConnectionStatus.error);
        expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
        expect(connections.disconnectCount, 1);
      },
    );

    // Reconciliation adopts a tunnel it finds up, and a few awaits pass
    // between finding it and saying so.
    test('should not adopt a tunnel whose helper is gone by then', () async {
      connections = FakeConnectionRepository(connectionActive: true)
        ..connectedThroughHelper = true
        ..helperRunning = true
        ..holdTunnelStartedAt = Completer<void>();
      buildContainer();
      final seen = <ConnectionStatus>[];
      container.listen(connectionProvider, (_, next) => seen.add(next.status));

      final notifier = container.read(connectionProvider.notifier);
      final reconciling = notifier.reconcileWithNative();
      await pumpEventQueue();
      connections.loseTunnel();
      await notifier.endLostTunnel();
      connections.holdTunnelStartedAt!.complete();
      await reconciling;

      expect(seen, isNot(contains(ConnectionStatus.connected)));
      expect(statusOf(), ConnectionStatus.error);
      expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
      expect(connections.disconnectCount, 1);
    });

    test(
      'should end a quick connect whose tunnel is lost before connected is published',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {kFreeTierConfigName: right(true)},
          throughHelper: true,
        )..holdTunnelStartedAt = Completer<void>();
        buildContainer(apiV2: FakeApiV2Service());
        final seen = <ConnectionStatus>[];
        container.listen(
          connectionProvider,
          (_, next) => seen.add(next.status),
        );

        final notifier = container.read(connectionProvider.notifier);
        final pending = notifier.connectWithApiV2();
        await pumpEventQueue();
        connections.loseTunnel();
        await notifier.endLostTunnel();
        connections.holdTunnelStartedAt!.complete();
        await pending;

        expect(seen, isNot(contains(ConnectionStatus.connected)));
        expect(statusOf(), ConnectionStatus.error);
        expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
        expect(connections.disconnectCount, 1);
      },
    );

    test(
      'should take the helper down when the engine stops under a tunnel',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          throughHelper: true,
        );
        buildContainer();
        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect(dialableConfig('a'));

        // The engine is gone and the helper is not, so its tunnel still takes
        // every app's traffic, into a port nothing answers on.
        connections.connectionActive = false;
        await notifier.reconcileWithNative();

        expect(connections.helperRunning, isFalse);
        expect(connections.disconnectCount, 1);
        expect(statusOf(), ConnectionStatus.error);
        expect(errorMessageOf(), UserFacingErrorKeys.tunnelStopped);
      },
    );

    test(
      'should only mark a connection made without the helper as down',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
        );
        buildContainer();
        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect(dialableConfig('a'));

        connections.connectionActive = false;
        await notifier.reconcileWithNative();

        expect(statusOf(), ConnectionStatus.ready);
        expect(errorMessageOf(), isNull);
        expect(connections.disconnectCount, 0);
      },
    );

    test(
      'should end a lost tunnel once when the engine and the helper both report it',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(true)},
          throughHelper: true,
        );
        buildContainer();
        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect(dialableConfig('a'));
        final failures = <String?>[];
        container.listen(connectionProvider, (_, next) {
          if (next.status == ConnectionStatus.error) {
            failures.add(next.errorMessage);
          }
        });

        // The engine dies and takes the helper with it, so the health check
        // and the helper's lease report the same loss, the second while the
        // first is still taking the tunnel down.
        connections
          ..holdDisconnect = Completer<void>()
          ..connectionActive = false;
        final reconciling = notifier.reconcileWithNative();
        await pumpEventQueue();
        connections.loseTunnel();
        final ending = notifier.endLostTunnel();
        connections.holdDisconnect!.complete();
        await Future.wait([reconciling, ending]);

        expect(connections.disconnectCount, 1);
        expect(failures, [UserFacingErrorKeys.tunnelStopped]);
      },
    );
  });

  group('a session is timed by the tunnel, not by the app', () {
    // The home screen counts a session from `connectedAt`, so stamping it
    // where the app noticed made the reading wrong exactly when it matters
    // most: reopen the app over a tunnel that stayed up and the clock
    // restarted from zero, reporting a fresh connection for one hours old.
    final cameUpAt = DateTime(2026, 9, 5, 14, 30);

    test('an adopted tunnel is dated from when it came up', () async {
      connections = FakeConnectionRepository(
        connectionActive: true,
        tunnelStartedAtResult: cameUpAt,
      );
      buildContainer();

      await container.read(connectionProvider.notifier).reconcileWithNative();

      expect(container.read(connectionProvider).connectedAt, cameUpAt);
    });

    test('a connect this app performed is dated the same way', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'a': right(true)},
        tunnelStartedAtResult: cameUpAt,
      );
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(
        container.read(connectionProvider).connectedAt,
        cameUpAt,
        reason:
            'a connect ends when the last probe comes back, and the '
            'tunnel it probed was already up',
      );
    });

    test('a platform that cannot say falls back to now', () async {
      connections = FakeConnectionRepository(connectionActive: true);
      buildContainer();

      await container.read(connectionProvider.notifier).reconcileWithNative();

      final connectedAt = container.read(connectionProvider).connectedAt;
      expect(connectedAt, isNotNull);
      expect(
        DateTime.now().difference(connectedAt!).inSeconds,
        lessThan(5),
        reason:
            'a desktop build and an older engine both answer null, and '
            'neither should leave the clock with nothing to count from',
      );
    });
  });

  group('startup reconciliation', () {
    test('adopts connected when the tunnel is already up', () async {
      connections = FakeConnectionRepository(connectionActive: true);
      buildContainer();

      await container.read(connectionProvider.notifier).reconcileWithNative();

      expect(statusOf(), ConnectionStatus.connected);
    });

    test('stays ready when no tunnel is running', () async {
      connections = FakeConnectionRepository(connectionActive: false);
      buildContainer();

      await container.read(connectionProvider.notifier).reconcileWithNative();

      expect(statusOf(), ConnectionStatus.ready);
    });

    test('needs no stored status to decide', () async {
      connections = FakeConnectionRepository(connectionActive: true);
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.reconcileWithNative();
      connections.connectionActive = false;
      await notifier.reconcileWithNative();

      expect(
        statusOf(),
        ConnectionStatus.ready,
        reason: 'the tunnel is the only thing consulted, on every call',
      );
    });
  });

  group('cancelConnecting', () {
    late FakeApiV2Service apiV2;

    /// [buildContainer], with the free tier answering from [service] rather
    /// than the production API. It is kept as [apiV2] for the test to hold.
    void buildFreeTierContainer([FakeApiV2Service? service]) {
      apiV2 = service ?? FakeApiV2Service();
      container = ProviderContainer(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(connections),
          apiV2ServiceProvider.overrideWithValue(apiV2),
        ],
      );
      addTearDown(container.dispose);
    }

    test('should take a connect in flight straight back to ready', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
        ..holdProbe = Completer<void>();
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      final pending = notifier.connectAuto([testConfig('a')]);
      await pumpEventQueue();
      await notifier.cancelConnecting();

      expect(
        statusOf(),
        ConnectionStatus.ready,
        reason: 'the dial answers the tap, not the probe it cut short',
      );

      connections.holdProbe!.complete();
      await pending;

      expect(statusOf(), ConnectionStatus.ready);
      expect(connections.connectedConfigNames, isEmpty);
    });

    test('should never publish connected for a cancelled connect', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
        ..holdDial = Completer<void>();
      buildContainer();

      final seen = <ConnectionStatus>[];
      container.listen(connectionProvider, (_, next) => seen.add(next.status));

      final notifier = container.read(connectionProvider.notifier);
      final pending = notifier.connectAuto([testConfig('a')]);
      await pumpEventQueue();
      await notifier.cancelConnecting();
      connections.holdDial!.complete();
      await pending;

      expect(
        seen,
        [ConnectionStatus.connecting, ConnectionStatus.ready],
        reason:
            'the post-connect ad hangs off connected, and a connect the '
            'user called off must not reach it',
      );
    });

    test('should not go on to probe once the server answers', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {kFreeTierConfigName: right(true)},
      );
      buildFreeTierContainer();
      apiV2.holdFetch = Completer<void>();

      final notifier = container.read(connectionProvider.notifier);
      final pending = notifier.connectWithApiV2();
      await pumpEventQueue();
      await notifier.cancelConnecting();
      apiV2.holdFetch!.complete();
      await pending;

      expect(connections.probeStopAfters, isEmpty);
      expect(statusOf(), ConnectionStatus.ready);
    });

    test('should not publish a failure from the step it cut short', () async {
      connections = FakeConnectionRepository();
      buildFreeTierContainer(
        FakeApiV2Service(
          subscriptionResult: left(const NetworkFailure('offline')),
        ),
      );
      apiV2.holdFetch = Completer<void>();

      final notifier = container.read(connectionProvider.notifier);
      final pending = notifier.connectWithApiV2();
      await pumpEventQueue();
      await notifier.cancelConnecting();
      apiV2.holdFetch!.complete();
      await pending;

      expect(statusOf(), ConnectionStatus.ready);
      expect(container.read(connectionProvider).errorMessage, isNull);
    });

    test('should leave a connected tunnel alone', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      await notifier.cancelConnecting();

      expect(statusOf(), ConnectionStatus.connected);
      expect(connections.disconnectCount, 0);
    });

    test('should let the next connect through', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
        ..holdProbe = Completer<void>();
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      final cancelled = notifier.connectAuto([testConfig('a')]);
      await pumpEventQueue();
      await notifier.cancelConnecting();
      connections.holdProbe!.complete();
      await cancelled;

      await notifier.connectAuto([testConfig('a')]);

      expect(statusOf(), ConnectionStatus.connected);
    });

    test('should keep reconciliation from adopting the tunnel a cancelled dial '
        'left up', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
        ..holdDial = Completer<void>()
        ..holdDisconnect = Completer<void>();
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      final pending = notifier.connectAuto([testConfig('a')]);
      await pumpEventQueue();
      final cancelling = notifier.cancelConnecting();

      // The dial lands after the cancel, and its tunnel is up until the
      // teardown after it gets through.
      connections.holdDial!.complete();
      await pumpEventQueue();
      expect(connections.connectionActive, isTrue);

      final reconciling = notifier.reconcileWithNative();
      await pumpEventQueue();
      expect(
        statusOf(),
        ConnectionStatus.ready,
        reason:
            'adopting it would read as connected for a connect the user '
            'called off',
      );

      connections.holdDisconnect!.complete();
      await Future.wait([pending, cancelling, reconciling]);

      expect(statusOf(), ConnectionStatus.ready);
      expect(connections.connectionActive, isFalse);
    });
  });

  group('connectWithApiV2 subscription lines', () {
    /// [buildContainer], with the free tier answering [configUrls].
    void buildWithSubscription(List<String> configUrls) {
      buildContainer(
        apiV2: FakeApiV2Service(
          subscriptionResult: right(
            SubscriptionPayload(configUrls: configUrls),
          ),
        ),
      );
    }

    test('should try only the lines the engine can dial', () async {
      connections = FakeConnectionRepository();
      buildWithSubscription(const [
        'hysteria://first-version',
        'hy2://second-version',
        'vless://host',
      ]);

      await container.read(connectionProvider.notifier).connectWithApiV2();

      expect(
        connections.testedConfigNames,
        unorderedEquals(['Server 2', 'Server 3']),
        reason: 'a config keeps the position the server listed it at',
      );
    });

    test('should report no configs when no line can be dialed', () async {
      connections = FakeConnectionRepository();
      buildWithSubscription(const ['hysteria://first-version']);

      await container.read(connectionProvider.notifier).connectWithApiV2();

      expect(connections.testedConfigNames, isEmpty);
      expect(statusOf(), ConnectionStatus.error);
      expect(
        container.read(connectionProvider).errorMessage,
        UserFacingErrorKeys.noConfigsFromServer,
      );
    });

    test('should not count undialable lines toward the cap', () async {
      const undialable = 3;
      final cap = ConnectionNotifier.maxSubscriptionConfigs;
      connections = FakeConnectionRepository();
      buildWithSubscription([
        for (var index = 0; index < undialable; index++)
          'hysteria://first-version-$index',
        for (var index = 0; index < cap + 5; index++) 'hy2://host-$index',
      ]);

      await container.read(connectionProvider.notifier).connectWithApiV2();

      expect(
        connections.testedConfigNames,
        unorderedEquals([
          for (var index = 0; index < cap; index++)
            'Server ${undialable + index + 1}',
        ]),
      );
    });
  });

  group('transition guards', () {
    test('clearError only acts on an error state', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      notifier.clearError();

      expect(statusOf(), ConnectionStatus.connected);
    });

    test('abortConnecting only reverts a connecting state', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));
      notifier.abortConnecting();

      expect(statusOf(), ConnectionStatus.connected);
    });
  });

  group('what analytics is told', () {
    test('a server picked by hand that failed is recorded with it', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(false)});
      buildContainer();

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(analytics.callsTo(#logConnectionFailed), [
        {
          #reason: UserFacingErrorKeys.proxyTestFailed,
          #selection: ConnectSelection.manual,
          #configName: 'a',
        },
      ]);
    });

    test('a quick connect that failed is recorded as auto', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(false)});
      buildContainer();

      await container.read(connectionProvider.notifier).connectAuto([
        testConfig('a'),
      ]);

      expect(analytics.callsTo(#logConnectionFailed), [
        {
          #reason: UserFacingErrorKeys.noWorkingConfig,
          #selection: ConnectSelection.auto,
          #configName: null,
        },
      ]);
    });

    // The list fetch fails before the service is reached, so a failure
    // recorded only by the service would never see it.
    test(
      'a server list that could not be fetched is a failed connect',
      () async {
        connections = FakeConnectionRepository();
        buildContainer(
          apiV2: FakeApiV2Service(
            subscriptionResult: left(const NetworkFailure()),
          ),
        );

        await container.read(connectionProvider.notifier).connectWithApiV2();

        expect(analytics.callsTo(#logConnectionFailed), [
          {
            #reason: UserFacingErrorKeys.networkError,
            #selection: ConnectSelection.auto,
            #configName: null,
          },
        ]);
      },
    );

    test('a disconnect records how long the tunnel was up', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'a': right(true)},
        tunnelStartedAtResult: DateTime.now().subtract(
          const Duration(minutes: 3),
        ),
      );
      buildContainer();
      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));

      await notifier.disconnect();

      expect(analytics.callsTo(#logUserDisconnected), [
        {#connectionDuration: inInclusiveRange(180, 182)},
      ]);
    });

    // Leaving mid-ad runs the background penalty twice, once for hidden and
    // once for paused, and both ask for a disconnect. One tunnel ended once.
    test('a tunnel asked to disconnect twice is recorded once', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();
      final notifier = container.read(connectionProvider.notifier);
      await notifier.connect(dialableConfig('a'));

      await Future.wait([notifier.disconnect(), notifier.disconnect()]);

      expect(analytics.callsTo(#logUserDisconnected), hasLength(1));
    });

    test('a disconnect with no tunnel up records nothing', () async {
      connections = FakeConnectionRepository();
      buildContainer();

      await container.read(connectionProvider.notifier).disconnect();

      expect(analytics.callsTo(#logUserDisconnected), isEmpty);
    });
  });

  // Reading the state back proves it was set; it does not prove anything was
  // told. This notifier used to need an updateShouldNotify override to be told
  // at all, because the entity compared its id and no transition changes that.
  // The entity is a value now and the override is gone, so what the listeners
  // see is worth asserting on the real notifier rather than a stand-in.
  group('what the listeners are told', () {
    test('a connect publishes both of its transitions', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});
      buildContainer();

      final seen = <ConnectionStatus>[];
      container.listen(connectionProvider, (_, next) => seen.add(next.status));

      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('a'));

      expect(seen, [ConnectionStatus.connecting, ConnectionStatus.connected]);
    });

    test(
      'a failed connect publishes the error, not just the attempt',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'a': right(false)},
        );
        buildContainer();

        final seen = <String?>[];
        container.listen(
          connectionProvider,
          (_, next) => seen.add(next.errorMessage),
        );

        await container
            .read(connectionProvider.notifier)
            .connect(dialableConfig('a'));

        expect(seen.last, isNotNull);
        expect(statusOf(), ConnectionStatus.error);
      },
    );

    test('republishing an unchanged state tells nobody', () async {
      connections = FakeConnectionRepository();
      buildContainer();

      var notifications = 0;
      container.listen(connectionProvider, (_, _) => notifications++);

      final notifier = container.read(connectionProvider.notifier)
        ..beginConnecting();
      expect(notifications, 1);

      // Already connecting. Without value equality this published a second
      // identical state and every watcher rebuilt for nothing.
      notifier.beginConnecting();

      expect(notifications, 1);
    });
  });
}
