import 'dart:async';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/providers/connection_state_storage_provider.dart';
import 'package:begzar/modules/ads/presentation/states/connection_ad_gate_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs the countdown that holds the post-connect ad on screen.
class ConnectionAdGateNotifier extends Notifier<ConnectionAdGateState> {
  static const _log = Log('adgate');

  Timer? _timer;

  @override
  ConnectionAdGateState build() {
    ref.onDispose(_cancelTimer);
    return const ConnectionAdGateState();
  }

  void start({int seconds = 15}) {
    _cancelTimer();
    state = ConnectionAdGateState(
      isActive: true,
      canClose: false,
      remainingSeconds: seconds,
      forceClosed: false,
    );
    _persistActive(true);
    _startTimer();
  }

  void pause() {
    if (!state.isActive || state.canClose) return;
    _cancelTimer();
  }

  void resume() {
    if (!state.isActive || state.canClose || _timer != null) return;
    _startTimer();
  }

  void markOpenedAdClick() {
    if (!state.isActive || state.openedAdClick) return;
    state = state.copyWith(openedAdClick: true);
  }

  void clearOpenedAdClick() {
    if (!state.openedAdClick) return;
    state = state.copyWith(openedAdClick: false);
  }

  /// Tears the gate down, whatever brought it to an end.
  ///
  /// Called from the connect path's `finally`, so it runs on every exit: a
  /// wait served, a wait walked out of, and a connect that never had an ad to
  /// show. Only the first and last of those settle anything — a countdown
  /// still running when this arrives was cut short, and the flag it left
  /// behind is the whole record of that.
  void complete() {
    _cancelTimer();
    if (!_isUnserved) _persistActive(false);
    state = const ConnectionAdGateState();
  }

  /// The user left mid-ad and the tunnel is being taken back for it. The flag
  /// stays set on purpose: the disconnect that follows races an app on its way
  /// out, and if it loses, the next launch is what finishes the job.
  void forceClose() {
    _cancelTimer();
    state = const ConnectionAdGateState(forceClosed: true);
  }

  /// Whether the wait this gate was holding went unserved.
  ///
  /// [ConnectionAdGateState.forceClosed] has to count, not just a countdown
  /// caught mid-run. Backgrounding mid-ad dismisses the overlay before it
  /// force-closes, and the dismissal releases the connect path's `finally`
  /// into [complete] — which then arrives to find a gate that is no longer
  /// active and reads it as settled. On a real device that ordering held, and
  /// it cleared the flag half a second after the gate opened.
  bool get _isUnserved =>
      state.forceClosed || (state.isActive && !state.canClose);

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        _timer = null;
        // The wait is served. Whatever happens to the app from here, the next
        // launch must not treat this tunnel as one the user walked out on.
        _persistActive(false);
        state = state.copyWith(canClose: true, remainingSeconds: 0);
        return;
      }
      state = state.copyWith(remainingSeconds: next);
    });
  }

  /// Best-effort, and deliberately not awaited — a countdown may not wait on a
  /// keychain round trip.
  ///
  /// The clear is written twice on the path that matters: once when the
  /// countdown reaches zero and again from [complete] as the overlay closes. A
  /// set that never lands costs one skipped ad; a clear that never lands costs
  /// a user their tunnel after they sat through the whole thing, which is the
  /// worse of the two and the reason it gets the second attempt.
  void _persistActive(bool active) => unawaited(_writeActive(active));

  Future<void> _writeActive(bool active) async {
    try {
      await ref.read(connectionStateStorageProvider).setAdGateActive(active);
      _log.trace('flag', {'active': active});
    } catch (_) {
      // Storage that will not answer must not take the overlay down with it.
      _log.warn('flag.unwritable', {'active': active});
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final connectionAdGateProvider =
    NotifierProvider<ConnectionAdGateNotifier, ConnectionAdGateState>(
      ConnectionAdGateNotifier.new,
    );
