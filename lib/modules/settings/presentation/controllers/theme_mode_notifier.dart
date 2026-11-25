import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/data/datasources/initial_theme_mode.dart';
import 'package:begzar/modules/settings/data/datasources/launch_appearance_channel.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What analytics calls the theme setting.
const _themeSetting = 'theme';

/// Which theme the app is drawn in: the device's, or one picked in Settings.
///
/// System default is what an install starts on and what nothing stored means,
/// so the platform's own brightness decides until a reader picks.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier({ThemeMode initial = ThemeMode.system})
    : _initial = initial;

  final ThemeMode _initial;
  late SettingsStorage _storage;
  late LaunchAppearanceChannel _launchAppearance;
  late Future<void> _loadFuture;
  bool _userTouched = false;

  /// Publishes what was stored, unless the reader has already picked: the
  /// screen is usable before the read lands, and a late answer must not undo
  /// a choice made in the meantime. A store that cannot be read leaves the
  /// theme where it is.
  ///
  /// The stored choice is also handed to the launch window on every launch,
  /// so a pick made before the platform was told about picks still reaches
  /// it.
  Future<void> _load() async {
    final String? stored;
    try {
      stored = await _storage.readThemeMode();
    } catch (_) {
      return;
    }
    if (!ref.mounted || _userTouched) return;
    state = themeModeNamed(stored);
    unawaited(_launchAppearance.follow(state));
  }

  @override
  ThemeMode build() {
    _storage = ref.watch(settingsStorageProvider);
    _launchAppearance = ref.watch(launchAppearanceProvider);
    _loadFuture = _load();
    return _initial;
  }

  Future<void> ensureLoaded() => _loadFuture;

  Future<void> setThemeMode(ThemeMode mode) async {
    _userTouched = true;
    state = mode;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logSettingChanged(setting: _themeSetting, value: mode.name),
    );
    unawaited(_launchAppearance.follow(mode));
    await _storage.writeThemeMode(mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
