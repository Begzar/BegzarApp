import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_listing.dart';
import 'package:flutter_test/flutter_test.dart';

PremiumServer _server(int id, List<int> configIds) => PremiumServer(
  id: id,
  name: 'Server $id',
  configs: [
    for (final configId in configIds)
      PremiumServerConfig(id: configId, name: 'Config $configId', url: ''),
  ],
);

void main() {
  group('resolving the stored last-connected pair', () {
    test('keeps both ids when the server and its config are still offered', () {
      final listing = PremiumServerListing.resolve(
        servers: [
          _server(1, [10, 11]),
          _server(2, [20]),
        ],
        lastConnected: (serverId: 2, configId: 20),
      );

      expect(listing.lastConnectedServerId, 2);
      expect(listing.lastConnectedConfigId, 20);
      expect(listing.expandedServerId, 2);
    });

    test(
      'drops the config id when its server kept it but the config is gone',
      () {
        final listing = PremiumServerListing.resolve(
          servers: [
            _server(1, [10]),
            _server(2, [21]),
          ],
          lastConnected: (serverId: 2, configId: 20),
        );

        expect(listing.lastConnectedServerId, 2);
        expect(
          listing.lastConnectedConfigId,
          isNull,
          reason: 'there is no row left for it to mark',
        );
        expect(listing.expandedServerId, 2);
      },
    );

    test('drops both when the server is no longer offered', () {
      final listing = PremiumServerListing.resolve(
        servers: [
          _server(1, [10]),
        ],
        lastConnected: (serverId: 2, configId: 20),
      );

      expect(listing.lastConnectedServerId, isNull);
      expect(listing.lastConnectedConfigId, isNull);
      expect(
        listing.expandedServerId,
        1,
        reason: 'the list should not open with every card collapsed',
      );
    });

    test('opens the first server when nothing was ever connected', () {
      final listing = PremiumServerListing.resolve(
        servers: [
          _server(7, [70]),
          _server(8, [80]),
        ],
        lastConnected: null,
      );

      expect(listing.expandedServerId, 7);
      expect(listing.lastConnectedServerId, isNull);
    });

    test('an empty list expands nothing', () {
      final listing = PremiumServerListing.resolve(
        servers: const [],
        lastConnected: (serverId: 2, configId: 20),
      );

      expect(listing.servers, isEmpty);
      expect(listing.expandedServerId, isNull);
    });
  });
}
