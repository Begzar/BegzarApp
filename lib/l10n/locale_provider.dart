import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What analytics calls the language setting.
const _languageSetting = 'language';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  LocaleNotifier({
    Locale initialLocale = const Locale('en'),
    bool languageSaved = false,
  }) : _initialLocale = initialLocale,
       _languageSaved = languageSaved;

  final Locale _initialLocale;
  late SettingsStorage _storage;
  late Future<void> _loadFuture;
  bool _userTouched = false;
  bool _languageSaved;

  @override
  Locale build() {
    _storage = ref.watch(settingsStorageProvider);
    _loadFuture = _loadLocale();
    return _initialLocale;
  }

  Future<void> ensureLoaded() => _loadFuture;

  /// Whether a language has been picked, on the first-run screen or in
  /// Settings. Until one has, the first-run screen asks for it.
  ///
  /// Settled once [ensureLoaded] completes. `main` reads storage before the
  /// first frame and passes what it found, so on a real launch it is already
  /// true by then for anyone who has picked.
  bool get hasSavedLanguage => _languageSaved;

  Future<void> _loadLocale() async {
    final code = await _storage.readLocale();
    final language = AppLanguage.fromCode(code);
    if (language == null) return;
    _languageSaved = true;
    if (!_userTouched) {
      state = language.locale;
    }
  }

  /// The first-run screen and the settings dropdown both land here, so one
  /// record covers a language picked either way.
  Future<void> setLanguage(AppLanguage language) async {
    await ensureLoaded();
    _userTouched = true;
    _languageSaved = true;
    state = language.locale;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logSettingChanged(setting: _languageSetting, value: language.code),
    );
    await _storage.writeLocale(language.code);
  }
}
