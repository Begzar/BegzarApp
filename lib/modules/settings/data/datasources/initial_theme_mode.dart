import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:flutter/material.dart';

/// The theme a stored [name] stands for.
///
/// Nothing stored, and anything that is not a theme's name, is System default:
/// a pick is the only thing that writes.
ThemeMode themeModeNamed(String? name) =>
    ThemeMode.values.asNameMap()[name] ?? ThemeMode.system;

/// Reads the stored theme before the first frame, so a reader who picked one
/// never sees the other for a frame.
///
/// A store that cannot be read opens in System default rather than not at all.
Future<ThemeMode> loadInitialThemeMode() async {
  try {
    final name = await SettingsStorage(
      storage: AppSecureStorage.instance,
    ).readThemeMode();
    return themeModeNamed(name);
  } catch (_) {
    return ThemeMode.system;
  }
}
