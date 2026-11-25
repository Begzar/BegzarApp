import 'package:begzar/core/providers/api_provider.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../connection/connection_test_doubles.dart';
import '../../premium_test_doubles.dart';

/// A device that does not place itself, so settling it takes the address.
const _berlin = DeviceRegionSignals(
  utcOffset: Duration(hours: 1),
  timeZoneId: 'Europe/Berlin',
);

PremiumSession _session({required bool active}) {
  final expiry = active
      ? DateTime.now().add(const Duration(days: 30))
      : DateTime.now().subtract(const Duration(days: 1));
  return PremiumSession(
    accessKey: 'test-key',
    account: PremiumAccount(
      username: 'tester',
      expireDate: expiry.toIso8601String(),
    ),
  );
}

/// The launcher on the real premium graph, with every seam it can reach faked
/// — the connection read for tunnel state and the free-tier client included,
/// so nothing here reaches a live API.
(ProviderContainer, FakePurchaseRegionRepository) _launch({
  PremiumSession? session,
  AppDistributionSource source = AppDistributionSource.github,
}) {
  final regions = FakePurchaseRegionRepository(
    device: _berlin,
    addressResult: right('DE'),
  );
  final container = ProviderContainer(
    overrides: [
      appDistributionSourceProvider.overrideWithValue(source),
      connectionRepositoryProvider.overrideWithValue(
        FakeConnectionRepository(),
      ),
      apiV2ServiceProvider.overrideWithValue(FakeApiV2Service()),
      premiumRepositoryProvider.overrideWithValue(
        FakePremiumRepository(session: session),
      ),
      purchaseRegionRepositoryProvider.overrideWithValue(regions),
    ],
  );
  addTearDown(container.dispose);
  return (container, regions);
}

void main() {
  test('a free user is placed at launch, before any button asks', () async {
    final (container, regions) = _launch();

    await container.read(premiumPurchaseLauncherProvider).warm();

    expect(regions.addressAsks, 1);
    expect(regions.kept?.country, 'DE');
  });

  test('the first dialog after launch does not ask again', () async {
    final (container, regions) = _launch();
    final launcher = container.read(premiumPurchaseLauncherProvider);

    await launcher.warm();
    final destination = await launcher.destination();

    expect(destination, PurchaseDestination.website);
    expect(regions.addressAsks, 1);
  });

  test('a subscriber is not asked where they are', () async {
    final (container, regions) = _launch(session: _session(active: true));

    await container.read(premiumPurchaseLauncherProvider).warm();

    expect(regions.deviceReads, 0);
    expect(regions.addressAsks, 0);
  });

  test('a lapsed subscriber is placed, because renewing is buying', () async {
    final (container, regions) = _launch(session: _session(active: false));

    await container.read(premiumPurchaseLauncherProvider).warm();

    expect(regions.addressAsks, 1);
  });

  group('PremiumPurchaseLauncher.destination', () {
    test('should send a Play build to Google Play without asking where the '
        'device is', () async {
      final (container, regions) = _launch(
        source: AppDistributionSource.googlePlay,
      );
      final launcher = container.read(premiumPurchaseLauncherProvider);

      await launcher.warm();
      final destination = await launcher.destination();

      expect(destination, PurchaseDestination.googlePlay);
      expect(launcher.sellsThroughGooglePlay, isTrue);
      expect(regions.deviceReads, 0);
      expect(regions.addressAsks, 0);
    });

    test('should leave other builds on the region rule', () async {
      final (container, regions) = _launch();
      final launcher = container.read(premiumPurchaseLauncherProvider);

      final destination = await launcher.destination();

      expect(destination, PurchaseDestination.website);
      expect(launcher.sellsThroughGooglePlay, isFalse);
      expect(regions.deviceReads, 1);
    });
  });
}
