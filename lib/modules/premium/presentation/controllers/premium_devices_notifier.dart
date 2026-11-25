import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/application/services/premium_account_service.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_devices_state.dart';

class PremiumDevicesNotifier extends Notifier<PremiumDevicesState> {
  late PremiumAccountService _accounts;

  @override
  PremiumDevicesState build() {
    _accounts = ref.watch(premiumAccountServiceProvider);
    return const PremiumDevicesState();
  }

  void reset() {
    state = const PremiumDevicesState();
  }

  Future<void> loadIfNeeded({bool force = false}) async {
    if (state.isLoading) return;
    if (state.hasLoaded && !force) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final deviceId = await _accounts.currentDeviceId();
      final devicesResult = await _accounts.fetchDevices();
      switch (devicesResult) {
        case Left(value: final failure):
          state = state.copyWith(
            isLoading: false,
            hasLoaded: true,
            errorMessage: failure.userFacingKey,
          );
          // This refresh is the same one the subscription card makes, so it is
          // as likely to be the call that finds the seat gone. The stored
          // session is already cleared by the time the answer arrives here.
          if (failure is SessionRevokedFailure) {
            ref.read(premiumProvider.notifier).endRevokedSession();
          }
        case Right(value: final result):
          state = state.copyWith(
            isLoading: false,
            hasLoaded: true,
            maxDevices: result.maxDevices,
            activeDevices: result.activeDevices,
            devices: result.devices,
            currentDeviceId: deviceId,
            clearError: true,
          );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        errorMessage: resolveUserFacingErrorKey(e),
      );
    }
  }

  /// Unlinks [deviceId] from the subscription.
  ///
  /// Returns why it was refused, as an l10n key, or null once it is done. The
  /// row that asked reports a refusal in the error toast, so it stays off
  /// [PremiumDevicesState.errorMessage]: that is what the list says about
  /// loading, and a removal kept there printed again above the list.
  Future<String?> removeDevice(String deviceId) async {
    if (state.removingDeviceId != null) return UserFacingErrorKeys.removeDevice;

    state = state.copyWith(removingDeviceId: deviceId, clearError: true);

    try {
      final removeResult = await _accounts.removeDevice(deviceId);
      switch (removeResult) {
        case Left(value: final failure):
          state = state.copyWith(clearRemoving: true);
          return failure.userFacingKey;
        case Right(value: final activeDevices):
          final updated = state.devices
              .where((device) => device.deviceId != deviceId)
              .toList();
          state = state.copyWith(
            devices: updated,
            activeDevices: activeDevices,
            clearRemoving: true,
            clearError: true,
          );
          return null;
      }
    } catch (e) {
      state = state.copyWith(clearRemoving: true);
      return resolveUserFacingErrorKey(e);
    }
  }
}

final premiumDevicesProvider =
    NotifierProvider<PremiumDevicesNotifier, PremiumDevicesState>(
      PremiumDevicesNotifier.new,
    );
