import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../connection/connection_test_doubles.dart';
import '../../premium_test_doubles.dart';

/// Servers whose configs carry a scheme [ProxyConfigValidator] accepts.
///
/// `connectAuto` never validates, but the manual path does — and one of these
/// tests goes down it.
PremiumServer _server(String name, List<String> configNames) => PremiumServer(
  id: name.hashCode,
  name: name,
  configs: [
    for (final (index, configName) in configNames.indexed)
      PremiumServerConfig(
        id: index,
        name: configName,
        url:
            '${ProxyConfigValidator.supportedSchemes.first}$name · $configName',
      ),
  ],
);

/// Lets a listener that reacts to a status change finish its own async work.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeConnectionRepository connections;
  late FakePremiumRepository premium;

  /// The real controller graph on fakes. Nothing here builds a widget: the
  /// point of these tests is that the list's controller keeps up with the
  /// tunnel on its own, which it could not do while the listener lived in the
  /// list widget's `build`.
  ProviderContainer buildContainer(
    List<PremiumServer> servers, {
    bool goAnyway = false,
  }) {
    premium = FakePremiumRepository(serversResult: right(servers));
    final container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        premiumRepositoryProvider.overrideWithValue(premium),
        connectionServiceProvider.overrideWith(
          (ref) => testConnectionService(
            ref.watch(connectionRepositoryProvider),
            random: const NoShuffleRandom(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    answerOtherVpnWarnings(container, goAnyway: goAnyway);
    // Instantiates the notifier, which is what registers the listener.
    container.read(premiumServersProvider);
    return container;
  }

  test(
    'a quick connect the list never started still moves the badge',
    () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Beta · Main': right(true)},
      );
      final beta = _server('Beta', ['Main']);
      final container = buildContainer([
        _server('Alpha', ['Main']),
        beta,
      ]);

      await container.read(connectionProvider.notifier).connectWithPremium();
      await settle();

      final state = container.read(premiumServersProvider);
      expect(state.lastConnectedServerId, beta.id);
      expect(state.lastConnectedConfigId, beta.configs.first.id);
      expect(state.activeConfigId, beta.configs.first.id);
    },
  );

  test('a config picked by hand becomes the active one', () async {
    connections = FakeConnectionRepository(
      testVerdicts: {'Alpha · Main': right(true)},
    );
    final alpha = _server('Alpha', ['Main']);
    final container = buildContainer([alpha]);

    final notifier = container.read(premiumServersProvider.notifier);
    // Tapping a config is only reachable from a loaded list, and the server a
    // config belongs to is resolved against that list.
    await notifier.load();
    notifier.setConnectingConfig(alpha.configs.first.id);
    await container
        .read(connectionProvider.notifier)
        .connect(alpha.configs.first.toProxyConfig(countryName: alpha.name));
    await settle();

    final state = container.read(premiumServersProvider);
    expect(state.activeConfigId, alpha.configs.first.id);
    expect(state.connectingConfigId, isNull);
    expect(premium.lastConnected, (
      serverId: alpha.id,
      configId: alpha.configs.first.id,
    ), reason: 'the manual path persists through the same setActiveConfig');
  });

  test(
    'does not start real-delay pings while a connect is in flight',
    () async {
      connections = FakeConnectionRepository();
      final alpha = _server('Alpha', ['Main']);
      final container = buildContainer([alpha]);

      container.read(connectionProvider.notifier).beginConnecting();
      await container.read(premiumServersProvider.notifier).load();
      await settle();

      expect(
        premium.pingedConfigIds,
        isEmpty,
        reason:
            'throwaway Xray probes share the engine process with the live test',
      );
    },
  );

  // A delay measured through another app's tunnel is that tunnel's delay, not
  // the server's.
  group('another VPN on the device', () {
    test(
      'should turn it off before measuring a server the user opened',
      () async {
        connections = FakeConnectionRepository()..otherVpnOn = true;
        final beta = _server('Beta', ['Main']);
        final container = buildContainer([
          _server('Alpha', ['Main']),
          beta,
        ]);

        // The list opens the first server by itself; the user opens the next.
        final notifier = container.read(premiumServersProvider.notifier);
        await notifier.load();
        notifier.toggleExpanded(beta.id);
        await settle();

        expect(connections.otherVpnTurnOffs, 1);
        expect(premium.pingedConfigIds, [beta.configs.first.id]);
        expect(
          container.read(otherVpnProvider)?.verdict,
          OtherVpnVerdict.disconnected,
        );
      },
    );

    test(
      'should not measure a server the user opened while it stays on',
      () async {
        connections = FakeConnectionRepository()
          ..otherVpnOn = true
          ..otherVpnYields = false;
        final beta = _server('Beta', ['Main']);
        final container = buildContainer([
          _server('Alpha', ['Main']),
          beta,
        ]);

        final notifier = container.read(premiumServersProvider.notifier);
        await notifier.load();
        notifier.toggleExpanded(beta.id);
        await pumpEventQueue(times: turnsToGiveUpOnAVpn);

        expect(premium.pingedConfigIds, isEmpty);
        expect(
          container.read(otherVpnProvider)?.verdict,
          OtherVpnVerdict.stillOn,
        );
        expect(
          container.read(premiumServersProvider).pingByConfigId,
          isEmpty,
          reason: 'no badge is left spinning for a measurement that never ran',
        );
      },
    );

    test(
      'should measure a server the user opened once told to go on anyway',
      () async {
        connections = FakeConnectionRepository()
          ..otherVpnOn = true
          ..otherVpnYields = false;
        final beta = _server('Beta', ['Main']);
        final container = buildContainer([
          _server('Alpha', ['Main']),
          beta,
        ], goAnyway: true);

        final notifier = container.read(premiumServersProvider.notifier);
        await notifier.load();
        notifier.toggleExpanded(beta.id);
        await pumpEventQueue(times: turnsToGiveUpOnAVpn);

        expect(premium.pingedConfigIds, [beta.configs.first.id]);
      },
    );

    test(
      'should skip the measurement after loading and leave the VPN on',
      () async {
        connections = FakeConnectionRepository()..otherVpnOn = true;
        // The list opens the first server by itself, and measures it.
        final container = buildContainer([
          _server('Alpha', ['Main']),
        ]);

        await container.read(premiumServersProvider.notifier).load();
        await settle();

        expect(premium.pingedConfigIds, isEmpty);
        expect(
          connections.otherVpnTurnOffs,
          0,
          reason: 'opening the tab is not asking for the other VPN to go',
        );
        expect(container.read(otherVpnProvider), isNull);
      },
    );
  });

  // The home row names the connected server from this label when the list
  // fetched on a relaunch no longer carries it.
  group('the connected server\'s label', () {
    test('should be stored and published by a quick connect', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Beta · Main': right(true)},
      );
      final beta = _server('Beta', ['Main']);
      final container = buildContainer([beta]);

      await container.read(connectionProvider.notifier).connectWithPremium();
      await settle();

      const expected = PremiumServerLabel(
        serverName: 'Beta',
        configName: 'Main',
        flagCode: null,
      );
      expect(premium.lastConnectedLabel, expected);
      expect(container.read(premiumServersProvider).activeLabel, expected);
    });

    test('should be read back when a relaunch adopts a live tunnel', () async {
      connections = FakeConnectionRepository()..connectionActive = true;
      final container = buildContainer(const []);
      const stored = PremiumServerLabel(
        serverName: 'Gone',
        configName: 'Main',
        flagCode: 'se',
      );
      premium
        ..lastConnected = (serverId: 3, configId: 9)
        ..lastConnectedLabel = stored;

      await container.read(connectionProvider.notifier).reconcileWithNative();
      await settle();

      final state = container.read(premiumServersProvider);
      expect(state.activeConfigId, 9);
      expect(state.activeLabel, stored);
    });

    test('should be dropped once the tunnel is down', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Beta · Main': right(true)},
      );
      final container = buildContainer([
        _server('Beta', ['Main']),
      ]);

      await container.read(connectionProvider.notifier).connectWithPremium();
      await settle();
      await container.read(connectionProvider.notifier).disconnect();
      await settle();

      expect(container.read(premiumServersProvider).activeLabel, isNull);
    });
  });

  test('disconnecting clears what is active but not what was last', () async {
    connections = FakeConnectionRepository(
      testVerdicts: {'Beta · Main': right(true)},
    );
    final beta = _server('Beta', ['Main']);
    final container = buildContainer([beta]);

    await container.read(connectionProvider.notifier).connectWithPremium();
    await settle();
    await container.read(connectionProvider.notifier).disconnect();
    await settle();

    final state = container.read(premiumServersProvider);
    expect(state.activeConfigId, isNull);
    expect(
      state.lastConnectedConfigId,
      beta.configs.first.id,
      reason: 'the badge outlives the connection it came from',
    );
  });
}
