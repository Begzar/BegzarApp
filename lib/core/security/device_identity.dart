import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// The stable id this install signs its requests with.
///
/// Every signed request carries it, free tier included, so it identifies the
/// install rather than any account — it exists before anyone signs in and
/// survives signing out. It lives on the floor for that reason: request
/// signing is core's, and having the premium module own the id meant core
/// reaching up into a feature to sign an anonymous request.
class DeviceIdentity {
  DeviceIdentity({AppKeyedStorage? storage})
    : _storage = storage ?? AppSecureStorage.instance;

  /// Historical key name, from when the premium module owned this. It is the
  /// address of an id already written on every install: renaming it would
  /// mint a new one for everybody and unbind every registered device.
  static const _deviceIdKey = 'premium_device_id';

  final AppKeyedStorage _storage;

  /// This install's id, minting one the first time it is asked for.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    const uuid = Uuid();
    final deviceId = uuid.v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }
}
