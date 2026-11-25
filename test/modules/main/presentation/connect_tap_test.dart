import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:begzar/core/providers/api_provider.dart';
import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/main/presentation/controllers/main_screen_controller.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../connection/connection_test_doubles.dart';
import '../../premium/premium_test_doubles.dart';
import '../../../support/memory_keyed_storage.dart';
import '../../../support/recording_analytics.dart';

/// A session whose subscription and account status the test picks.
PremiumSession _session({required bool entitled, String? statusLabel}) {
  final expiry = entitled
      ? DateTime.now().add(const Duration(days: 30))
      : DateTime.now().subtract(const Duration(days: 1));

  return PremiumSession(
    accessKey: 'test-key',
    account: PremiumAccount(
      username: 'tester',
      expireDate: expiry.toIso8601String(),
      statusLabel: statusLabel,
    ),
  );
}

PremiumServer _server() => const PremiumServer(
  id: 1,
  name: 'Alpha',
  configs: [
    PremiumServerConfig(
      id: 1,
      name: 'Main',
      url: '$kTestConfigScheme://Alpha · Main',
    ),
  ],
);

/// Event-loop turns [settlePremium] gives the restore before calling it stuck.
///
/// The restore is a chain of microtasks against fakes, so one turn is enough
/// and has been every time it has been measured. The margin is for a graph
/// that grows an await, not for a slow machine — turns are counted, not timed.
const int _settleTurns = 20;

