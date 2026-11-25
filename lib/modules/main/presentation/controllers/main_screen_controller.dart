import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/app_update/domain/errors/update_required_exception.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drives the app's two ways of asking for a connect.
///
/// It owns the sequence — is a transition already in flight, is an update
/// forced, is another app's VPN in the way, is the account entitled, which of
/// the connect paths applies — and reports what happened. The widget is left
/// with turning that into a dialog.
///
/// Both askers go through the same gate. The home dial calls
/// [toggleConnection], which also has the disconnect and clear-the-error
/// meanings a single button has to carry; the premium list calls
/// [connectToConfig] with the config the user picked. They used to run the
/// sequence twice, written from each other rather than shared, and the copies
/// had already drifted.
class MainScreenController {
  static const _log = Log('connect');

  const MainScreenController(this._ref);

  final Ref _ref;

  /// The whole of what the connect button does, as one call.
  Future<ConnectTapOutcome> toggleConnection() async {
    _log.trace('toggle.tap', {
      'status': _ref.read(connectionProvider).status.name,
    });

    // The dial is the one control a person has while a connect runs, so a tap
    // on it then is how a connect that is taking too long gets called off.
    // Ahead of the gate, which refuses every other tap mid-transition.
    if (_ref.read(connectionProvider).status == ConnectionStatus.connecting) {
      _log.trace('toggle.cancel');
      await _ref.read(connectionProvider.notifier).cancelConnecting();
      return ConnectTapOutcome.cancelled;
    }

    final blocked = _blocked();
    if (blocked != null) {
      _log.trace('toggle.blocked', {'outcome': blocked.name});
      return blocked;
    }

    final status = _ref.read(connectionProvider).status;

    // The error is sticky until acknowledged, so the first tap after one
    // clears it rather than immediately retrying into the same failure.
    if (status == ConnectionStatus.error) {
      _log.trace('toggle.errorCleared');
      _ref.read(connectionProvider.notifier).clearError();
      return ConnectTapOutcome.errorCleared;
    }

    if (status == ConnectionStatus.connected) {
      _log.trace('toggle.disconnect');
      await stopConnection();
      return ConnectTapOutcome.disconnecting;
    }

    _log.trace('toggle.connect');
    return _gatedConnect(_startConnection);
  }

  /// Drops the tunnel up now and quick-connects again, as the dial would from
  /// ready: the free connect or the premium one, through the same gate.
  ///
  /// Offered for a tunnel that stopped carrying traffic. Quick connect probes
  /// before it dials, so a dead server is unlikely to be picked again, and for
  /// a free user this is a connect like any other, post-connect promotion
  /// included.
  Future<ConnectTapOutcome> switchServer() async {
    if (_ref.read(connectionProvider).status != ConnectionStatus.connected) {
      return ConnectTapOutcome.ignored;
    }
    _log.trace('switch');
    await stopConnection();
    return toggleConnection();
  }

  /// Connects to one config the user named, for the premium server list.
  ///
  /// The same gate as [toggleConnection], differing only in what it dials.
  /// Whether an already-connected tunnel should be dropped first is left to
  /// the list, because that answer depends on which config is active — the one
  /// part of the sequence that is genuinely the list's own.
  Future<ConnectTapOutcome> connectToConfig(ProxyConfigEntity config) {
    final blocked = _blocked();
    if (blocked != null) return Future.value(blocked);

    return _gatedConnect(
      () => _ref.read(connectionProvider.notifier).connect(config),
    );
  }

  /// What refuses the ask before anything else about it is decided. Null when
  /// nothing does.
  ConnectTapOutcome? _blocked() {
    // An ask mid-transition would start a second connect on top of the first,
    // or one while the tunnel is still coming down. Calling a connect off is
    // the dial's alone, and [toggleConnection] does it before reaching here.
    if (_ref.read(connectionProvider).status.isTransitional) {
      return ConnectTapOutcome.ignored;
    }

    // The update dialog blocks every path, so this refuses before touching the
    // connection at all.
    if (_ref.read(forceUpdateProvider).required) {
      return ConnectTapOutcome.updateRequired;
    }

    return null;
  }

  /// Gets another app's VPN out of quick connect's way, returning
  /// [ConnectTapOutcome.otherVpnOn] when it would not go and the user did not
  /// choose to go on with it on.
  ///
  /// The connection reads as connecting while the attempt runs — the network
  /// can take a few seconds to settle — so a tap on the dial meanwhile calls
  /// the connect off, as it does at any other step, and that comes back as
  /// [ConnectTapOutcome.cancelled] whatever the verdict. Whatever the verdict,
  /// the alert it raises is what tells the user.
  Future<ConnectTapOutcome?> _clearOtherVpn() async {
    final otherVpn = _ref.read(otherVpnProvider.notifier);
    if (!await otherVpn.isOn()) return null;

    final connection = _ref.read(connectionProvider.notifier);
    final isCancelled = connection.beginConnecting();
    final verdict = await otherVpn.clear();
    if (isCancelled()) return ConnectTapOutcome.cancelled;
    if (verdict != OtherVpnVerdict.stillOn) return null;

    connection.abortConnecting();
    return ConnectTapOutcome.otherVpnOn;
  }

