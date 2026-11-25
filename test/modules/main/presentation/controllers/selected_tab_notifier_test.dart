import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_analytics.dart';

ProviderContainer _container(RecordingAnalytics analytics) {
  final container = ProviderContainer(
    overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SelectedTab', () {
    test('should record home as the first screen of the run', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);

      container.read(selectedTabProvider);

      expect(analytics.callsTo(#logScreenView), [
        {#screenName: 'home'},
      ]);
    });

    test('should record each tab it switches to', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);
      container.read(selectedTabProvider);

      container.read(selectedTabProvider.notifier).select(premiumIndex);
      container.read(selectedTabProvider.notifier).select(settingIndex);

      expect(analytics.callsTo(#logScreenView), [
        {#screenName: 'home'},
        {#screenName: 'premium'},
        {#screenName: 'settings'},
      ]);
    });

    test('should record nothing when the showing tab is tapped again', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);
      container.read(selectedTabProvider);

      container.read(selectedTabProvider.notifier).select(homeIndex);

      expect(analytics.callsTo(#logScreenView), hasLength(1));
    });
  });
}