void main() {
  late FakeConnectionRepository connections;
  late FakePremiumRepository premium;
  late FakeApiV2Service apiV2;
  late ProviderContainer container;

  // `ReleaseHintBus.latest` is a process-wide static that any 200 from the
  // Begzar API publishes into, and the connect path reads it as the version to
  // enforce. Nothing here writes it now that the free tier is faked, but a
  // test that inherited a version from an earlier one would fail several lines
  // away from the cause — which is exactly how this file used to flake.
  setUp(() {
    ReleaseHintBus.latest = null;
  });

  /// Wires the real controller graph to fakes on both sides, so a tap runs
  /// the same sequence the button does.
  ///
  /// The free tier is faked as well as the premium one. It is not what most of
  /// these tests are about, but the real `ApiV2Service` calls the production
  /// API for real, and one test does reach it.
  ///
  /// [settings] seeds the settings store, which is otherwise left to the
  /// platform and reads as the defaults. [experimentalSupported] pins whether
  /// the WARP engine exists, which a test would otherwise inherit from the
  /// machine the suite runs on.
  void buildContainer({
    PremiumSession? session,
    bool goAnyway = false,
    Map<String, String>? settings,
    bool experimentalSupported = false,
    AnalyticsService? analytics,
  }) {
    premium = FakePremiumRepository(
      session: session,
      serversResult: right([_server()]),
    );
    apiV2 = FakeApiV2Service();

    container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        premiumRepositoryProvider.overrideWithValue(premium),
        apiV2ServiceProvider.overrideWithValue(apiV2),
        connectionServiceProvider.overrideWith(
          (ref) => testConnectionService(
            ref.watch(connectionRepositoryProvider),
            random: const NoShuffleRandom(),
            analytics: analytics,
          ),
        ),
        experimentalSupportedProvider.overrideWithValue(experimentalSupported),
        if (settings != null)
          flutterSecureStorageProvider.overrideWithValue(
            MemoryKeyedStorage(settings),
          ),
      ],
    );
    addTearDown(container.dispose);
    answerOtherVpnWarnings(container, goAnyway: goAnyway);
  }

  Future<ConnectTapOutcome> tap() =>
      container.read(mainScreenProvider).toggleConnection();

  /// Lets the premium notifier finish restoring the stored session, which the
  /// gate reads before it decides anything.
  ///
  /// Reaching the bound fails here rather than carrying on. Every assertion
  /// below depends on the restore having landed, and a gate that reads an
  /// unrestored account takes the free path instead — which reports the same
  /// problem several lines later as whatever the free path happened to do.
  Future<void> settlePremium() async {
    for (var turn = 0; turn < _settleTurns; turn++) {
      if (container.read(premiumProvider) is! PremiumRestoring) return;
      await Future<void>.delayed(Duration.zero);
    }

    fail('the premium session was still restoring after $_settleTurns turns');
  }

  /// Takes the connection to disconnecting and leaves it there, by dropping a
  /// tunnel adopted from native while [FakeConnectionRepository.holdDisconnect]
  /// holds the teardown. Completing the hold lets the disconnect finish.
  Future<void> holdMidDisconnect() async {
    connections.connectionActive = true;
    await container.read(connectionProvider.notifier).reconcileWithNative();
    connections.holdDisconnect = Completer<void>();
    unawaited(container.read(connectionProvider.notifier).disconnect());
    await pumpEventQueue();
  }

  group('a tap that cannot connect', () {
    test('is ignored while a disconnect is in flight', () async {
      connections = FakeConnectionRepository();
      buildContainer();
      await holdMidDisconnect();

      expect(await tap(), ConnectTapOutcome.ignored);

      connections.holdDisconnect!.complete();
    });

    test('clears a sticky error rather than retrying into it', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Alpha · Main': right(false)},
      );
      buildContainer();
      await container
          .read(connectionProvider.notifier)
          .connect(dialableConfig('Alpha · Main'));
      expect(container.read(connectionProvider).status, ConnectionStatus.error);

      expect(await tap(), ConnectTapOutcome.errorCleared);
      expect(container.read(connectionProvider).status, ConnectionStatus.ready);
    });

    // The dialog blocks every path, so the gate refuses before it touches the
    // connection at all.
    test('is refused outright when an update is forced', () async {
      connections = FakeConnectionRepository();
      buildContainer();
      container
          .read(forceUpdateProvider.notifier)
          .markRequired(currentVersion: '1.0.0', requiredVersion: '2.0.0');

      expect(await tap(), ConnectTapOutcome.updateRequired);
      expect(container.read(connectionProvider).status, ConnectionStatus.ready);
      expect(connections.testedConfigNames, isEmpty);
    });
  });

  // Offered by the connection card for a tunnel that stopped carrying traffic.
  group('MainScreenController.switchServer', () {
    test(
      'should drop the tunnel and quick-connect a free user again',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {kFreeTierConfigName: right(true)},
        );
        buildContainer();
        await settlePremium();
        await tap();
        final disconnectsBefore = connections.disconnectCount;

        final outcome = await container.read(mainScreenProvider).switchServer();

        expect(outcome, ConnectTapOutcome.connecting);
        expect(connections.disconnectCount, greaterThan(disconnectsBefore));
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.connected,
        );
      },
    );

    test(
      'should quick-connect a premium user through the premium path',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'Alpha · Main': right(true)},
        );
        buildContainer(session: _session(entitled: true));
        await settlePremium();
        await tap();
        connections.testedConfigNames.clear();

        final outcome = await container.read(mainScreenProvider).switchServer();

        expect(outcome, ConnectTapOutcome.connecting);
        expect(connections.testedConfigNames, contains('Alpha · Main'));
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.connected,
        );
      },
    );

    test('should do nothing while no tunnel is up', () async {
      connections = FakeConnectionRepository();
      buildContainer();
      await settlePremium();

      final outcome = await container.read(mainScreenProvider).switchServer();

      expect(outcome, ConnectTapOutcome.ignored);
      expect(connections.disconnectCount, 0);
    });
  });

  group('the premium gate', () {
    // A subscription already known to have lapsed is not entitled, so there
    // is nothing to re-check: the tap takes the free path rather than being
    // refused. A lapsed premium user still gets the free service.
    test(
      'a subscription already known to be lapsed takes the free path',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {kFreeTierConfigName: right(true)},
        );
        buildContainer(session: _session(entitled: false));
        await settlePremium();

        expect(container.read(premiumProvider).isEntitled, isFalse);
        expect(await tap(), ConnectTapOutcome.connecting);
        expect(
          connections.connectedConfigNames,
          [kFreeTierConfigName],
          reason:
              'the free service is what a lapsed account still gets, so it '
              'dials what the free tier hands back and not the premium list',
        );
        expect(
          apiV2.fetchCount,
          1,
          reason: 'taking the free path means asking the free tier for configs',
        );
      },
    );

    // The refusals are reachable only when the stored account looks entitled
    // and the server disagrees on the way in — which is the whole point of
    // re-checking rather than trusting what is on disk.
    test('the server disabling the account refuses the connect', () async {
      connections = FakeConnectionRepository();
      buildContainer(session: _session(entitled: true));
      await settlePremium();
      expect(container.read(premiumProvider).isEntitled, isTrue);

      // The server changes its mind between sign-in and this connect.
      premium.refreshResult = right(
        PremiumAccount(
          username: 'tester',
          expireDate: DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          statusLabel: 'disabled',
        ),
      );

      expect(await tap(), ConnectTapOutcome.accountInactive);
      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.ready,
        reason: 'a refused gate takes the connection back out of connecting',
      );
      expect(connections.testedConfigNames, isEmpty);
    });

    test('the server expiring the subscription refuses the connect', () async {
      connections = FakeConnectionRepository();
      buildContainer(session: _session(entitled: true));
      await settlePremium();

      premium.refreshResult = right(
        PremiumAccount(
          username: 'tester',
          expireDate: DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        ),
      );

      expect(await tap(), ConnectTapOutcome.subscriptionExpired);
      expect(connections.testedConfigNames, isEmpty);
    });

    test('an entitled account connects through the premium path', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Alpha · Main': right(true)},
      );
      buildContainer(session: _session(entitled: true));
      await settlePremium();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.connected,
      );
      expect(connections.testedConfigNames, contains('Alpha · Main'));
    });
  });

  // The dial is the one control a person has while a connect runs, so a tap on
  // it mid-connect is the way out of a connect that is taking too long.
  group('a tap while connecting', () {
    test('should call the connect off', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {kFreeTierConfigName: right(true)},
      )..holdProbe = Completer<void>();
      buildContainer();

      final first = tap();
      await pumpEventQueue();

      expect(await tap(), ConnectTapOutcome.cancelled);
      expect(container.read(connectionProvider).status, ConnectionStatus.ready);

      connections.holdProbe!.complete();
      await first;

      expect(connections.connectedConfigNames, isEmpty);
      expect(container.read(connectionProvider).status, ConnectionStatus.ready);
    });

    test(
      'should call off a connect still waiting on the entitlement check',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'Alpha · Main': right(true)},
        );
        buildContainer(session: _session(entitled: true));
        await settlePremium();
        final check = Completer<void>();
        premium.refreshGates.add(check);

        final first = tap();
        await pumpEventQueue();
        expect(await tap(), ConnectTapOutcome.cancelled);

        check.complete();

        expect(
          await first,
          ConnectTapOutcome.cancelled,
          reason:
              'the server saying yes after the user said stop is not a '
              'reason to dial',
        );
        expect(connections.testedConfigNames, isEmpty);
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.ready,
        );
      },
    );

    test(
      "should keep a cancelled check's refusal off the connect asked for after it",
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'Alpha · Main': right(true)},
        );
        buildContainer(session: _session(entitled: true));
        await settlePremium();
        final cancelledCheck = Completer<void>();
        final nextCheck = Completer<void>();
        premium.refreshGates.addAll([cancelledCheck, nextCheck]);

        // Each gate answers with what the server said when it was asked.
        premium.refreshResult = right(
          PremiumAccount(
            username: 'tester',
            expireDate: DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            statusLabel: 'disabled',
          ),
        );
        final first = tap();
        await pumpEventQueue();
        await tap();

        premium.refreshResult = null;
        final next = tap();
        await pumpEventQueue();

        cancelledCheck.complete();
        expect(await first, ConnectTapOutcome.cancelled);
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.connecting,
          reason:
              'taking the connection out of connecting for a refusal '
              'nobody is waiting on would cancel the connect that is',
        );

        nextCheck.complete();
        expect(await next, ConnectTapOutcome.connecting);
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.connected,
        );
      },
    );
  });

  // Quick connect measures every server before it dials, and a measurement
  // sent through someone else's tunnel measures the wrong thing.
  group('another VPN on the device', () {
    test('should turn it off and go on to connect', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {kFreeTierConfigName: right(true)},
      )..otherVpnOn = true;
      buildContainer();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(connections.otherVpnTurnOffs, 1);
      expect(connections.connectedConfigNames, [kFreeTierConfigName]);
      expect(
        container.read(otherVpnProvider)?.verdict,
        OtherVpnVerdict.disconnected,
        reason: 'the user is told what happened to their other VPN',
      );
    });

    test('should refuse the connect while it stays on', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer();

      expect(await tap(), ConnectTapOutcome.otherVpnOn);
      expect(apiV2.fetchCount, 0);
      expect(connections.probeStopAfters, isEmpty);
      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.ready,
        reason: 'the attempt reads as connecting while it runs, and no longer',
      );
    });

    test('should connect with it on when the user goes on anyway', () async {
      connections =
          FakeConnectionRepository(
              testVerdicts: {kFreeTierConfigName: right(true)},
            )
            ..otherVpnOn = true
            ..otherVpnYields = false;
      buildContainer(goAnyway: true);

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(connections.connectedConfigNames, [kFreeTierConfigName]);
    });

    test(
      'should still check the subscription when the user goes on anyway',
      () async {
        connections = FakeConnectionRepository()
          ..otherVpnOn = true
          ..otherVpnYields = false;
        buildContainer(session: _session(entitled: true), goAnyway: true);
        await settlePremium();
        final asked = premium.refreshAccountCount;

        await tap();
        expect(premium.refreshAccountCount, greaterThan(asked));
      },
    );

    test(
      'should refuse before asking the server about the subscription',
      () async {
        connections = FakeConnectionRepository()
          ..otherVpnOn = true
          ..otherVpnYields = false;
        buildContainer(session: _session(entitled: true));
        await settlePremium();
        final asked = premium.refreshAccountCount;

        expect(await tap(), ConnectTapOutcome.otherVpnOn);
        expect(premium.refreshAccountCount, asked);
      },
    );

    test('should refuse a config picked from the list the same way', () async {
      connections =
          FakeConnectionRepository(testVerdicts: {'Alpha · Main': right(true)})
            ..otherVpnOn = true
            ..otherVpnYields = false;
      buildContainer();

      expect(
        await container
            .read(mainScreenProvider)
            .connectToConfig(dialableConfig('Alpha · Main')),
        ConnectTapOutcome.otherVpnOn,
      );
      expect(connections.connectedConfigNames, isEmpty);
    });

    test(
      'should stop when the dial is tapped while it is being turned off',
      () async {
        connections =
            FakeConnectionRepository(
                testVerdicts: {kFreeTierConfigName: right(true)},
              )
              ..otherVpnOn = true
              ..holdOtherVpnTurnOff = Completer<void>();
        buildContainer();

        final first = tap();
        await pumpEventQueue();
        expect(await tap(), ConnectTapOutcome.cancelled);

        connections.holdOtherVpnTurnOff!.complete();

        expect(
          await first,
          ConnectTapOutcome.cancelled,
          reason:
              'the other VPN going is no reason to carry on with a '
              'connect the user called off',
        );
        expect(apiV2.fetchCount, 0);
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.ready,
        );
      },
    );
  });

  // Experimental settings send a free connect to the WARP engine. Only a free
  // one, and only where the engine is built in.
  group('Experimental settings', () {
    const on = {
      'settings_experimental': 'true',
      'settings_warp_mode': 'masque-psiphon',
    };

    test('a free user connects on WARP in the stored mode', () async {
      final analytics = RecordingAnalytics();
      connections = FakeConnectionRepository();
      buildContainer(
        settings: on,
        experimentalSupported: true,
        analytics: analytics,
      );
      await settlePremium();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.connected,
      );
      expect(connections.warpModes, [WarpMode.masquePsiphon]);
      expect(
        apiV2.fetchCount,
        0,
        reason: 'a WARP connect has no server list to ask for',
      );
      expect(connections.connectedConfigNames, isEmpty);
      expect(analytics.callsTo(#logUserConnected), [
        {#configName: 'warp:masque_psiphon', #connectionMode: 'vpn'},
      ]);
    });

    test('a subscriber is never moved off the premium path', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Alpha · Main': right(true)},
      );
      buildContainer(
        session: _session(entitled: true),
        settings: on,
        experimentalSupported: true,
      );
      await settlePremium();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(connections.warpModes, isEmpty);
      expect(connections.testedConfigNames, contains('Alpha · Main'));
    });

    test('a platform without the engine keeps the free server list', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {kFreeTierConfigName: right(true)},
      );
      buildContainer(settings: on);
      await settlePremium();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(connections.warpModes, isEmpty);
      expect(connections.connectedConfigNames, [kFreeTierConfigName]);
    });

    test('switched off, a free user keeps the free server list', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {kFreeTierConfigName: right(true)},
      );
      buildContainer(
        settings: const {'settings_experimental': 'false'},
        experimentalSupported: true,
      );
      await settlePremium();

      expect(await tap(), ConnectTapOutcome.connecting);
      expect(connections.warpModes, isEmpty);
      expect(connections.connectedConfigNames, [kFreeTierConfigName]);
    });

    test('a WARP engine that will not start fails the connect', () async {
      final analytics = RecordingAnalytics();
      connections = FakeConnectionRepository()
        ..warpResult = left(const ProxyTestFailure());
      buildContainer(
        settings: on,
        experimentalSupported: true,
        analytics: analytics,
      );
      await settlePremium();

      await tap();
      final state = container.read(connectionProvider);
      expect(state.status, ConnectionStatus.error);
      expect(state.errorMessage, const ProxyTestFailure().userFacingKey);
      expect(analytics.callsTo(#logUserConnected), isEmpty);
      expect(analytics.callsTo(#logConnectionFailed), [
        {
          #reason: const ProxyTestFailure().userFacingKey,
          #selection: ConnectSelection.auto,
          #configName: null,
        },
      ]);
    });
  });

  test('a tap while connected disconnects', () async {
    // Adopted from the native tunnel rather than dialled here: this test is
    // about what the tap does once connected, not about connecting.
    connections = FakeConnectionRepository(connectionActive: true);
    buildContainer();
    await container.read(connectionProvider.notifier).reconcileWithNative();
    expect(
      container.read(connectionProvider).status,
      ConnectionStatus.connected,
    );

    expect(await tap(), ConnectTapOutcome.disconnecting);
    expect(container.read(connectionProvider).status, ConnectionStatus.ready);
    expect(connections.disconnectCount, 1);
  });

  // The premium list picks the config itself, so it has its own entry point —
  // but it is refused by the same gate, and these mirror the tap tests above
  // on purpose: the two paths agreeing is the whole point of sharing it.
  group('connecting to a named config', () {
    Future<ConnectTapOutcome> pick(String name) => container
        .read(mainScreenProvider)
        .connectToConfig(dialableConfig(name));

    test('is ignored while a connect is already in flight', () async {
      connections = FakeConnectionRepository();
      buildContainer();
      container.read(connectionProvider.notifier).beginConnecting();

      expect(await pick('Alpha · Main'), ConnectTapOutcome.ignored);
      expect(connections.connectedConfigNames, isEmpty);
    });

    test('is refused outright when an update is forced', () async {
      connections = FakeConnectionRepository();
      buildContainer();
      container
          .read(forceUpdateProvider.notifier)
          .markRequired(currentVersion: '1.0.0', requiredVersion: '2.0.0');

      expect(await pick('Alpha · Main'), ConnectTapOutcome.updateRequired);
      expect(connections.connectedConfigNames, isEmpty);
    });

    test('the server disabling the account refuses the connect', () async {
      connections = FakeConnectionRepository();
      buildContainer(session: _session(entitled: true));
      await settlePremium();

      premium.refreshResult = right(
        PremiumAccount(
          username: 'tester',
          expireDate: DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          statusLabel: 'disabled',
        ),
      );

      expect(await pick('Alpha · Main'), ConnectTapOutcome.accountInactive);
      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.ready,
        reason: 'a refused gate takes the connection back out of connecting',
      );
      expect(connections.connectedConfigNames, isEmpty);
    });

    test(
      'dials the config it was handed, not one of its own choosing',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'Alpha · Main': right(true)},
        );
        buildContainer(session: _session(entitled: true));
        await settlePremium();

        expect(await pick('Alpha · Main'), ConnectTapOutcome.connecting);
        expect(
          container.read(connectionProvider).status,
          ConnectionStatus.connected,
        );
        expect(connections.connectedConfigNames, ['Alpha · Main']);
      },
    );
  });

  // An entitled session the server then refuses to answer for is the only way
  // to reach [ConnectTapOutcome.checkFailed] through the gate. The error toast
  // explains it, so all the gate owes is the outcome.
  test('a server that cannot be reached refuses the connect', () async {
    connections = FakeConnectionRepository(
      testVerdicts: {'Alpha · Main': right(true)},
    );
    buildContainer(session: _session(entitled: true));
    await settlePremium();

    premium.refreshResult = left(const NetworkFailure('offline'));

    expect(await tap(), ConnectTapOutcome.checkFailed);
    expect(
      container.read(connectionProvider).status,
      ConnectionStatus.ready,
      reason: 'a refused gate takes the connection back out of connecting',
    );
    expect(connections.testedConfigNames, isEmpty);
  });

  test('only a refusal has something to explain', () {
    expect(ConnectTapOutcome.updateRequired.needsExplaining, isTrue);
    expect(ConnectTapOutcome.notEntitled.needsExplaining, isTrue);
    expect(ConnectTapOutcome.subscriptionExpired.needsExplaining, isTrue);
    expect(ConnectTapOutcome.accountInactive.needsExplaining, isTrue);
    expect(
      ConnectTapOutcome.checkFailed.needsExplaining,
      isTrue,
      reason:
          'a refused gate leaves the connection on ready, so nothing '
          'surfaces the reason unless this outcome is explained',
    );

    expect(ConnectTapOutcome.connecting.needsExplaining, isFalse);
    expect(ConnectTapOutcome.disconnecting.needsExplaining, isFalse);
    expect(ConnectTapOutcome.errorCleared.needsExplaining, isFalse);
    expect(ConnectTapOutcome.ignored.needsExplaining, isFalse);
    expect(
      ConnectTapOutcome.cancelled.needsExplaining,
      isFalse,
      reason: 'the dial going back to ready is the whole answer to a cancel',
    );
    expect(
      ConnectTapOutcome.otherVpnOn.needsExplaining,
      isFalse,
      reason:
          'the other-VPN warning is raised by its own listener, which the '
          "server list's measurement shares",
    );
  });
}
