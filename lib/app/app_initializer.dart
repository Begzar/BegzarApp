import 'dart:async';

import 'package:begzar/app/analytics_user_properties.dart';
import 'package:begzar/app/app_bootstrap.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/providers/macos_keychain_ready_provider.dart';
import 'package:begzar/modules/ads/di/ads_providers.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/app_update/presentation/controllers/startup_update_gate.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/play_purchase_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Restores VPN UI state without blocking first paint.
///
/// The tunnel is the only thing asked; nothing is read back from storage.
final appInitializationProvider = FutureProvider<void>((ref) async {
  // Fired, not awaited. The version check can take up to its own timeout, and
  // nothing on screen depends on the answer: a build that is too old is
  // announced on `forceUpdateProvider`, and the home screen raises the dialog
  // from there whenever that lands.
  unawaited(ref.read(startupUpdateGateProvider).run());

  // Before anything is awaited, so the first events of the run already carry
  // the channel, and the tier once the stored session has been read.
  ref.read(analyticsUserPropertiesProvider);

  await Future.wait([
    ref.read(localeProvider.notifier).ensureLoaded(),
    ref.read(settingsProvider.notifier).ensureLoaded(),
    ref.read(appRoutingProvider.notifier).ensureLoaded(),
    ref.read(customRoutingProvider.notifier).ensureLoaded(),
  ]);

  await ref.read(connectionProvider.notifier).reconcileWithNative();

  // After the reconcile, not beside it: whether the tunnel is up decides
  // whether the address can be asked. Fired, not awaited — nothing on screen
  // waits for it.
  unawaited(ref.read(premiumPurchaseLauncherProvider).warm());

  // A Play build listens for purchases from launch, not from the paywall: a
  // payment can clear while the app is closed, and Play hands an unfinished
  // one back only to a listener.
  if (ref.read(appDistributionSourceProvider) ==
      AppDistributionSource.googlePlay) {
    ref.read(playPurchaseProvider);
  }
});

/// Boots deferred services and VPN state sync without blocking UI.
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _deferredStarted = false;

  void _startDeferredIfReady(bool ready) {
    if (!ready || _deferredStarted) return;
    _deferredStarted = true;
    AppBootstrap.startDeferredInitialization(
      ref.read(connectionAdHandlerProvider),
      ref.read(analyticsServiceProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keychainReady = ref.watch(macOsKeychainReadyProvider);
    _startDeferredIfReady(keychainReady);

    if (keychainReady) {
      ref.watch(appInitializationProvider);
    }
    return widget.child;
  }
}
