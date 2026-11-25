import 'package:begzar/modules/app_update/domain/app_version_gate.dart';
import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/controllers/startup_update_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

StartupUpdateGate _gate(ProviderContainer container) =>
    container.read(startupUpdateGateProvider);

void main() {
  test('an allowed build goes straight through', () async {
    final container = _container();

    final verdict = await _gate(
      container,
    ).evaluate(Future.value(const AppVersionGateResult.allow()));

    expect(verdict, StartupUpdateVerdict.allowed);
    expect(container.read(forceUpdateProvider).required, isFalse);
  });

  test('a required update is recorded for the rest of the app', () async {
    final container = _container();

    final verdict = await _gate(container).evaluate(
      Future.value(
        const AppVersionGateResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '2.0.0',
          updateUrl: 'https://example.test/update',
        ),
      ),
    );

    expect(verdict, StartupUpdateVerdict.updateRequired);

    final force = container.read(forceUpdateProvider);
    expect(force.required, isTrue);
    expect(force.currentVersion, '1.0.0');
    expect(force.requiredVersion, '2.0.0');
    expect(force.updateUrl, 'https://example.test/update');
  });

  // Fail-open on purpose. A client that bricks itself whenever the version
  // catalog is unreachable is a worse failure than one running a build behind.
  test('a check that throws lets the user in', () async {
    final container = _container();

    final verdict = await _gate(
      container,
    ).evaluate(Future.error(Exception('no network')));

    expect(verdict, StartupUpdateVerdict.allowed);
    expect(container.read(forceUpdateProvider).required, isFalse);
  });

  group('StartupUpdateGate.evaluate', () {
    test(
      'should publish an available update for the rest of the app',
      () async {
        final container = _container();

        final verdict = await _gate(container).evaluate(
          Future.value(
            const AppVersionGateResult.updateAvailable(
              currentVersion: '1.0.0',
              latestVersion: '1.1.0',
              updateUrl: 'https://example.test/update',
            ),
          ),
        );

        expect(verdict, StartupUpdateVerdict.allowed);
        expect(container.read(forceUpdateProvider).required, isFalse);

        final update = container.read(availableUpdateProvider);
        expect(update?.version, '1.1.0');
        expect(update?.url, 'https://example.test/update');
      },
    );

    test('should publish nothing beside a required update', () async {
      final container = _container();

      await _gate(container).evaluate(
        Future.value(
          const AppVersionGateResult.updateRequired(
            currentVersion: '1.0.0',
            requiredVersion: '2.0.0',
            updateUrl: 'https://example.test/update',
          ),
        ),
      );

      expect(container.read(availableUpdateProvider), isNull);
    });

    test('should publish nothing for a build that is current', () async {
      final container = _container();

      await _gate(
        container,
      ).evaluate(Future.value(const AppVersionGateResult.allow()));

      expect(container.read(availableUpdateProvider), isNull);
    });
  });
}
