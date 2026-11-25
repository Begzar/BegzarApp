import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Install channel baked into the binary via
/// `--dart-define=DISTRIBUTION_SOURCE=<id>`.
///
/// Canonical ids match the release catalog's channel keys:
/// `github`, `google_play`, `ms_store`, `testflight`, `app_store`.
///
/// Release scripts pass this. Store pipelines (Play / MS Store / App Store /
/// TestFlight) must set the matching id — a missing define defaults to
/// `github`, and a source the catalog does not list fails open.
class AppDistribution {
  AppDistribution._();

  static const defineKey = 'DISTRIBUTION_SOURCE';

  static const String raw = String.fromEnvironment(
    defineKey,
    defaultValue: 'github',
  );

  static AppDistributionSource get source =>
      AppDistributionSource.parse(raw) ?? AppDistributionSource.github;

  static String get sourceKey => source.apiKey;

  /// Platform key in the version catalog (`android` / `windows` / `ios` /
  /// `macos`). Separate from the V4 session header, which still maps macOS
  /// to `windows` for subscription routes.
  static String get catalogPlatform {
    if (kIsWeb) return 'android';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'android';
  }
}

enum AppDistributionSource {
  github('github'),
  googlePlay('google_play'),
  msStore('ms_store'),
  testFlight('testflight'),
  appStore('app_store');

  const AppDistributionSource(this.apiKey);
  final String apiKey;

  static AppDistributionSource? parse(String raw) {
    switch (raw.trim().toLowerCase().replaceAll('-', '_')) {
      case 'github':
      case 'gh':
        return github;
      case 'google_play':
      case 'googleplay':
      case 'play':
      case 'play_store':
        return googlePlay;
      case 'ms_store':
      case 'msstore':
      case 'microsoft_store':
        return msStore;
      case 'testflight':
      case 'test_flight':
        return testFlight;
      case 'app_store':
      case 'appstore':
        return appStore;
      default:
        return null;
    }
  }
}
