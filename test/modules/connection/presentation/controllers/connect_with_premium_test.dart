import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:begzar/modules/premium/di/premium_providers.dart';

import '../../connection_test_doubles.dart';
import '../../../premium/premium_test_doubles.dart';

PremiumServer _server(String name, List<String> configNames) {
  return PremiumServer(
    id: name.hashCode,
    name: name,
    configs: [
      for (final (index, configName) in configNames.indexed)
        PremiumServerConfig(
          id: index,
          name: configName,
          url: '$kTestConfigScheme://$name · $configName',
        ),
    ],
  );
}

void main() {
  late FakeConnectionRepository connections;
  late FakePremiumRepository premium;

  ProviderContainer buildContainer(
    Either<ApiFailure, List<PremiumServer>> serversResult,
  ) {
    premium = FakePremiumRepository(serversResult: serversResult);
    final container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        premiumRepositoryProvider.overrideWithValue(premium),
        // Quick connect shuffles its candidates, so which configs get tried
        // before one passes is otherwise random. These tests are about the
        // flattening of servers into candidates, not the ordering, so the
        // shuffle is pinned to leave the flattened order alone.
        connectionServiceProvider.overrideWith(
          (ref) => testConnectionService(
            ref.watch(connectionRepositoryProvider),
            random: const NoShuffleRandom(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('connectWithPremium', () {
    test(
      'flattens every server list entry and connects to a working config',
      () async {
        connections = FakeConnectionRepository(
          testVerdicts: {'Beta · Main': right(true)},
        );
        final container = buildContainer(
          right([
            _server('Alpha', ['Main']),
            _server('Beta', ['Main']),
          ]),
        );

        await container.read(connectionProvider.notifier).connectWithPremium();

        final state = container.read(connectionProvider);
        expect(state.status, ConnectionStatus.connected);
        expect(connections.testedConfigNames, contains('Alpha · Main'));
        expect(connections.testedConfigNames, contains('Beta · Main'));
      },
    );

    test(
      'surfaces the API failure key when the server list cannot load',
      () async {
        connections = FakeConnectionRepository();
        final container = buildContainer(
          left(const ServerFailure('Unauthorized', statusCode: 401)),
        );

        await container.read(connectionProvider.notifier).connectWithPremium();

        final state = container.read(connectionProvider);
        expect(state.status, ConnectionStatus.error);
        expect(UserFacingErrorKeys.all, contains(state.errorMessage));
        expect(connections.testedConfigNames, isEmpty);
      },
    );

    test('records the server and config it landed on', () async {
      // Nothing selected this config by hand, so the list has no
      // `connectingConfigId` to go on. Quick connect resolving the pair itself
      // is what gives the last-connected badge something to point at.
      connections = FakeConnectionRepository(
        testVerdicts: {'Beta · Main': right(true)},
      );
      final beta = _server('Beta', ['Main']);
      final container = buildContainer(
        right([
          _server('Alpha', ['Main']),
          beta,
        ]),
      );

      await container.read(connectionProvider.notifier).connectWithPremium();

      expect(
        container.read(connectionProvider).status,
        ConnectionStatus.connected,
      );
      expect(premium.lastConnected, (
        serverId: beta.id,
        configId: beta.configs.first.id,
      ));
    });

    test('records nothing when no config dials', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'Alpha · Main': right(false)},
      );
      final container = buildContainer(
        right([
          _server('Alpha', ['Main']),
        ]),
      );

      await container.read(connectionProvider.notifier).connectWithPremium();

      expect(container.read(connectionProvider).status, ConnectionStatus.error);
      expect(premium.lastConnected, isNull);
    });

    test('reports no configs when the account has no servers', () async {
      connections = FakeConnectionRepository();
      final container = buildContainer(right(const []));

      await container.read(connectionProvider.notifier).connectWithPremium();

      final state = container.read(connectionProvider);
      expect(state.status, ConnectionStatus.error);
      expect(state.errorMessage, UserFacingErrorKeys.noConfigsFromServer);
    });
  });
}
