import 'dart:async';

import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';
import '../../../../support/recording_analytics.dart';

/// A store whose reads wait until the test lets them through, so a pick can
/// be made while the stored selection is still on its way.
class _SlowReadStorage extends MemoryKeyedStorage {
  _SlowReadStorage(super.seed);

  final Completer<void> release = Completer<void>();

  @override
  Future<String?> read({required String key}) async {
    await release.future;
    return super.read(key: key);
  }
}

ProviderContainer _container(
  MemoryKeyedStorage storage,
  RecordingAnalytics analytics,
) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(storage),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> _loadedContainer(RecordingAnalytics analytics) async {
  final container = _container(MemoryKeyedStorage(), analytics);
  await container.read(appRoutingProvider.notifier).ensureLoaded();
  return container;
}

void main() {
  group('AppRoutingNotifier', () {
    test('should record the mode under app_routing_mode', () async {
      final analytics = RecordingAnalytics();
      final container = await _loadedContainer(analytics);

      await container
          .read(appRoutingProvider.notifier)
          .setMode(AppRoutingMode.onlySelected);

      expect(analytics.callsTo(#logSettingChanged), [
        {#setting: 'app_routing_mode', #value: 'only_selected'},
      ]);
    });

    // Which apps a user picked is theirs; only the mode is worth a count.
    test('should record nothing when an app is picked', () async {
      final analytics = RecordingAnalytics();
      final container = await _loadedContainer(analytics);

      await container
          .read(appRoutingProvider.notifier)
          .setPicked('com.a', picked: true);

      expect(analytics.callsTo(#logSettingChanged), isEmpty);
    });

    test('should record nothing when the picks are cleared', () async {
      final analytics = RecordingAnalytics();
      final container = await _loadedContainer(analytics);
      final routing = container.read(appRoutingProvider.notifier);
      await routing.setPicked('com.a', picked: true);

      await routing.clearPicked();

      expect(analytics.callsTo(#logSettingChanged), isEmpty);
    });

    // A pick made before the stored selection lands waits for it, so it is
    // added to what was stored instead of replacing it, and the late read
    // cannot undo it afterwards.
    test(
      'should not let a late read undo a pick made before it landed',
      () async {
        final seeding = MemoryKeyedStorage();
        final seeded = _container(seeding, RecordingAnalytics());
        final seeder = seeded.read(appRoutingProvider.notifier);
        await seeder.ensureLoaded();
        await seeder.setPicked('com.stored', picked: true);
        final storage = _SlowReadStorage(seeding.values);
        final container = _container(storage, RecordingAnalytics());
        final routing = container.read(appRoutingProvider.notifier);

        final pick = routing.setPicked('com.a', picked: true);
        storage.release.complete();
        await pick;

        expect(container.read(appRoutingProvider).allExcept, {
          'com.stored',
          'com.a',
        });
      },
    );
  });
}
