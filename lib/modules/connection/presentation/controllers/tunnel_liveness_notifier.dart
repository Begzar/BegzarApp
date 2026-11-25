import 'dart:async';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/tunnel_liveness.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checks a connected tunnel for traffic on [TunnelLiveness]'s schedule, and
/// publishes what the checks found.
///
/// The health check only asks whether the engine is running, so a server that
/// stops passing traffic would otherwise read as connected for as long as the
/// engine stays up. This runs beside it and never ends a tunnel: what to do
/// about a dead one is the user's to say.
class TunnelLivenessNotifier extends Notifier<TunnelLiveness> {
  static const _log = Log('connect');

  Timer? _nextCheck;

  /// A check in flight, so a resume landing on a timer's check does not run a
  /// second one beside it.
  bool _checking = false;

  bool get _connected => ref.read(connectionProvider).isActive;

  void _cancelNextCheck() {
    _nextCheck?.cancel();
    _nextCheck = null;
  }

  void _scheduleNextCheck() {
    _cancelNextCheck();
    _nextCheck = Timer(state.nextCheckIn, checkNow);
  }

  @override
  TunnelLiveness build() {
    ref.onDispose(_cancelNextCheck);
    ref.listen(connectionProvider, (previous, next) {
      final cameUp = next.isActive && !(previous?.isActive ?? false);
      if (cameUp) {
        state = const TunnelLiveness();
        _scheduleNextCheck();
      } else if (!next.isActive) {
        _cancelNextCheck();
        state = const TunnelLiveness();
      }
    });

    // A tunnel adopted before anything read this provider never shows it the
    // transition, so it starts checking here instead.
    if (_connected) {
      _nextCheck = Timer(TunnelLiveness.healthyInterval, checkNow);
    }
    return const TunnelLiveness();
  }

  /// Runs a check now instead of waiting for the next one, as returning to
  /// the app does. Nothing happens while no tunnel is up.
  Future<void> checkNow() async {
    if (_checking || !_connected) return;
    _checking = true;
    _cancelNextCheck();

    final passed = await ref.read(connectionServiceProvider).isPassingTraffic();
    _checking = false;
    // The tunnel may have gone while the check ran; its answer is then about
    // a connection that no longer exists.
    if (!ref.mounted || !_connected) return;

    final wasDead = state.isDead;
    state = state.after(passed: passed);
    if (state.isDead != wasDead) {
      _log.warn(state.isDead ? 'liveness.dead' : 'liveness.back');
    }
    _scheduleNextCheck();
  }
}

final tunnelLivenessProvider =
    NotifierProvider<TunnelLivenessNotifier, TunnelLiveness>(
      TunnelLivenessNotifier.new,
    );
