import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a home dial might be laid out.
const _dialPlace = Rect.fromLTWH(100, 200, 180, 180);

ProviderContainer _container({
  LaunchCoverPhase initial = LaunchCoverPhase.covering,
}) {
  final container = ProviderContainer(
    overrides: [
      launchCoverProvider.overrideWith(
        () => LaunchCoverNotifier(initial: initial),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LaunchCoverNotifier', () {
    test('should rest done when nothing asked for a cover', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });

    test('should land on the place the home dial reports', () {
      final container = _container();

      container.read(launchCoverProvider.notifier).land(_dialPlace);

      final state = container.read(launchCoverProvider);
      expect(state.phase, LaunchCoverPhase.landing);
      expect(state.target, _dialPlace);
    });

    test('should leave without landing when a screen other than home asks', () {
      final container = _container();

      container.read(launchCoverProvider.notifier).dismiss();

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });

    // Only the first answer moves the cover: a home dial laid out behind a
    // screen that already asked must not pull the cover back to fly.
    test('should ignore a landing once it is leaving', () {
      final container = _container();
      final notifier = container.read(launchCoverProvider.notifier);

      notifier.dismiss();
      notifier.land(_dialPlace);

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });

    // A dialog over home, the forced update's, can open while the dial is on
    // its way; the dial must not carry on across it.
    test('should leave mid-flight when something opens over home', () {
      final container = _container();
      final notifier = container.read(launchCoverProvider.notifier);

      notifier.land(_dialPlace);
      notifier.dismiss();

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });

    test('should end once the cover is gone', () {
      final container = _container();
      final notifier = container.read(launchCoverProvider.notifier);

      notifier.land(_dialPlace);
      notifier.finish();

      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });

    test('should not cover again after it ended', () {
      final container = _container(initial: LaunchCoverPhase.done);

      container.read(launchCoverProvider.notifier).land(_dialPlace);

      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });
  });
}
