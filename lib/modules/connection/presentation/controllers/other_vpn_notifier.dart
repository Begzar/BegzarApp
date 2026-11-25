import 'dart:async';

import 'package:begzar/modules/connection/application/services/connection_service.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something about another VPN the user has to be told.
///
/// [serial] tells two alerts with the same verdict apart, so a second tap on a
/// VPN that is still on raises the warning a second time instead of being
/// filtered out as nothing new.
typedef OtherVpnAlert = ({OtherVpnVerdict verdict, int serial});

/// Clears another app's VPN out of the way of a measurement, and publishes
/// what the user has to be told about it.
///
/// Two places ask: the connect gate, before quick connect probes, and the
/// premium list, before it measures a server the user opened. The state is the
/// latest alert, and one listener on the root screen turns it into the notice
/// or the warning, so both askers share one surface — the list's measurement
/// has no tap outcome to carry it.
class OtherVpnNotifier extends Notifier<OtherVpnAlert?> {
  late ConnectionService _service;
  int _serial = 0;

  /// What the warning on screen will answer, while one is.
  Completer<bool>? _goAnyway;

  @override
  OtherVpnAlert? build() {
    _service = ref.watch(connectionServiceProvider);
    // A warning nobody can answer any more holds its asker open for good.
    ref.onDispose(() => answerWarning(goAnyway: false));
    return null;
  }

  /// Turns another VPN off where it can, raises an alert unless there was
  /// none, and hands the verdict back so the caller knows whether to go on.
  ///
  /// A VPN that stayed on raises the warning, and the verdict waits for its
  /// answer: [OtherVpnVerdict.overridden] when the user goes on anyway,
  /// [OtherVpnVerdict.stillOn] for any other way out.
  Future<OtherVpnVerdict> clear() async {
    final verdict = await _service.clearOtherVpn();
    if (verdict == OtherVpnVerdict.none || !ref.mounted) return verdict;
    if (verdict != OtherVpnVerdict.stillOn) {
      state = (verdict: verdict, serial: ++_serial);
      return verdict;
    }

    // Only one warning is on screen at a time; an earlier ask still waiting
    // on one is answered no rather than left open.
    answerWarning(goAnyway: false);
    final goAnyway = _goAnyway = Completer<bool>();
    // Set before the state, since a listener may answer as it is raised.
    state = (verdict: verdict, serial: ++_serial);
    return await goAnyway.future
        ? OtherVpnVerdict.overridden
        : OtherVpnVerdict.stillOn;
  }

  /// The user's answer to the warning: [goAnyway] when they chose to go on
  /// with the other VPN on. Nothing happens when no warning is waiting.
  void answerWarning({required bool goAnyway}) {
    final pending = _goAnyway;
    _goAnyway = null;
    if (pending != null && !pending.isCompleted) pending.complete(goAnyway);
  }

  /// Whether another VPN is on, for an asker that must not turn it off.
  Future<bool> isOn() => _service.isOtherVpnOn();

  /// Opens the system's VPN settings, for the warning's button.
  Future<void> openSettings() async {
    await _service.openVpnSettings();
  }
}

final otherVpnProvider = NotifierProvider<OtherVpnNotifier, OtherVpnAlert?>(
  OtherVpnNotifier.new,
);
