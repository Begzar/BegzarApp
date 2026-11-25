import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
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
  group('ForceUpdateNotifier', () {
    test('should record the versions when an update is first required', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);

      container
          .read(forceUpdateProvider.notifier)
          .markRequired(currentVersion: '7.3.0', requiredVersion: '7.4.0');

      expect(analytics.callsTo(#logForceUpdateRequired), [
        {#currentVersion: '7.3.0', #requiredVersion: '7.4.0'},
      ]);
    });

    // The startup gate and the connect path can both reach the verdict, and a
    // refused connect reaches it again on every tap.
    test('should record once however often it is required again', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);
      final notifier = container.read(forceUpdateProvider.notifier);

      notifier.markRequired(currentVersion: '7.3.0', requiredVersion: '7.4.0');
      notifier.markRequired(currentVersion: '7.3.0', requiredVersion: '7.4.0');

      expect(analytics.callsTo(#logForceUpdateRequired), hasLength(1));
    });

    test('should record nothing while no update is required', () {
      final analytics = RecordingAnalytics();
      final container = _container(analytics);

      container.read(forceUpdateProvider);

      expect(analytics.callsTo(#logForceUpdateRequired), isEmpty);
    });
  });
}
