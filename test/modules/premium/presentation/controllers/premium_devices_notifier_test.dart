import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_devices_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../premium_test_doubles.dart';

/// Where the linked-devices list comes from.
///
/// The account answers with the roster as well as the subscription,
/// so the list is read out of the account refresh. There is no second request
/// for it, and the count is what proves that.
void main() {
  final roster = LinkedDevices(
    maxDevices: 3,
    activeDevices: 2,
    devices: [
      PremiumDevice(
        deviceId: 'test-device',
        deviceName: 'This phone',
        loggedInAt: DateTime.utc(2026, 9, 1),
      ),
      PremiumDevice(
        deviceId: 'other',
        deviceName: 'Old tablet',
        loggedInAt: DateTime.utc(2026, 7, 1),
      ),
    ],
  );

  test('the roster arrives with the account, in one round trip', () async {
    final repository = FakePremiumRepository(
      session: _signedIn(),
      devices: roster,
    );
    final container = _container(repository);

    await container.read(premiumDevicesProvider.notifier).loadIfNeeded();

    final state = container.read(premiumDevicesProvider);
    expect(state.devices.map((d) => d.deviceId), ['test-device', 'other']);
    expect(state.maxDevices, 3);
    expect(state.activeDevices, 2);
    expect(state.errorMessage, isNull);
    expect(
      repository.refreshAccountCount,
      1,
      reason: 'the device list must not cost a request of its own',
    );
  });

  test('the list marks which row is this install', () async {
    final container = _container(
      FakePremiumRepository(session: _signedIn(), devices: roster),
    );

    await container.read(premiumDevicesProvider.notifier).loadIfNeeded();

    expect(
      container.read(premiumDevicesProvider).currentDeviceId,
      'test-device',
    );
  });

  test('a second load is skipped unless it is forced', () async {
    final repository = FakePremiumRepository(
      session: _signedIn(),
      devices: roster,
    );
    final container = _container(repository);
    final notifier = container.read(premiumDevicesProvider.notifier);

    await notifier.loadIfNeeded();
    await notifier.loadIfNeeded();
    expect(repository.refreshAccountCount, 1);

    await notifier.loadIfNeeded(force: true);
    expect(repository.refreshAccountCount, 2);
  });

  // No stored credential is not a failed call, and the repository answers null
  // rather than a left. The devices side has to turn that into something the
  // section can show.
  test('a signed-out user is told the session is missing', () async {
    final container = _container(FakePremiumRepository());

    await container.read(premiumDevicesProvider.notifier).loadIfNeeded();

    expect(
      container.read(premiumDevicesProvider).errorMessage,
      UserFacingErrorKeys.sessionNotFound,
    );
  });

  // The roster refresh is a full account refresh, so it is one of the places a
  // revoked session surfaces. Left to the section alone it would clear storage
  // and leave the rest of the app showing a subscription that no longer exists.
  test('a revoked session signs the account out too', () async {
    final repository = FakePremiumRepository(
      session: _signedIn(),
      devices: roster,
    );
    final container = _container(repository);
    final premium = container.read(premiumProvider.notifier);
    await premium.ensureRestored();
    await premium.refreshSubscription(silent: true);
    await Future<void>.delayed(Duration.zero);

    repository.refreshResult = left(const SessionRevokedFailure());
    await container.read(premiumDevicesProvider.notifier).loadIfNeeded();

    expect(container.read(premiumProvider), isA<PremiumSignedOut>());
  });

  group('PremiumDevicesNotifier.removeDevice', () {
    test('should keep a failed removal out of the list\'s error', () async {
      final container = _container(
        FakePremiumRepository(
          session: _signedIn(),
          devices: roster,
          removeDeviceResult: left(const NetworkFailure('offline')),
        ),
      );
      final notifier = container.read(premiumDevicesProvider.notifier);
      await notifier.loadIfNeeded();

      await notifier.removeDevice('other');

      final state = container.read(premiumDevicesProvider);
      expect(
        state.errorMessage,
        isNull,
        reason:
            'the row reports a failed removal in the error toast; kept here '
            'it printed again above the device list',
      );
      expect(state.removingDeviceId, isNull);
      expect(state.devices.map((device) => device.deviceId), [
        'test-device',
        'other',
      ]);
    });
  });
}

ProviderContainer _container(FakePremiumRepository repository) {
  final container = ProviderContainer(
    overrides: [premiumRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

PremiumSession _signedIn() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);
