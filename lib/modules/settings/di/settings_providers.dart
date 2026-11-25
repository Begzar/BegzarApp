import 'dart:io';

import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/modules/settings/application/services/routing_rules_service.dart';
import 'package:begzar/modules/settings/application/services/settings_service.dart';
import 'package:begzar/modules/settings/data/datasources/launch_appearance_channel.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The settings module's composition root.
///
/// This is the only place that knows both the Riverpod container and the
/// module's data layer, which is what lets everything below it be built with
/// plain constructors and faked in a test by overriding one provider.
///
/// Each controller declares its own `NotifierProvider` beside itself; what
/// lives here is the graph underneath them.

/// Whether this platform has a system proxy the engine can take over.
///
/// A platform fact rather than a preference, and the only place the app asks
/// it — the notifier and the settings screen both used to keep their own
/// copy of this expression.
bool get supportsSystemProxy => !kIsWeb && Platform.isWindows;

/// Whether this platform can send some apps through the tunnel and not others.
///
/// Android decides per app in the VPN service; Windows and Linux match the
/// engine's connections to a program by its file name. A provider so a test
/// can pin it: read from the host, the settings screen a test sees changed
/// with the machine the suite ran on.
final appRoutingSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows || Platform.isLinux),
);

/// Whether this platform can run Experimental settings' WARP engine.
///
/// The engine is built into the Android and iOS cores only. A provider so a
/// test can pin it, and so the settings screen and the connect path ask the
/// same question: a choice stored on another platform is never acted on.
final experimentalSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

/// Secure-storage-backed local data source.
/// Where the theme pick is handed to the next launch window.
final launchAppearanceProvider = Provider<LaunchAppearanceChannel>(
  (ref) => const LaunchAppearanceChannel(),
);

final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return SettingsStorage(storage: ref.watch(flutterSecureStorageProvider));
});

/// The one door to settings data. Tests override this rather than the
/// sources beneath it.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    storage: ref.watch(settingsStorageProvider),
    systemProxySupported: supportsSystemProxy,
  );
});

/// Preferences and app routing.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(settingsRepositoryProvider));
});

/// The custom routing rule set and its edits.
final routingRulesServiceProvider = Provider<RoutingRulesService>((ref) {
  return RoutingRulesService(ref.watch(settingsRepositoryProvider));
});
