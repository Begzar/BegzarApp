import 'package:begzar/modules/premium/data/dtos/premium_device_dto.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The roster arrives with the account, which promises less than a dedicated
/// devices answer would: no count of active devices, and no order. What the
/// app makes up for is asserted here.
void main() {
  BackendDevice device({String id = 'device', String? loggedInAt}) =>
      BackendDevice(
        deviceId: id,
        deviceName: 'Pixel 8',
        loggedInAt: loggedInAt,
      );

  LinkedDevices roster({
    List<BackendDevice> devices = const [],
    bool known = true,
    int? max,
  }) => PremiumDeviceDto.rosterFromBackend(
    BackendAccountData(
      account: const BackendAccount(username: 'u'),
      rosterKnown: known,
      devices: devices,
      maxDevices: max,
    ),
  );

  test('the newest sign-in comes first', () {
    final r = roster(
      devices: [
        device(id: 'older', loggedInAt: '2026-07-01T12:00:00Z'),
        device(id: 'newest', loggedInAt: '2026-09-01T12:00:00Z'),
        device(id: 'middle', loggedInAt: '2026-08-01T12:00:00Z'),
      ],
    );

    expect(r.devices.map((d) => d.deviceId), ['newest', 'middle', 'older']);
  });

  test('a device with no readable timestamp sorts last', () {
    final r = roster(
      devices: [
        device(id: 'undated'),
        device(id: 'unparsable', loggedInAt: 'whenever'),
        device(id: 'dated', loggedInAt: '2026-07-01T12:00:00Z'),
      ],
    );

    expect(r.devices.first.deviceId, 'dated');
    expect(
      r.devices.map((d) => d.deviceId).skip(1),
      containsAll(<String>['undated', 'unparsable']),
    );
  });

  test('a device the remove call could not name is dropped', () {
    final r = roster(
      devices: [
        device(id: ''),
        device(id: 'usable', loggedInAt: '2026-07-01T12:00:00Z'),
      ],
    );

    expect(r.devices.map((d) => d.deviceId), ['usable']);
  });

  test('a device the backend did not name is named for it', () {
    final r = PremiumDeviceDto.rosterFromBackend(
      const BackendAccountData(
        account: BackendAccount(username: 'u'),
        rosterKnown: true,
        devices: [BackendDevice(deviceId: 'one')],
      ),
    );

    expect(r.devices.single.deviceName, 'Unknown Device');
  });

  // The account sends a device limit but no active count, so the seat count
  // on load is the length of the list that came with it.
  test('the seat count falls back to the list it arrived with', () {
    final r = roster(
      max: 3,
      devices: [
        device(id: 'one'),
        device(id: 'two'),
      ],
    );

    expect(r.maxDevices, 3);
    expect(r.activeDevices, 2);
  });

  test('an answer with no devices reads as an empty roster', () {
    final r = roster(max: 2, known: false);

    expect(r.devices, isEmpty);
    expect(r.maxDevices, 2);
    expect(r.activeDevices, 0);
  });

  group('whether the roster was reported at all', () {
    test('should not claim a roster the answer did not carry', () {
      expect(roster(max: 2, known: false).rosterKnown, isFalse);
    });

    test('should claim a roster that was an empty list', () {
      expect(roster(max: 2).rosterKnown, isTrue);
    });

    test('should claim a roster that carried rows', () {
      expect(roster(devices: [device(id: 'one')]).rosterKnown, isTrue);
    });
  });

  group('LinkedDevices.registers', () {
    test('should report a device the roster lists as registered', () {
      final r = roster(
        devices: [
          device(id: 'this-device'),
          device(id: 'other'),
        ],
      );

      expect(r.registers('this-device'), isTrue);
    });

    test('should report a device the roster leaves out as unregistered', () {
      expect(
        roster(devices: [device(id: 'other')]).registers('this-device'),
        isFalse,
      );
    });

    test('should report an empty roster as registering nothing', () {
      expect(roster().registers('this-device'), isFalse);
    });

    // Absence is not removal: an answer that never mentioned devices says
    // nothing about which ones are registered.
    test('should report a device as registered when no roster was sent', () {
      expect(roster(max: 2, known: false).registers('this-device'), isTrue);
    });
  });
}
