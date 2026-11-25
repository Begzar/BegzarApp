import 'dart:convert';

import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';

void main() {
  test(
    'readSession rewrites stored JSON that still contains legacy fields',
    () async {
      final store = MemoryKeyedStorage();
      store.values['premium_session_v1'] = jsonEncode({
        'access_key': 'key',
        'username': 'user',
        'expire_date': '2099-01-01',
        'password': 'legacy-password',
        'config_source': 'free',
      });

      final session = await PremiumStorage(storage: store).readSession();

      expect(session?.account.username, 'user');
      final rewritten =
          jsonDecode(store.values['premium_session_v1']!)
              as Map<String, dynamic>;
      expect(rewritten, isNot(contains('password')));
      expect(rewritten, isNot(contains('config_source')));
    },
  );

  group('PremiumStorage last connected label', () {
    test('should read back the label saved with the ids', () async {
      final storage = PremiumStorage(storage: MemoryKeyedStorage());
      const label = PremiumServerLabel(
        serverName: 'Sweden',
        configName: 'SE-01',
        flagCode: 'se',
      );

      await storage.saveLastConnected(serverId: 7, configId: 41, label: label);

      expect(await storage.readLastConnectedLabel(), label);
      expect(await storage.readLastConnected(), (serverId: 7, configId: 41));
    });

    test('should keep a label that has no flag', () async {
      final storage = PremiumStorage(storage: MemoryKeyedStorage());
      const label = PremiumServerLabel(
        serverName: 'Sweden',
        configName: 'Main',
      );

      await storage.saveLastConnected(serverId: 7, configId: 41, label: label);

      expect(await storage.readLastConnectedLabel(), label);
    });

    // Builds before the label was stored left the ids alone on disk.
    test('should read no label when none was ever stored', () async {
      final store = MemoryKeyedStorage();
      store.values['premium_last_connected_server_id'] = '7';
      store.values['premium_last_connected_config_id'] = '41';

      final storage = PremiumStorage(storage: store);

      expect(await storage.readLastConnectedLabel(), isNull);
      expect(await storage.readLastConnected(), (serverId: 7, configId: 41));
    });

    test('should read no label from a stored value it cannot parse', () async {
      final store = MemoryKeyedStorage();
      store.values['premium_last_connected_label'] = 'not json';

      expect(
        await PremiumStorage(storage: store).readLastConnectedLabel(),
        isNull,
      );
    });
  });
}
