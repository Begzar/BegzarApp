import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/presentation/controllers/theme_mode_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';
import '../../../../support/recording_analytics.dart';
import '../../settings_test_doubles.dart';

/// Where the choice is kept.
const _key = 'settings_theme_mode';

ProviderContainer _container(
  AppKeyedStorage storage, {
  RecordingAnalytics? analytics,
  RecordingLaunchAppearance? launchAppearance,
}) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(storage),
      analyticsServiceProvider.overrideWithValue(
        analytics ?? RecordingAnalytics(),
      ),
      launchAppearanceProvider.overrideWithValue(
        launchAppearance ?? RecordingLaunchAppearance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ThemeModeNotifier', () {
    test('should start on system default with nothing stored', () async {
      final container = _container(MemoryKeyedStorage());

      await container.read(themeModeProvider.notifier).ensureLoaded();

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('should restore a stored light', () async {
      final container = _container(MemoryKeyedStorage({_key: 'light'}));

      await container.read(themeModeProvider.notifier).ensureLoaded();

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('should treat an unknown value as system default', () async {
      final container = _container(MemoryKeyedStorage({_key: 'sepia'}));

      await container.read(themeModeProvider.notifier).ensureLoaded();

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('should keep system default when the store cannot be read', () async {
      final container = _container(const FailingKeyedStorage());

      await container.read(themeModeProvider.notifier).ensureLoaded();

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('should write the pick by name', () async {
      final storage = MemoryKeyedStorage();
      final container = _container(storage);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(storage.values[_key], 'dark');
    });

    test('should record the pick as setting theme', () async {
      final analytics = RecordingAnalytics();
      final container = _container(MemoryKeyedStorage(), analytics: analytics);

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'theme', #value: 'light'},
      ]);
    });

    // The screen is usable before the stored value lands; a late answer must
    // not undo a choice made in the meantime.
    test('should keep a pick made before the stored value loads', () async {
      final container = _container(MemoryKeyedStorage({_key: 'dark'}));
      final notifier = container.read(themeModeProvider.notifier);

      final pick = notifier.setThemeMode(ThemeMode.light);
      await notifier.ensureLoaded();
      await pick;

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    // The next launch window is drawn before Dart runs, so it can only follow
    // a pick the platform was told about.
    test('should hand the pick to the launch window', () async {
      final launchAppearance = RecordingLaunchAppearance();
      final container = _container(
        MemoryKeyedStorage(),
        launchAppearance: launchAppearance,
      );
      final notifier = container.read(themeModeProvider.notifier);
      await notifier.ensureLoaded();

      await notifier.setThemeMode(ThemeMode.dark);

      expect(launchAppearance.followed.last, ThemeMode.dark);
    });

    // A pick made before this build shipped was never handed over; reading it
    // back at launch is what brings the launch window in line.
    test('should hand the stored choice to the launch window', () async {
      final launchAppearance = RecordingLaunchAppearance();
      final container = _container(
        MemoryKeyedStorage({_key: 'light'}),
        launchAppearance: launchAppearance,
      );

      await container.read(themeModeProvider.notifier).ensureLoaded();

      expect(launchAppearance.followed, [ThemeMode.light]);
    });

    test(
      'should leave the launch window alone when the store cannot be read',
      () async {
        final launchAppearance = RecordingLaunchAppearance();
        final container = _container(
          const FailingKeyedStorage(),
          launchAppearance: launchAppearance,
        );

        await container.read(themeModeProvider.notifier).ensureLoaded();

        expect(launchAppearance.followed, isEmpty);
      },
    );

    test('should open in the theme read before the first frame', () {
      final container = ProviderContainer(
        overrides: [
          flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
          themeModeProvider.overrideWith(
            () => ThemeModeNotifier(initial: ThemeMode.dark),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
