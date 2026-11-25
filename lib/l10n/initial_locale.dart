import 'dart:ui' show PlatformDispatcher;

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:flutter/material.dart';

/// What the app opens in, read before the first frame.
///
/// [saved] is false until a language has been picked, on the first-run screen
/// or in Settings. Until then [locale] is the device's own language, or
/// English where the app has no translation for it.
typedef InitialLocale = ({Locale locale, bool saved});

/// Reads the saved locale from secure storage before the first frame.
Future<InitialLocale> loadInitialLocale() async {
  final code = await SettingsStorage(
    storage: AppSecureStorage.instance,
  ).readLocale();
  final saved = AppLanguage.fromCode(code);
  final language =
      saved ?? AppLanguage.forDevice(PlatformDispatcher.instance.locale);
  return (locale: language.locale, saved: saved != null);
}
