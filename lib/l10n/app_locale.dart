import 'package:flutter/material.dart';

/// Supported app languages.
enum AppLanguage {
  english('en', 'English'),
  persian('fa', 'فارسی'),
  chinese('zh', '中文'),
  russian('ru', 'Русский');

  const AppLanguage(this.code, this.nativeLabel);

  final String code;
  final String nativeLabel;

  Locale get locale => Locale(code);

  /// The way its script runs, for text set in it outside its own locale.
  TextDirection get textDirection =>
      this == AppLanguage.persian ? TextDirection.rtl : TextDirection.ltr;

  static AppLanguage? fromCode(String? code) {
    if (code == null) return null;
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  /// The language the device is set to, as one the app has.
  ///
  /// Only the language is compared, so `fa_IR` is Persian and `zh_Hant_TW` is
  /// Chinese. A language the app has no translation for answers English.
  static AppLanguage forDevice(Locale deviceLocale) =>
      fromCode(deviceLocale.languageCode) ?? AppLanguage.english;

  /// The languages the first-run screen puts its question in, top to bottom.
  ///
  /// The language picked first — the device's own until the reader picks
  /// another — then English for anyone who does not read it. With English
  /// picked, saying it once is enough.
  static List<AppLanguage> firstRunQuestionLanguages(AppLanguage picked) =>
      picked == AppLanguage.english
      ? const [AppLanguage.english]
      : [picked, AppLanguage.english];

  /// Whether a first launch asks for the language at all.
  ///
  /// A device already in Persian is in the language most of the people this
  /// app is for read, so Persian is saved without asking.
  static bool firstRunAsks(AppLanguage device) => device != AppLanguage.persian;

  static const supportedLocales = [
    Locale('en'),
    Locale('fa'),
    Locale('zh'),
    Locale('ru'),
  ];
}
