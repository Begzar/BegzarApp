import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Key/value storage used by the app (Keychain on mobile, file on macOS).
abstract class AppKeyedStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});
}

/// Shared app storage.
///
/// On macOS we intentionally avoid `flutter_secure_storage` Keychain: unsigned /
/// ad-hoc release builds re-prompt for the login keychain on every SecItem
/// access (often 3–4 dialogs after the permission gate). File storage under
/// Application Support + LocalAuthentication on Grant is the reliable path.
class AppSecureStorage {
  AppSecureStorage._();

  static AppKeyedStorage get instance => _debugInstance ?? _instance;

  static final AppKeyedStorage _instance = _create();

  static AppKeyedStorage? _debugInstance;

  /// Stands in for the platform store in a test that drives code reading
  /// [instance] directly; null puts the real one back.
  @visibleForTesting
  static set debugInstance(AppKeyedStorage? storage) =>
      _debugInstance = storage;

  static AppKeyedStorage _create() {
    if (!kIsWeb && Platform.isMacOS) {
      return MacOsFileKeyedStorage.instance;
    }
    return _FlutterKeyedStorage(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
          usesDataProtectionKeychain: false,
        ),
      ),
    );
  }
}

class _FlutterKeyedStorage implements AppKeyedStorage {
  _FlutterKeyedStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// JSON map persisted in Application Support (no Keychain prompts).
class MacOsFileKeyedStorage implements AppKeyedStorage {
  MacOsFileKeyedStorage._();

  static final MacOsFileKeyedStorage instance = MacOsFileKeyedStorage._();

  static const _fileName = 'begzar_secure_store.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, String>> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (e) {
      return {};
    }
  }

  Future<void> _save(Map<String, String> data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<String?> read({required String key}) async {
    final data = await _load();
    return data[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    final data = await _load();
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
    await _save(data);
  }

  @override
  Future<void> delete({required String key}) async {
    final data = await _load();
    data.remove(key);
    await _save(data);
  }
}
