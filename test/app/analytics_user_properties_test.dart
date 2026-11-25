import 'package:begzar/app/analytics_user_properties.dart';
import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../modules/premium/premium_test_doubles.dart';
import '../support/memory_keyed_storage.dart';
import '../support/recording_analytics.dart';

PremiumSession _subscriber() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);

ProviderContainer _container({
  required RecordingAnalytics analytics,
  PremiumSession? session,
  AppDistributionSource distribution = AppDistributionSource.github,
}) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
      premiumRepositoryProvider.overrideWithValue(
        FakePremiumRepository(session: session),
      ),
      appDistributionSourceProvider.overrideWithValue(distribution),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('analyticsUserPropertiesProvider', () {
    test('should set the channel the build was made for', () {
      final analytics = RecordingAnalytics();
      final container = _container(
        analytics: analytics,
        distribution: AppDistributionSource.googlePlay,
      );

      container.read(analyticsUserPropertiesProvider);

      expect(analytics.callsTo(#setDistribution), [
        {#source: 'google_play'},
      ]);
    });

    // A restore that has not landed reads as signed out, and setting free for
    // a subscriber at every launch would split their events across both tiers.
    test('should set no tier while the session is still restoring', () {
      final analytics = RecordingAnalytics();
      final container = _container(
        analytics: analytics,
        session: _subscriber(),
      );

      container.read(analyticsUserPropertiesProvider);

      expect(analytics.callsTo(#setPlanTier), isEmpty);
    });

    test('should set premium once a subscriber is restored', () async {
      final analytics = RecordingAnalytics();
      final container = _container(
        analytics: analytics,
        session: _subscriber(),
      );

      container.read(analyticsUserPropertiesProvider);
      await container.read(premiumProvider.notifier).ensureRestored();

      expect(analytics.callsTo(#setPlanTier), [
        {#tier: PlanTier.premium},
      ]);
    });

    test('should set free once a signed-out user is restored', () async {
      final analytics = RecordingAnalytics();
      final container = _container(analytics: analytics);

      container.read(analyticsUserPropertiesProvider);
      await container.read(premiumProvider.notifier).ensureRestored();

      expect(analytics.callsTo(#setPlanTier), [
        {#tier: PlanTier.free},
      ]);
    });

    test('should move a subscriber who signs out to free', () async {
      final analytics = RecordingAnalytics();
      final container = _container(
        analytics: analytics,
        session: _subscriber(),
      );
      container.read(analyticsUserPropertiesProvider);
      await container.read(premiumProvider.notifier).ensureRestored();

      await container.read(premiumProvider.notifier).logout();

      expect(analytics.callsTo(#setPlanTier), [
        {#tier: PlanTier.premium},
        {#tier: PlanTier.free},
      ]);
    });
  });
}
