import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/storage/connection_state_storage.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/states/connection_ad_gate_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';

void main() {
  group('shouldPenalizeBackground', () {
    test('is false until the gate is armed', () {
      expect(
        const ConnectionAdGateState().shouldPenalizeBackground(
          connectionActive: true,
        ),
        isFalse,
      );
    });

    test('is true while the wait is still running', () {
      const gate = ConnectionAdGateState(isActive: true, remainingSeconds: 10);
      expect(gate.shouldPenalizeBackground(connectionActive: true), isTrue);
    });

    test('is false after the wait finishes', () {
      const gate = ConnectionAdGateState(isActive: true, canClose: true);
      expect(gate.shouldPenalizeBackground(connectionActive: true), isFalse);
    });

    test('is false when the user opened the ad CTA', () {
      const gate = ConnectionAdGateState(
        isActive: true,
        remainingSeconds: 10,
        openedAdClick: true,
      );
      expect(gate.shouldPenalizeBackground(connectionActive: true), isFalse);
    });

    test('is false when the VPN is not connected', () {
      const gate = ConnectionAdGateState(isActive: true, remainingSeconds: 10);
      expect(gate.shouldPenalizeBackground(connectionActive: false), isFalse);
    });
  });

  group('pause and resume', () {
    testWidgets('pause freezes remaining seconds until resume', (tester) async {
      final container = _container();
      final notifier = container.read(connectionAdGateProvider.notifier);

      notifier.start(seconds: 10);
      await tester.pump(const Duration(seconds: 3));
      expect(container.read(connectionAdGateProvider).remainingSeconds, 7);

      notifier.pause();
      await tester.pump(const Duration(seconds: 5));
      expect(container.read(connectionAdGateProvider).remainingSeconds, 7);
      expect(container.read(connectionAdGateProvider).canClose, isFalse);

      notifier.resume();
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(connectionAdGateProvider).remainingSeconds, 5);
      notifier.complete();
    });

    testWidgets('resume is a no-op when already ticking', (tester) async {
      final container = _container();
      final notifier = container.read(connectionAdGateProvider.notifier);

      notifier.start(seconds: 5);
      notifier.resume();
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(connectionAdGateProvider).remainingSeconds, 3);
      notifier.complete();
    });
  });

  group('the unfinished-gate flag', () {
    testWidgets('is written while the countdown runs and cleared at zero', (
      tester,
    ) async {
      final storage = MemoryKeyedStorage();
      final container = _container(storage);
      final notifier = container.read(connectionAdGateProvider.notifier);
      final flags = ConnectionStateStorage(storage: storage);

      notifier.start(seconds: 3);
      await tester.pump();
      expect(await flags.hasAdGateActive(), isTrue);

      await tester.pump(const Duration(seconds: 3));
      expect(container.read(connectionAdGateProvider).canClose, isTrue);
      expect(
        await flags.hasAdGateActive(),
        isFalse,
        reason: 'a watched-out ad must not cost the next launch its tunnel',
      );
      notifier.complete();
    });

    testWidgets('survives a gate the user walked out of', (tester) async {
      final storage = MemoryKeyedStorage();
      final container = _container(storage);
      final notifier = container.read(connectionAdGateProvider.notifier);
      final flags = ConnectionStateStorage(storage: storage);

      notifier.start(seconds: 15);
      await tester.pump(const Duration(seconds: 4));

      // The process ends here; nothing clears the flag on the way out.
      expect(await flags.hasAdGateActive(), isTrue);
      notifier.complete();
    });

    // Backgrounding mid-ad disconnects, but that disconnect races an app on
    // its way out. Clearing here once cost the next launch the only evidence
    // it had that the ad was never watched.
    testWidgets('survives a force-close, and the complete that follows it', (
      tester,
    ) async {
      final storage = MemoryKeyedStorage();
      final container = _container(storage);
      final notifier = container.read(connectionAdGateProvider.notifier);
      final flags = ConnectionStateStorage(storage: storage);

      notifier.start(seconds: 15);
      await tester.pump(const Duration(seconds: 4));

      // The real order when the app is backgrounded mid-ad: the overlay is
      // dismissed and force-closed, and dismissing it releases the connect
      // path's `finally` into complete(). On a device that second call
      // arrived to find an inactive gate and cleared the flag half a second
      // after it was written.
      notifier.forceClose();
      notifier.complete();
      await tester.pump();

      expect(await flags.hasAdGateActive(), isTrue);
    });

    testWidgets('is kept when a gate is torn down mid-countdown', (
      tester,
    ) async {
      final storage = MemoryKeyedStorage();
      final container = _container(storage);
      final notifier = container.read(connectionAdGateProvider.notifier);
      final flags = ConnectionStateStorage(storage: storage);

      notifier.start(seconds: 15);
      await tester.pump(const Duration(seconds: 4));
      notifier.complete();
      await tester.pump();

      expect(
        await flags.hasAdGateActive(),
        isTrue,
        reason: 'a wait cut short is exactly what the flag records',
      );
    });

    // A connect that never had an ad to show still runs the handler's
    // teardown, and must not leave a flag behind for the next launch to
    // punish someone for.
    testWidgets('is cleared when no gate ever started', (tester) async {
      final storage = MemoryKeyedStorage(<String, String>{
        'ad_gate_active': 'true',
      });
      final container = _container(storage);
      final flags = ConnectionStateStorage(storage: storage);

      container.read(connectionAdGateProvider.notifier).complete();
      await tester.pump();

      expect(await flags.hasAdGateActive(), isFalse);
    });
  });
}

ProviderContainer _container([MemoryKeyedStorage? storage]) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(
        storage ?? MemoryKeyedStorage(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
