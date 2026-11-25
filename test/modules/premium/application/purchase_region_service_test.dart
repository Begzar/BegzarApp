import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/application/services/purchase_region_service.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../premium_test_doubles.dart';

const _tehran = DeviceRegionSignals(
  utcOffset: Duration(hours: 3, minutes: 30),
  timeZoneId: 'Asia/Tehran',
);

const _berlin = DeviceRegionSignals(
  utcOffset: Duration(hours: 1),
  timeZoneId: 'Europe/Berlin',
);

final _now = DateTime.utc(2026, 9, 26, 12);

PurchaseRegionService _service(
  FakePurchaseRegionRepository repository, {
  bool tunnelCarriesOwnTraffic = false,
  DateTime? now,
}) => PurchaseRegionService(
  repository,
  tunnelCarriesOwnTraffic: tunnelCarriesOwnTraffic,
  clock: () => now ?? _now,
);

void main() {
  test(
    'a device that places itself in Iran asks nothing of the network',
    () async {
      final repository = FakePurchaseRegionRepository(device: _tehran);

      final region = await _service(repository).resolve(tunnelIsUp: false);

      expect(region, PurchaseRegion.iran);
      expect(repository.addressAsks, 0);
    },
  );

  test('an address in Iran places a device that reads foreign', () async {
    final repository = FakePurchaseRegionRepository(
      device: _berlin,
      addressResult: right('IR'),
    );

    final region = await _service(repository).resolve(tunnelIsUp: false);

    expect(region, PurchaseRegion.iran);
    expect(repository.addressAsks, 1);
  });

  test('a foreign device at a foreign address is international', () async {
    final repository = FakePurchaseRegionRepository(
      device: _berlin,
      addressResult: right('DE'),
    );

    expect(
      await _service(repository).resolve(tunnelIsUp: false),
      PurchaseRegion.international,
    );
  });

  test('an address the server gave no country for is silent', () async {
    final repository = FakePurchaseRegionRepository(device: _berlin);

    expect(
      await _service(repository).resolve(tunnelIsUp: false),
      PurchaseRegion.international,
    );
  });

  group('while the tunnel is up', () {
    test(
      'where it carries the app, the exit is not taken for the buyer',
      () async {
        // Apple: the address would be the server's.
        final repository = FakePurchaseRegionRepository(
          device: _berlin,
          addressResult: right('IR'),
        );

        final region = await _service(
          repository,
          tunnelCarriesOwnTraffic: true,
        ).resolve(tunnelIsUp: true);

        expect(region, PurchaseRegion.international);
        expect(repository.addressAsks, 0);
      },
    );

    test('where the app bypasses it, the address is still asked', () async {
      // Android: the app excludes itself from its own VpnService.
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('IR'),
      );

      final region = await _service(repository).resolve(tunnelIsUp: true);

      expect(region, PurchaseRegion.iran);
      expect(repository.addressAsks, 1);
    });

    test('the device still places itself', () async {
      final repository = FakePurchaseRegionRepository(device: _tehran);

      final region = await _service(
        repository,
        tunnelCarriesOwnTraffic: true,
      ).resolve(tunnelIsUp: true);

      expect(region, PurchaseRegion.iran);
    });
  });

  group('the address is asked once', () {
    test('an answer is kept for the run', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
      );
      final service = _service(repository);

      await service.resolve(tunnelIsUp: false);
      await service.resolve(tunnelIsUp: false);

      expect(repository.addressAsks, 1);
    });

    test('purchases arriving together share one request', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
      );
      final service = _service(repository);

      await Future.wait([
        service.resolve(tunnelIsUp: false),
        service.resolve(tunnelIsUp: false),
      ]);

      expect(repository.addressAsks, 1);
    });

    test('a failure is not kept, so the next purchase asks again', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: left(const NetworkFailure()),
      );
      final service = _service(repository);

      expect(
        await service.resolve(tunnelIsUp: false),
        PurchaseRegion.international,
      );

      repository.addressResult = right('IR');
      expect(await service.resolve(tunnelIsUp: false), PurchaseRegion.iran);
      expect(repository.addressAsks, 2);
    });

    test('the device is read afresh every time', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
      );
      final service = _service(repository);

      expect(
        await service.resolve(tunnelIsUp: false),
        PurchaseRegion.international,
      );

      repository.device = _tehran;
      expect(await service.resolve(tunnelIsUp: false), PurchaseRegion.iran);
    });
  });

  group('the address is kept across launches', () {
    test('a kept answer inside its day is used without asking', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
        kept: AddressAnswer(
          country: 'IR',
          askedAt: _now.subtract(const Duration(hours: 23)),
        ),
      );

      expect(
        await _service(repository).resolve(tunnelIsUp: false),
        PurchaseRegion.iran,
      );
      expect(repository.addressAsks, 0);
    });

    test('a kept answer past its day is asked again, and replaced', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
        kept: AddressAnswer(
          country: 'IR',
          askedAt: _now.subtract(PurchaseRegionService.addressTtl),
        ),
      );

      expect(
        await _service(repository).resolve(tunnelIsUp: false),
        PurchaseRegion.international,
      );
      expect(repository.addressAsks, 1);
      expect(repository.kept?.country, 'DE');
      expect(repository.kept?.askedAt, _now);
    });

    test('a kept answer from the future is not trusted', () async {
      // The clock was moved back since it was written.
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: right('DE'),
        kept: AddressAnswer(
          country: 'IR',
          askedAt: _now.add(const Duration(days: 3)),
        ),
      );

      await _service(repository).resolve(tunnelIsUp: false);

      expect(repository.addressAsks, 1);
    });

    test('an answer is kept even when it names no country', () async {
      final repository = FakePurchaseRegionRepository(device: _berlin);

      await _service(repository).resolve(tunnelIsUp: false);

      expect(repository.kept, isNotNull);
      expect(repository.kept?.country, isNull);
    });

    test('a failure falls back to an old answer rather than to none', () async {
      final repository = FakePurchaseRegionRepository(
        device: _berlin,
        addressResult: left(const TimeoutFailure()),
        kept: AddressAnswer(
          country: 'IR',
          askedAt: _now.subtract(const Duration(days: 5)),
        ),
      );

      expect(
        await _service(repository).resolve(tunnelIsUp: false),
        PurchaseRegion.iran,
      );
      expect(repository.kept?.askedAt, isNot(_now), reason: 'not rewritten');
    });

    test('a device that places itself never writes anything', () async {
      final repository = FakePurchaseRegionRepository(
        device: _tehran,
        addressResult: right('IR'),
      );

      await _service(repository).resolve(tunnelIsUp: false);

      expect(repository.kept, isNull);
    });
  });
}
