import 'package:begzar/modules/premium/domain/entities/premium_device.dart';

/// The linked-devices section: the roster, and what is happening to it.
class PremiumDevicesState {
  final bool isLoading;
  final bool hasLoaded;
  final int? maxDevices;
  final int? activeDevices;
  final List<PremiumDevice> devices;

  /// This install's id, so the list can mark one row as "this device" and
  /// refuse to offer removing it.
  final String? currentDeviceId;

  final String? errorMessage;

  /// The device whose removal is in flight; only one runs at a time.
  final String? removingDeviceId;

  const PremiumDevicesState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.maxDevices,
    this.activeDevices,
    this.devices = const [],
    this.currentDeviceId,
    this.errorMessage,
    this.removingDeviceId,
  });

  PremiumDevicesState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    int? maxDevices,
    int? activeDevices,
    List<PremiumDevice>? devices,
    String? currentDeviceId,
    String? errorMessage,
    String? removingDeviceId,
    bool clearError = false,
    bool clearRemoving = false,
  }) {
    return PremiumDevicesState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      maxDevices: maxDevices ?? this.maxDevices,
      activeDevices: activeDevices ?? this.activeDevices,
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      removingDeviceId: clearRemoving
          ? null
          : (removingDeviceId ?? this.removingDeviceId),
    );
  }
}
