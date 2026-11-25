import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendAccountData;

/// One device on an account's roster, as the engine listed it.
class PremiumDeviceDto {
  const PremiumDeviceDto({
    required this.deviceId,
    required this.deviceName,
    this.loggedInAt,
  });

  final String deviceId;
  final String deviceName;
  final String? loggedInAt;

  /// An unparsable timestamp becomes null rather than a failure: the row is
  /// still worth showing without its "signed in at" line.
  PremiumDevice toDomain() => PremiumDevice(
    deviceId: deviceId,
    deviceName: deviceName,
    loggedInAt: loggedInAt == null ? null : DateTime.tryParse(loggedInAt!),
  );

  /// The roster an engine answer carried: devices the remove call could not
  /// name dropped, the most recent sign-in first, and the counts falling back
  /// to the list when the answer gave none.
  static LinkedDevices rosterFromBackend(BackendAccountData data) {
    final devices =
        data.devices
            .map(
              (d) => PremiumDeviceDto(
                deviceId: d.deviceId,
                deviceName: d.deviceName ?? _fallbackName,
                loggedInAt: d.loggedInAt,
              ).toDomain(),
            )
            .where((device) => device.deviceId.isNotEmpty)
            .toList()
          ..sort(_newestFirst);
    return LinkedDevices(
      maxDevices: data.maxDevices ?? devices.length,
      activeDevices: data.activeDevices ?? devices.length,
      devices: devices,
      rosterKnown: data.rosterKnown,
    );
  }

  /// Most recent sign-in first, undated devices last.
  static int _newestFirst(PremiumDevice a, PremiumDevice b) {
    final left = a.loggedInAt;
    final right = b.loggedInAt;
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  static const _fallbackName = 'Unknown Device';
}