  /// Clears another VPN out of the way, re-checks entitlement, then hands over
  /// to [dial].
  ///
  /// The other VPN goes first because it needs no server: a tap refused for it
  /// costs no entitlement request.
  ///
  /// [dial] reports its own failures on the connection state, so reaching
  /// [ConnectTapOutcome.connecting] means the attempt was made — not that it
  /// succeeded. The one exception it can raise is a version requirement the
  /// server only revealed once asked, which is a refusal rather than a failure.
  Future<ConnectTapOutcome> _gatedConnect(Future<void> Function() dial) async {
    final otherVpn = await _clearOtherVpn();
    if (otherVpn == ConnectTapOutcome.cancelled) {
      return ConnectTapOutcome.cancelled;
    }
    if (otherVpn != null) {
      _log.warn('gate.refused', {'outcome': otherVpn.name});
      return otherVpn;
    }

    final refusal = await _checkEntitlement();
    // The user withdrawing the ask is not the gate refusing it, and the check
    // has already traced it.
    if (refusal == ConnectTapOutcome.cancelled) {
      return ConnectTapOutcome.cancelled;
    }
    if (refusal != null) {
      _log.warn('gate.refused', {'outcome': refusal.name});
      return refusal;
    }

    try {
      await dial();
      _log.trace('gate.dialing');
      return ConnectTapOutcome.connecting;
    } on UpdateRequiredException catch (error) {
      _log.warn('gate.updateRequired');
      _markUpdateRequired(error);
      return ConnectTapOutcome.updateRequired;
    }
  }

  /// Re-checks the subscription with the server before a premium connect.
  ///
  /// Returns null when the connect may proceed — including for a free user,
  /// who has no entitlement to check. The connection is put into `connecting`
  /// for the duration so the button reads as busy while the server answers,
  /// and taken back out if the answer is no.
  ///
  /// A cancel while the server answers stops the connect too, and comes back
  /// as [ConnectTapOutcome.cancelled] whatever the server said. Its answer
  /// belongs to an ask the user withdrew, and acting on it would reach into
  /// whatever connect they asked for next.
  Future<ConnectTapOutcome?> _checkEntitlement() async {
    if (!_ref.read(premiumProvider).isEntitled) {
      _log.trace('entitlement.skipped', {'why': 'free path'});
      return null;
    }

    final connection = _ref.read(connectionProvider.notifier);
    final isCancelled = connection.beginConnecting();

    _log.trace('entitlement.recheck');
    final validation = await _ref
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    if (isCancelled()) {
      _log.trace('entitlement.cancelled', {'verdict': validation.name});
      return ConnectTapOutcome.cancelled;
    }

    _log.trace('entitlement.verdict', {'verdict': validation.name});
    if (validation == PremiumConnectValidation.allowed ||
        validation == PremiumConnectValidation.skipped) {
      return null;
    }

    connection.abortConnecting();
    return switch (validation) {
      PremiumConnectValidation.notLoggedIn ||
      PremiumConnectValidation.notSubscribed => ConnectTapOutcome.notEntitled,
      PremiumConnectValidation.subscriptionExpired =>
        ConnectTapOutcome.subscriptionExpired,
      PremiumConnectValidation.accountInactive =>
        ConnectTapOutcome.accountInactive,
      PremiumConnectValidation.checkFailed => ConnectTapOutcome.checkFailed,
      PremiumConnectValidation.allowed ||
      PremiumConnectValidation.skipped => null,
    };
  }

  /// Quick connect, with everything but a version requirement swallowed.
  ///
  /// The forced-update flag is already read by [_blocked]; what can still
  /// arrive here is the server naming a newer required version in the answer
  /// to this very request, which only this call can discover.
  Future<void> _startConnection() async {
    try {
      await _quickConnect();
    } on UpdateRequiredException {
      rethrow;
    } catch (_) {
      // Connection errors are reported via connectionProvider.
    }
  }

  /// Keyed on the subscription, not on which view the appbar is showing, so a
  /// paying user's connect button is always a premium quick connect.
  ///
  /// A free user with Experimental settings on connects on the WARP engine
  /// instead of Begzar's servers, where the platform has it built in. A
  /// subscriber never does: the switch only changes what a free connect
  /// dials. The stored choice is awaited, so a connect made the moment the
  /// app opens does not read the default before storage has answered.
  Future<void> _quickConnect() async {
    final connection = _ref.read(connectionProvider.notifier);
    final premium = _ref.read(premiumProvider).isEntitled;
    if (premium) {
      _log.trace('quickConnect', {'premium': true});
      await connection.connectWithPremium();
      return;
    }

    await _ref.read(settingsProvider.notifier).ensureLoaded();
    final preferences = _ref.read(settingsProvider);
    final warp =
        preferences.experimental && _ref.read(experimentalSupportedProvider);
    _log.trace('quickConnect', {'premium': false, 'warp': warp});
    if (warp) {
      await connection.connectWithWarp(preferences.warpMode);
      return;
    }
    await connection.connectWithApiV2();
  }

  Future<void> stopConnection() async {
    try {
      await _ref.read(connectionProvider.notifier).disconnect();
    } catch (_) {
      // Disconnect errors are reported via connectionProvider.
    }
  }

  Future<void> checkConnectionStatus() {
    return _ref.read(connectionProvider.notifier).reconcileWithNative();
  }

  void _markUpdateRequired(UpdateRequiredException error) {
    _ref
        .read(forceUpdateProvider.notifier)
        .markRequired(
          currentVersion: error.currentVersion,
          requiredVersion: error.requiredVersion,
          updateUrl: error.updateUrl,
        );
  }
}

/// The connect controller, shared by the home dial and the premium list. A
/// plain [Provider]: it holds no state of its own, and the empty state class it
/// used to publish said nothing.
final mainScreenProvider = Provider<MainScreenController>(
  MainScreenController.new,
);
