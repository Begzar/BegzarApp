import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_keyed_storage.dart';
import '../support/recording_analytics.dart';

void main() {
  group('LocaleNotifier', () {
    // The first-run screen and the settings dropdown both land here, so one
    // record covers a language picked either way.
    test('should record the language picked', () async {
      final analytics = RecordingAnalytics();
      final container = ProviderContainer(
        overrides: [
          flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(localeProvider.notifier)
          .setLanguage(AppLanguage.persian);

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'language', #value: 'fa'},
      ]);
    });
  });
}
