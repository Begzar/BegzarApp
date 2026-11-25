import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/providers/connection_state_storage_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/ads/presentation/controllers/ad_skip_warning_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/tunnel_liveness_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';

/// Handles app lifecycle and live VPN health monitoring.
class ConnectionLifecycleHandler extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectionLifecycleHandler({super.key, required this.child});

  @override
  ConsumerState<ConnectionLifecycleHandler> createState() =>
      _ConnectionLifecycleHandlerState();
}

class _ConnectionLifecycleHandlerState
    extends ConsumerState<ConnectionLifecycleHandler>
    with WidgetsBindingObserver {
  static const _log = Log('adgate');
  static const _healthCheckInterval = Duration(seconds: 3);

  Timer? _healthCheckTimer;
  StreamSubscription<bool>? _vpnEventSubscription;
  StreamSubscription<void>? _tunnelLostSubscription;
  ProviderSubscription? _connectionSubscription;
  ProviderSubscription? _premiumSubscription;
  bool _monitoringStarted = false;
  bool _isCheckingAdSkipWarning = false;
  bool _isEnforcingAdGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMonitoring();
      _checkPendingAdSkipWarning();
    });
  }

  @override
  void dispose() {
    _stopHealthCheck();
    _vpnEventSubscription?.cancel();
    _tunnelLostSubscription?.cancel();
    _connectionSubscription?.close();
    _premiumSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.hidden:
        _handleAppBackgroundDuringAdGate();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _startMonitoring() async {
    if (_monitoringStarted) return;
    _monitoringStarted = true;

    final adapter = ref.read(proxyCoreAdapterProvider);
    await adapter.initialize(
      onEngineStateChanged: (isRunning) async {
        if (!isRunning && ref.read(connectionProvider).isActive) {
          await ref.read(connectionProvider.notifier).reconcileWithNative();
        }
      },
    );

    _vpnEventSubscription = adapter.watchVpnStatusEvents().listen((
      isRunning,
    ) async {
      if (!isRunning) {
        // Confirm with a real status probe — iOS can emit transient
        // "down" events while the NE tunnel is still connected.
        await ref.read(connectionProvider.notifier).reconcileWithNative();
      } else if (!ref.read(connectionProvider).isActive) {
        await ref.read(connectionProvider.notifier).reconcileWithNative();
      }
    }, onError: (_) {});

    // Windows only: the tunnel helper ended its lease on its own. Read once,
    // like the adapter above: the stream is the helper's, and the helper
    // lives for the app's whole run, so a service rebuilt on a language
    // change still hands out the same one.
    _tunnelLostSubscription = ref
        .read(connectionServiceProvider)
        .tunnelLost
        .listen((_) => ref.read(connectionProvider.notifier).endLostTunnel());

    _connectionSubscription = ref.listenManual(connectionProvider, (
      previous,
      next,
    ) {
      if (next.isActive && !(previous?.isActive ?? false)) {
        _startHealthCheck();
        if (next.adopted) unawaited(_enforceUnfinishedAdGate());
      } else if (!next.isActive && (previous?.isActive ?? false)) {
        _stopHealthCheck();
      }
    });

    _premiumSubscription = ref.listenManual(premiumProvider, (previous, next) {
      final wasRevoked = previous is PremiumSignedOut && previous.isRevoked;
      if (next is PremiumSignedOut && next.isRevoked && !wasRevoked) {
        unawaited(_dropTunnelForRevokedSession());
      }
    });

    if (ref.read(connectionProvider).isActive) {
      _startHealthCheck();
      unawaited(_enforceUnfinishedAdGate());
    }
  }

  /// Drops the tunnel when the server has taken this device's premium seat.
  ///
  /// A user who signs out keeps the connection they are already on; a seat
  /// removed from another device is not theirs to keep using, and the premium
  /// servers it is dialled into are exactly what the subscription paid for.
  /// The tunnel is dropped whichever servers it is on: nothing the connection
  /// carries says which list a config came from, and a free session outliving
  /// a revoked premium one is the cheaper mistake of the two.
  Future<void> _dropTunnelForRevokedSession() async {
    if (!mounted || !ref.read(connectionProvider).isActive) return;

    try {
      await ref.read(connectionProvider.notifier).disconnect();
    } catch (_) {}
  }

  /// Takes back a tunnel whose ad was never watched out.
  ///
  /// Backgrounding mid-ad is caught while the app is still running, but being
  /// killed is not caught at all — and the tunnel survives the process, so
  /// force-quitting was the one reliable way to keep a connection without
  /// watching anything. The gate writes down that it is running; a launch that
  /// adopts a live tunnel with that flag still set is looking at exactly that,
  /// and drops the tunnel the same way backgrounding would have.
  Future<void> _enforceUnfinishedAdGate() async {
    // Startup can reach this twice — the state may already be active when
    // monitoring starts, and then change again — and both would read the flag
    // before either cleared it.
    if (_isEnforcingAdGate || !mounted) return;
    _isEnforcingAdGate = true;
    _log.trace('enforce.check');

    try {
      final storage = ref.read(connectionStateStorageProvider);

      bool unfinished;
      try {
        unfinished = await storage.hasAdGateActive();
      } catch (_) {
        _log.warn('enforce.unreadable');
        return;
      }
      if (!unfinished || !mounted) {
        _log.trace('enforce.clear', {'unfinished': unfinished});
        return;
      }

      try {
        await storage.setAdGateActive(false);
      } catch (_) {}

      // Nobody exempt from ads can have earned this flag; theirs is left over
      // from before they were exempt, and clearing it is the whole penalty.
      if (!await _adsApplyToUser() || !mounted) {
        _log.trace('enforce.exempt');
        return;
      }
      if (!ref.read(connectionProvider).isActive) {
        _log.trace('enforce.nothingToTake');
        return;
      }

      _log.trace('enforce.reclaim');
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logPromotionAbandoned(cause: PromotionAbandonCause.relaunch),
      );
      ref.read(adSkipWarningPendingProvider.notifier).markPending();
      try {
        await storage.setAdSkipWarningPending(true);
      } catch (_) {}

      try {
        await ref.read(connectionProvider.notifier).disconnect();
      } catch (_) {}

      if (!mounted) return;
      await _checkPendingAdSkipWarning();
    } finally {
      _isEnforcingAdGate = false;
    }
  }

  /// Whether ads are this user's to see at all.
  ///
  /// The premium restore is waited on rather than read: at launch it has not
  /// landed yet, and an unfinished restore reads exactly like a free user.
  Future<bool> _adsApplyToUser() async {
    if (ref.read(settingsProvider.notifier).shouldBlockAds) return false;
    await ref.read(premiumProvider.notifier).ensureRestored();
    if (!mounted) return false;
    return !ref.read(premiumProvider).hasActiveSubscription;
  }

  void _startHealthCheck() {
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      ref.read(connectionProvider.notifier).reconcileWithNative();
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> _handleAppResumed() async {
    final gateNotifier = ref.read(connectionAdGateProvider.notifier);
    gateNotifier.resume();
    gateNotifier.clearOpenedAdClick();
    try {
      await ref.read(connectionProvider.notifier).reconcileWithNative();
    } catch (_) {}
    // Coming back to the app is when a person notices a tunnel that stopped
    // carrying traffic, so it is checked now rather than at the next tick.
    unawaited(ref.read(tunnelLivenessProvider.notifier).checkNow());
    await _checkPendingAdSkipWarning();
  }

  Future<void> _handleAppPaused() async {
    await _handleAppBackgroundDuringAdGate();
  }

  /// Records the ad on screen as walked out on.
  ///
  /// Android passes through hidden and then paused, and both run the
  /// background check; only the first finds the overlay still up, so one wait
  /// is recorded once.
  void _recordAbandonedInBackground() {
    final shown = ref.read(postConnectAdProvider)?.ad;
    if (shown == null) return;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logPromotionAbandoned(
            cause: PromotionAbandonCause.background,
            promotionId: shown.id,
            promotionName: shown.title,
            secondsLeft: ref.read(connectionAdGateProvider).remainingSeconds,
          ),
    );
  }

  Future<void> _handleAppBackgroundDuringAdGate() async {
    final gate = ref.read(connectionAdGateProvider);
    if (gate.isActive && !gate.canClose) {
      ref.read(connectionAdGateProvider.notifier).pause();
    }

    if (!gate.shouldPenalizeBackground(
      connectionActive: ref.read(connectionProvider).isActive,
    )) {
      return;
    }

    ref.read(adSkipWarningPendingProvider.notifier).markPending();
    try {
      await ref
          .read(connectionStateStorageProvider)
          .setAdSkipWarningPending(true);
    } catch (_) {}

    _recordAbandonedInBackground();
    ref.read(postConnectAdProvider.notifier).dismiss();
    ref.read(connectionAdGateProvider.notifier).forceClose();

    try {
      await ref.read(connectionProvider.notifier).disconnect();
    } catch (_) {}
  }

  Future<void> _checkPendingAdSkipWarning() async {
    if (_isCheckingAdSkipWarning || !mounted) return;
    _isCheckingAdSkipWarning = true;

    try {
      final inMemoryPending = ref.read(adSkipWarningPendingProvider);
      final storedPending = await ref
          .read(connectionStateStorageProvider)
          .hasAdSkipWarningPending();
      if ((!inMemoryPending && !storedPending) || !mounted) return;

      if (!await _adsApplyToUser()) {
        await _clearAdSkipWarningPending();
        return;
      }

      await _clearAdSkipWarningPending();
      if (!mounted) return;

      ref.read(adSkipWarningShowRequestProvider.notifier).request();
    } finally {
      _isCheckingAdSkipWarning = false;
    }
  }

  Future<void> _clearAdSkipWarningPending() async {
    ref.read(adSkipWarningPendingProvider.notifier).clear();
    try {
      await ref
          .read(connectionStateStorageProvider)
          .setAdSkipWarningPending(false);
    } catch (_) {}
  }

  Future<void> _handleAppDetached() async {
    await _handleAppBackgroundDuringAdGate();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
