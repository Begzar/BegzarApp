import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';

/// Premium's storage for a fake-backend run, kept in memory.
///
/// A session the fake backend issues means nothing to the real server, so it
/// never reaches the device's keystore: switching back to
/// `lib/main.dart` finds the real stored session, or none, exactly as it was.
class FakeRunStorage implements AppKeyedStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
