import 'dart:ui';

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/repositories/purchase_region_repository.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_begzar_backend.dart';
import '../../../../support/memory_keyed_storage.dart';

/// Its own name, so a handler left behind by one test cannot answer for the
/// real channel in another file.
const _channel = MethodChannel('test/purchase_region/device_info');

void _answerChannel(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
}

PurchaseRegionRepository _repository({
  AppKeyedStorage? storage,
  FakeBegzarBackend? backend,
  Locale locale = const Locale('en', 'US'),
  Duration offset = const Duration(hours: 3, minutes: 30),
}) => PurchaseRegionRepository(
  storage: storage ?? MemoryKeyedStorage(),
  channel: _channel,
  utcOffset: () => offset,
  systemLocale: () => locale,
  backend: backend ?? FakeBegzarBackend(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading the device', () {
    test('takes the zone and both countries from the platform', () async {
      _answerChannel((call) async {
        expect(call.method, 'getRegionSignals');
        return {
          'timeZoneId': 'Asia/Tehran',
          'simCountry': 'ir',
          'networkCountry': ' ir ',
        };
      });

      final device = await _repository(
        locale: const Locale('fa', 'IR'),
      ).readDevice();

      expect(device.timeZoneId, 'Asia/Tehran');
      expect(device.simCountry, 'ir');
      expect(device.networkCountry, 'ir');
      expect(device.localeLanguage, 'fa');
      expect(device.localeRegion, 'IR');
      expect(device.utcOffset, const Duration(hours: 3, minutes: 30));
    });

    test('reads a blank country as no reading', () async {
      // What Android answers for a device with no SIM.
      _answerChannel(
        (_) async => {
          'timeZoneId': 'Europe/Berlin',
          'simCountry': '',
          'networkCountry': null,
        },
      );

      final device = await _repository().readDevice();

      expect(device.simCountry, isNull);
      expect(device.networkCountry, isNull);
    });

    test(
      'a platform with no handler still gives the clock and locale',
      () async {
        // No handler installed: the channel throws MissingPluginException, as
        // it does on every platform but Android.
        final device = await _repository(
          offset: const Duration(hours: 1),
          locale: const Locale('en', 'DE'),
        ).readDevice();

        expect(device.timeZoneId, isNull);
        expect(device.simCountry, isNull);
        expect(device.utcOffset, const Duration(hours: 1));
        expect(device.localeRegion, 'DE');
      },
    );

    test('a platform error reads as no reading, not a failure', () async {
      _answerChannel((_) async => throw PlatformException(code: 'boom'));

      final device = await _repository().readDevice();

      expect(device.timeZoneId, isNull);
    });
  });

  group('asking for the address', () {
    test('reads the country the backend places it in', () async {
      final backend = FakeBegzarBackend(
        onLookupRegionCountry: () async => const BackendAnswer('IR'),
      );

      final answer = await _repository(backend: backend).addressCountry();

      expect(answer.getRight().toNullable(), 'IR');
      expect(backend.calls, ['lookupRegionCountry']);
    });

    test('an answer without a country is a right of null', () async {
      final answer = await _repository(
        backend: FakeBegzarBackend(
          onLookupRegionCountry: () async => const BackendAnswer(null),
        ),
      ).addressCountry();

      expect(answer.isRight(), isTrue);
      expect(answer.getRight().toNullable(), isNull);
    });

    test('a refusal is a server failure', () async {
      final answer = await _repository(
        backend: FakeBegzarBackend(
          onLookupRegionCountry: () async => throw const BackendException(
            BackendFailureKind.server,
            message: 'Geo lookup refused',
            status: 500,
          ),
        ),
      ).addressCountry();

      expect(answer.getLeft().toNullable(), isA<ServerFailure>());
    });

    test('a timeout is a timeout failure', () async {
      final answer = await _repository(
        backend: FakeBegzarBackend(
          onLookupRegionCountry: () async =>
              throw const BackendException(BackendFailureKind.timeout),
        ),
      ).addressCountry();

      expect(answer.getLeft().toNullable(), isA<TimeoutFailure>());
    });

    test('a dead link is a network failure', () async {
      final answer = await _repository(
        backend: FakeBegzarBackend(),
      ).addressCountry();

      expect(answer.getLeft().toNullable(), isA<NetworkFailure>());
    });
  });

  group('keeping the answer', () {
    final askedAt = DateTime.utc(2026, 9, 26, 12);

    test('reads back what it kept', () async {
      final storage = MemoryKeyedStorage();

      await _repository(
        storage: storage,
      ).storeAddressAnswer(AddressAnswer(country: 'DE', askedAt: askedAt));
      final kept = await _repository(storage: storage).readAddressAnswer();

      expect(kept?.country, 'DE');
      expect(kept?.askedAt, askedAt);
    });

    test('keeps an answer that named no country', () async {
      final storage = MemoryKeyedStorage();

      await _repository(
        storage: storage,
      ).storeAddressAnswer(AddressAnswer(country: null, askedAt: askedAt));
      final kept = await _repository(storage: storage).readAddressAnswer();

      expect(kept, isNotNull);
      expect(kept?.country, isNull);
    });

    test('nothing kept reads as nothing', () async {
      expect(await _repository().readAddressAnswer(), isNull);
    });

    test('something unreadable reads as nothing kept', () async {
      for (final raw in [
        'not json',
        '[]',
        '{"country":"DE"}',
        '{"country":7,"at":"2026-09-26T12:00:00Z"}',
      ]) {
        final storage = MemoryKeyedStorage({'purchase_address_v1': raw});

        expect(
          await _repository(storage: storage).readAddressAnswer(),
          isNull,
          reason: raw,
        );
      }
    });

    test('storage that will not answer costs a request, not a crash', () async {
      final repository = _repository(storage: const FailingKeyedStorage());

      expect(await repository.readAddressAnswer(), isNull);
      await repository.storeAddressAnswer(
        AddressAnswer(country: 'DE', askedAt: askedAt),
      );
    });
  });
}
