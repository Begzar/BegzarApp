import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';
import '../../../../support/recording_analytics.dart';

Future<ProviderContainer> _container(RecordingAnalytics analytics) async {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  await container.read(settingsProvider.notifier).ensureLoaded();
  return container;
}

void main() {
  group('SettingsNotifier', () {
    test('should record each toggle under its own name', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);
      final settings = container.read(settingsProvider.notifier);

      await settings.setProxyOnly(true);
      await settings.setBypassLan(false);
      await settings.setAppExclude(true);

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'proxy_only', #value: 'on'},
        {#setting: 'bypass_lan', #value: 'off'},
        {#setting: 'app_exclude', #value: 'on'},
      ]);
    });

    test('should record Experimental settings and the WARP mode', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);
      final settings = container.read(settingsProvider.notifier);

      await settings.setExperimental(true);
      await settings.setWarpMode(WarpMode.masquePsiphon);
      await settings.setExperimental(false);

      final preferences = container.read(settingsProvider);
      expect(preferences.experimental, isFalse);
      expect(
        preferences.warpMode,
        WarpMode.masquePsiphon,
        reason: 'turning it off keeps the mode for when it comes back on',
      );
      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'experimental', #value: 'on'},
        {#setting: 'experimental_mode', #value: 'masque_psiphon'},
        {#setting: 'experimental', #value: 'off'},
      ]);
    });

    test('should record the connection mode', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);

      await container
          .read(settingsProvider.notifier)
          .setConnectionMode(ExposureMode.tunnel);

      expect(container.read(settingsProvider).exposure.tunnel, isTrue);
      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'connection_mode', #value: 'tunnel'},
      ]);
    });

    // The resolver a user types is theirs; which kind it was is all analytics
    // needs.
    test('should record a resolver the user named as custom', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);

      await container.read(settingsProvider.notifier).setDnsServer('1.1.1.1');

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'dns', #value: 'custom'},
      ]);
    });

    test('should record the fallback resolver as default', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);

      await container.read(settingsProvider.notifier).setDnsServer('8.8.8.8');

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'dns', #value: 'default'},
      ]);
    });

    test('should record nothing for a resolver it refused', () async {
      final analytics = RecordingAnalytics();
      final container = await _container(analytics);

      await container
          .read(settingsProvider.notifier)
          .setDnsServer('not-an-address');

      expect(analytics.callsTo(#logSettingChanged), isEmpty);
    });
  });
}
