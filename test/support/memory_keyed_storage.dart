import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';

/// An [AppKeyedStorage] backed by a map, so a test can seed what a previous
/// launch would have written and read back what this one wrote.
///
/// The real implementation talks to the platform keystore, which is
/// unavailable under `flutter test`.
class MemoryKeyedStorage implements AppKeyedStorage {
  MemoryKeyedStorage([Map<String, String>? seed]) {
    if (seed != null) values.addAll(seed);
  }

  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

/// The install id a seeded store answers with.
///
/// A stubbed account roster has to list it: the repository ends a
/// session whose roster no longer registers this device, and a store left to
/// mint its own id would give the stub nothing to name.
const testDeviceId = 'test-device';

/// The key [DeviceIdentity] stores the install id under. Named here so a test
/// can seed one; its own copy is private.
const _deviceIdKey = 'premium_device_id';

/// A [MemoryKeyedStorage] that already holds [testDeviceId], the way an
/// install that has run before does.
MemoryKeyedStorage storageWithDeviceId([Map<String, String>? seed]) =>
    MemoryKeyedStorage({_deviceIdKey: testDeviceId, ...?seed});

/// A [MemoryKeyedStorage] that fails every call, standing in for a keychain
/// the platform has locked or revoked.
class FailingKeyedStorage implements AppKeyedStorage {
  const FailingKeyedStorage();

  @override
  Future<String?> read({required String key}) async => throw _StorageDown();

  @override
  Future<void> write({required String key, required String? value}) async =>
      throw _StorageDown();

  @override
  Future<void> delete({required String key}) async => throw _StorageDown();
}

/// A [MemoryKeyedStorage] that answers reads but fails every write, standing
/// in for a keychain that has gone read-only partway through a launch.
class WriteFailingKeyedStorage extends MemoryKeyedStorage {
  WriteFailingKeyedStorage([super.seed]);

  @override
  Future<void> write({required String key, required String? value}) async =>
      throw _StorageDown();
}

class _StorageDown implements Exception {
  @override
  String toString() => 'storage unavailable';
}
