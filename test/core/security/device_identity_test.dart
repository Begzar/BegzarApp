import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';

void main() {
  test('mints an id the first time and keeps it afterwards', () async {
    final store = MemoryKeyedStorage();
    final identity = DeviceIdentity(storage: store);

    final first = await identity.getOrCreate();
    final second = await identity.getOrCreate();

    expect(first, isNotEmpty);
    expect(
      second,
      first,
      reason: 'a device that re-registers under a new id loses its binding',
    );
  });

  test('a blank stored value is not an id', () async {
    final store = MemoryKeyedStorage();
    store.values['premium_device_id'] = '';

    final id = await DeviceIdentity(storage: store).getOrCreate();

    expect(id, isNotEmpty);
  });

  test('reads the id installs already carry', () async {
    final store = MemoryKeyedStorage();
    store.values['premium_device_id'] = 'an-existing-install';

    final id = await DeviceIdentity(storage: store).getOrCreate();

    expect(
      id,
      'an-existing-install',
      reason: 'the key predates this class and addresses a real stored id — '
          'changing it re-registers every install that upgrades',
    );
  });

  test('premium reads the same id core signs with', () async {
    final store = MemoryKeyedStorage();

    final signing = await DeviceIdentity(storage: store).getOrCreate();
    final asPremiumSeesIt = await PremiumStorage(
      storage: store,
    ).getOrCreateDeviceId();

    expect(
      asPremiumSeesIt,
      signing,
      reason: 'the signed request and the registered device must agree on '
          'which device this is',
    );
  });
}
