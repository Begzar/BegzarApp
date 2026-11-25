import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/providers/api_provider.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:begzar/modules/connection/application/services/connection_service.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/premium/application/services/premium_servers_service.dart';
import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar/modules/app_update/application/services/app_version_enforcement.dart';
import 'package:begzar/modules/app_update/data/datasources/installed_build.dart';
import 'package:begzar/modules/app_update/domain/errors/update_required_exception.dart';
import 'package:begzar/modules/app_update/domain/version_comparison.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';

/// What one auto-connect attempt produced.
///
/// [serverVersion] is what the payload declared, echoed back to the caller that
/// asked for it. [landedOn] is the config that actually dialled — the list was
/// shuffled, so nobody upstream knows which one that was.
typedef _AutoConnectOutcome = ({
  String? serverVersion,
  ProxyConfigEntity? landedOn,
});

const _AutoConnectOutcome _autoConnectFailed = (
  serverVersion: null,
  landedOn: null,
);

/// Connection state, as the UI sees it.
///
/// This is the presentation layer's controller: it drives [ConnectionService]
/// and publishes what widgets read. Sole owner of connection state — the
/// repository remembers only the ports it bound and the Windows helper only
/// whether it carries the connection, neither keeps a status, and storage
/// keeps none either, so every transition a user sees originates here,
/// either from an operation this notifier performed or from
/// [reconcileWithNative], which asks the tunnel and believes the answer.
///
/// Errors are published as l10n keys, never as raw text: `errorMessage` on the
/// entity is always a [UserFacingErrorKeys] value.
class ConnectionNotifier extends Notifier<ConnectionEntity> {
  static const _log = Log('connect');

  late ConnectionService _service;
  ApiV2Service? _apiV2Service;
  PremiumServersService? _premiumServers;

  /// How many connects [cancelConnecting] has called off. A connect that
  /// started under an earlier count is one of them.
  int _cancellations = 0;

  @override
  ConnectionEntity build() {
    _service = ref.watch(connectionServiceProvider);
    _apiV2Service = ref.watch(apiV2ServiceProvider);
    _premiumServers = ref.watch(premiumServersServiceProvider);
    return ConnectionEntity.create();
  }

  /// Blocks connection when the install channel's required version is newer.
  ///
  /// Prefers the splash catalog entry for this install channel so a
  /// lagging store listing is not compared against a GitHub-only bump.
  Future<void> _enforceMinimumVersion(
    String? serverVersion, {
    String? updateUrl,
  }) async {
    final target = AppVersionEnforcement.target(
      fallbackVersion: serverVersion,
      fallbackUrl: updateUrl,
    );
    if (target == null) return;

    final current = await InstalledBuild.instance.version();
    if (compareVersions(current, target.version) >= 0) return;

    state = state.disconnected();
    throw UpdateRequiredException(
      currentVersion: current,
      requiredVersion: target.version,
      updateUrl: target.url,
    );
  }

  /// The state a live tunnel lands on, timed by the tunnel rather than by the
  /// moment this notifier got around to saying so.
  ///
  /// Every route into connected goes through here, not only the adopting one.
  /// The gap is minutes when a tunnel is adopted at startup and seconds when
  /// this app just dialled — a connect ends when the last probe comes back,
  /// and the tunnel it probed was already carrying traffic — but it is never
  /// zero, and the home screen counts a session from this. A platform with no
  /// answer falls back to now, which is what the entity does with a null.
  ///
  /// [adopted] separates the one route that did not dial — see
  /// `ConnectionEntity.adopted`.
  Future<ConnectionEntity> _connected({bool adopted = false}) async =>
      state.connected(at: await _service.tunnelStartedAt(), adopted: adopted);

  /// Puts the connection into connecting for one connect, and hands back how
  /// to ask whether [cancelConnecting] has since called it off.
  ///
  /// Every step of a connect awaits something, and a cancel can land during
  /// any of them, so each step asks once its await returns and drops what it
  /// learned rather than publishing it over the cancel.
  bool Function() _startConnecting() {
    final startedUnder = _cancellations;
    state = state.connecting();
    return () => startedUnder != _cancellations;
  }

  /// Clear error UI and return to idle/ready (e.g. after user dismisses failure).
  void clearError() {
    if (state.status == ConnectionStatus.error) {
      state = state.disconnected();
    }
  }

  /// Show connecting UI before async pre-connect work (e.g. premium validation).
  ///
  /// Returns how to ask whether the user has cancelled since, which the caller
  /// asks once that work returns — see [_startConnecting].
  bool Function() beginConnecting() {
    _log.trace('state.beginConnecting');
    return _startConnecting();
  }

  /// Calls off the connect in flight, at whatever step it has reached.
  ///
  /// The connection is back on ready at once rather than when the step under
  /// way returns. That step may be a probe or a server call that runs to its
  /// timeout, and waiting for it is exactly what the user is cancelling. A
  /// disconnect in flight is not a connect, and is left to finish.
  Future<void> cancelConnecting() async {
    if (state.status != ConnectionStatus.connecting) return;
    _log.trace('cancel');
    _cancellations++;
    state = state.disconnected();
    await _service.cancelConnect();
  }

  /// Revert to ready when pre-connect validation fails.
  void abortConnecting() {
    if (state.status == ConnectionStatus.connecting) {
      _log.trace('state.abortConnecting');
      state = state.disconnected();
    }
  }

  /// Publishes a connect that ended without a tunnel, and records it.
  ///
  /// Every connect failure comes through here, including the ones that happen
  /// before the service is reached, so the failure rate counts every way a
  /// connect can end short.
  void _failConnect(
    String key,
    ConnectSelection selection, {
    String? configName,
  }) {
    state = state.failed(key);
    _service.recordFailedConnect(key, selection, configName: configName);
  }

  /// Takes down a tunnel that went away on its own, and says so.
  ///
  /// Disconnecting is published before anything is awaited, so a second
  /// report of the same loss finds nothing active and ends nothing again: an
  /// engine that dies often takes the helper with it, and the health check
  /// and the helper's lease then both report it. No session length is handed
  /// over, because the user did not end this one. A disconnect that fails is
  /// only logged; what the user needs to hear is that the tunnel stopped.
  Future<void> _endTunnel() async {
    state = state.disconnecting();
    final result = await _service.disconnect();
    if (result case Left(value: final failure)) {
      _log.error('lost.disconnect.failed', {
        'reason': failure.runtimeType,
        'key': failure.userFacingKey,
      });
    }
    state = state.failed(UserFacingErrorKeys.tunnelStopped);
  }

  /// Publishes [connected] for a connect that landed, unless the Windows
  /// tunnel it brought up is already gone, and reports whether it did.
  ///
  /// The helper can go after saying it is ready and before this publish,
  /// which is several awaits later, and a loss reported in that gap found the
  /// connection still connecting and had nothing to end. So the repository
  /// is asked here, with nothing awaited between its answer and the publish:
  /// a helper gone before is caught by the question, and one gone after finds
  /// a connection for [endLostTunnel] to end. It is asked rather than
  /// remembered from a report, because a report that lands while connecting
  /// could come from a helper an earlier, called-off connect left behind,
  /// whereas the answer is about the helper this connect brought up. It is
  /// false for every connect the helper did not carry.
  ///
  /// [reconcileWithNative] adopts through here too: it also awaits between
  /// finding a tunnel up and saying so.
  Future<bool> _publishConnected(ConnectionEntity connected) async {
    if (_service.helperLost) {
      _log.warn('lost.beforeConnected');
      await _endTunnel();
      return false;
    }
    state = connected;
    return true;
  }

  /// Connect with specific config
  Future<void> connect(ProxyConfigEntity config) async {
    _log.trace('one', {
      'config': config.name,
      'scheme': Log.scheme(config.url),
    });
    final isCancelled = _startConnecting();
    final result = await _service.connect(config);
    // The service answers null only for a connect it was told to call off,
    // and [cancelConnecting] is what tells it.
    if (isCancelled() || result == null) return;

    if (result case Left(value: final failure)) {
      _log.error('one.failed', {
        'reason': failure.runtimeType,
        'key': failure.userFacingKey,
      });
      _failConnect(
        failure.userFacingKey,
        ConnectSelection.manual,
        configName: config.name,
      );
      return;
    }

    _log.trace('one.ok');
    final connected = await _connected();
    if (isCancelled()) return;
    await _publishConnected(connected);
  }

  /// Connect with auto config selection
  Future<void> connectAuto(List<ProxyConfigEntity> configs) async {
    _log.trace('auto', {'configs': configs.length});
    final isCancelled = _startConnecting();
    final result = await _service.connectAuto(configs);
    // See [connect] for why null needs nothing of its own.
    if (isCancelled() || result == null) return;

    if (result case Left(value: final failure)) {
      _log.error('auto.failed', {
        'reason': failure.runtimeType,
        'key': failure.userFacingKey,
      });
      _failConnect(failure.userFacingKey, ConnectSelection.auto);
      return;
    }

    _log.trace('auto.ok');
    final connected = await _connected();
    if (isCancelled()) return;
    await _publishConnected(connected);
  }

  /// How many of a subscription's dialable configs a free connect tries.
  ///
  /// The desktops try fewer configs than the mobile platforms: each failed dial
  /// costs a native round trip there, and a long list turns a bad network into
  /// a minute of spinning.
  static int get maxSubscriptionConfigs =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
      ? 10
      : 25;

  /// Connect using API v2 (fetch configs from server and auto-connect)
  Future<String?> connectWithApiV2() async {
    final apiV2Service = _apiV2Service;
    if (apiV2Service == null) {
      _log.error('free.unavailable');
      _failConnect(UserFacingErrorKeys.apiV2Unavailable, ConnectSelection.auto);
      return null;
    }

    _log.trace('free.start');
    final isCancelled = _startConnecting();

    final result = await apiV2Service.getVPNConfigurations();
    if (isCancelled()) return null;
    switch (result) {
      case Left(value: final failure):
        _log.error('free.fetchFailed', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        _failConnect(failure.userFacingKey, ConnectSelection.auto);
        return null;
      case Right(value: final payload):
        // Numbered before filtering, so a name keeps the server's position.
        final configs = proxyConfigsFromSubscription(payload.configUrls)
            .where(ProxyConfigValidator.isDialable)
            .take(maxSubscriptionConfigs)
            .toList();
        _log.trace('free.fetched', {
          'lines': payload.configUrls.length,
          'configs': configs.length,
        });
        if (configs.isEmpty) {
          _failConnect(
            UserFacingErrorKeys.noConfigsFromServer,
            ConnectSelection.auto,
          );
          return null;
        }

        final outcome = await _connectWithConfigs(
          configs,
          payload.serverVersion,
          isCancelled: isCancelled,
          updatedUrl: payload.updatedUrl,
        );
        return outcome.serverVersion;
    }
  }

  /// Quick connect for a free user with Experimental settings on: the WARP
  /// engine in [mode] instead of a server list.
  ///
  /// The same steps as every other connect around the dial: the build is
  /// version-gated first, and the tunnel lands on the same connected state,
  /// so the post-connect promotion gate and the session clock see an
  /// ordinary connect. A failure is recorded as a quick connect's would be.
  Future<void> connectWithWarp(WarpMode mode) async {
    _log.trace('warp.start', {'mode': mode.engineName});
    final isCancelled = _startConnecting();

    try {
      final latest = ReleaseHintBus.latest;
      await _enforceMinimumVersion(
        latest?.version,
        updateUrl: latest?.updatedUrl,
      );
      if (isCancelled()) return;
    } on UpdateRequiredException {
      _log.warn('gate.updateRequired');
      rethrow;
    } catch (e) {
      _log.error('gate.threw', {'type': e.runtimeType}, e);
      _failConnect(resolveUserFacingErrorKey(e), ConnectSelection.auto);
      return;
    }

    final result = await _service.connectWarp(mode);
    // See [connect] for why null needs nothing of its own.
    if (isCancelled() || result == null) return;

    if (result case Left(value: final failure)) {
      _log.error('warp.failed', {
        'reason': failure.runtimeType,
        'key': failure.userFacingKey,
      });
      _failConnect(failure.userFacingKey, ConnectSelection.auto);
      return;
    }

    _log.trace('warp.ok');
    final connected = await _connected();
    if (isCancelled()) return;
    await _publishConnected(connected);
  }

  /// Quick connect for premium: fetch the server list and auto-connect.
  ///
  /// Uses the same server list as the manual picker, so quick
  /// connect can never be rejected for a server the user could still pick by
  /// hand — the dedicated configs endpoint additionally enforced device
  /// registration and turned that mismatch into a connect failure.
  Future<String?> connectWithPremium() async {
    final premiumServers = _premiumServers;
    if (premiumServers == null) {
      _log.error('premium.unavailable');
      _failConnect(
        UserFacingErrorKeys.premiumApiUnavailable,
        ConnectSelection.auto,
      );
      return null;
    }

    _log.trace('premium.start');
    final isCancelled = _startConnecting();

    final result = await premiumServers.fetchServers();
    if (isCancelled()) return null;
    switch (result) {
      case Left(value: final failure):
        _log.error('premium.fetchFailed', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        _failConnect(failure.userFacingKey, ConnectSelection.auto);
        return null;
      case Right(value: final servers):
        final configs = [
          for (final server in servers)
            for (final config in server.configs)
              config.toProxyConfig(countryName: server.name),
        ];
        _log.trace('premium.fetched', {
          'servers': servers.length,
          'configs': configs.length,
        });
        if (configs.isEmpty) {
          _failConnect(
            UserFacingErrorKeys.noConfigsFromServer,
            ConnectSelection.auto,
          );
          return null;
        }

        final outcome = await _connectWithConfigs(
          configs,
          null,
          isCancelled: isCancelled,
          onLanded: (landedOn) =>
              _rememberPremiumLanding(premiumServers, servers, landedOn),
        );
        return outcome.serverVersion;
    }
  }

  /// Version-gate, auto-connect, and publish state for fetched configs.
  ///
  /// [_AutoConnectOutcome.landedOn] is null on every path that did not land:
  /// a failure, whose reason is already published on [state], or a cancel. So
  /// callers only ever read it to find out *where* a successful connect ended
  /// up.
  ///
  /// [isCancelled] is the one [_startConnecting] handed the caller, so a cancel
  /// that landed before this was reached still counts here.
  ///
  /// [onLanded] runs after the tunnel is up but *before* the connected status
  /// is published. The ordering is the point: whatever the premium list learns
  /// from the connected status has to be able to see what this connect wrote.
  Future<_AutoConnectOutcome> _connectWithConfigs(
    List<ProxyConfigEntity> configs,
    String? serverVersion, {
    required bool Function() isCancelled,
    String? updatedUrl,
    Future<void> Function(ProxyConfigEntity landedOn)? onLanded,
  }) async {
    try {
      await _enforceMinimumVersion(
        serverVersion ?? ReleaseHintBus.latest?.version,
        updateUrl: updatedUrl ?? ReleaseHintBus.latest?.updatedUrl,
      );
      if (isCancelled()) return _autoConnectFailed;
    } on UpdateRequiredException {
      _log.warn('gate.updateRequired');
      rethrow;
    } catch (e) {
      _log.error('gate.threw', {'type': e.runtimeType}, e);
      _failConnect(resolveUserFacingErrorKey(e), ConnectSelection.auto);
      return _autoConnectFailed;
    }

    _log.trace('configs.auto', {'configs': configs.length});
    final result = await _service.connectAuto(configs);
    if (isCancelled()) return _autoConnectFailed;
    switch (result) {
      // See [connect] for why null needs nothing of its own.
      case null:
        return _autoConnectFailed;
      case Left(value: final failure):
        _log.error('configs.failed', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        _failConnect(failure.userFacingKey, ConnectSelection.auto);
        return _autoConnectFailed;
      case Right(value: final landedOn):
        _log.trace('configs.ok', {
          'config': landedOn.name,
          'scheme': Log.scheme(landedOn.url),
        });
        await onLanded?.call(landedOn);
        final connected = await _connected();
        if (isCancelled()) return _autoConnectFailed;
        if (!await _publishConnected(connected)) return _autoConnectFailed;
        return (serverVersion: serverVersion, landedOn: landedOn);
    }
  }

  /// Records which premium config quick connect landed on, so the list's
  /// last-connected badge points at what actually dialled.
  ///
  /// Resolved here rather than in the list's own controller because quick
  /// connect is reachable without ever opening the list — and a controller
  /// holding no servers cannot turn a config URL into the server/config pair
  /// storage keeps. This connect already fetched the list, so it is the one
  /// place that can answer.
  ///
  /// Written through [PremiumServersService] rather than through the list's
  /// notifier on purpose: that notifier listens to this one, so reading it here
  /// closes a loop Riverpod rejects as a circular dependency. Storage is the
  /// handoff instead, and the list adopts the pair when it sees the tunnel come
  /// up.
  Future<void> _rememberPremiumLanding(
    PremiumServersService premiumServers,
    List<PremiumServer> servers,
    ProxyConfigEntity landedOn,
  ) async {
    for (final server in servers) {
      for (final config in server.configs) {
        if (config.url != landedOn.url) continue;
        await premiumServers.rememberLastConnected(server, config);
        return;
      }
    }
  }

  /// Disconnect
  ///
  /// The session's length is read before the state leaves connected. A second
  /// call for the same tunnel finds it already disconnecting, has no session
  /// to hand over, and so ends nothing a second time in analytics.
  Future<void> disconnect() async {
    _log.trace('disconnect');
    final connectedFor = state.connectionDuration;
    state = state.disconnecting();
    final result = await _service.disconnect(connectedFor: connectedFor);
    state = result.match(
      (failure) {
        _log.error('disconnect.failed', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        return state.failed(failure.userFacingKey);
      },
      (_) {
        _log.trace('disconnect.ok');
        return state.disconnected();
      },
    );
  }

  /// Ends the connection when the Windows tunnel goes away without a
  /// disconnect asking for it: its helper exited, was killed, or its tunnel
  /// failed.
  ///
  /// Only a connection that is up has anything to end. One still connecting
  /// is caught where it publishes connected, and one already going down or
  /// failed has been dealt with.
  Future<void> endLostTunnel() async {
    if (!state.isActive) return;
    _log.warn('lost');
    await _endTunnel();
  }

  /// Align state with the native tunnel, the only external source of truth.
  ///
  /// Startup, lifecycle resume, the health-check timer and native VPN status
  /// events all land here, so no caller can publish a connection state of its
  /// own devising.
  Future<void> reconcileWithNative() async {
    try {
      // A connect the user called off may have a dial still landing, and the
      // tunnel it brings up stands until that connect takes it back down.
      // Asking before then would adopt it as a connection.
      await _service.settleCancelledConnect();

      // While auto-connect is still testing configs the tunnel may already be
      // up. Promoting now would fire the post-connect ad before a working
      // config has been chosen.
      if (state.status.isTransitional) {
        _log.trace('reconcile.skipped', {'status': state.status.name});
        return;
      }

      final isActive = await _service.isConnectionActive();
      if (isActive &&
          !state.isActive &&
          state.status != ConnectionStatus.error) {
        _log.trace('reconcile.adopt', {'native': 'up'});
        await _publishConnected(await _connected(adopted: true));
      } else if (!isActive && state.isActive) {
        // Behind the Windows helper, the engine going is not the end of it:
        // the helper's tunnel still takes every app's traffic, into a port
        // nothing answers on, and the machine has no network while the app
        // reads disconnected. So that connection ends as a lost tunnel does,
        // which stops the helper first. Any other is only marked down.
        if (_service.connectedThroughHelper) {
          _log.warn('reconcile.tunnelDown');
          await endLostTunnel();
        } else {
          _log.trace('reconcile.adopt', {'native': 'down'});
          state = state.disconnected();
        }
      }
    } catch (_) {
      // A failed probe is not evidence the tunnel changed; leave state alone.
    }
  }

  /// Measures the round trip through the tunnel.
  ///
  /// The result is both published on the state and handed back, so a caller
  /// that drives the measurement can show what it got without having to
  /// watch for the change it just caused.
  Future<PingResult> measurePing([List<String>? urls]) async {
    try {
      final result = await _service.measurePing(urls);
      state = state.withPingResult(result);
      return result;
    } catch (_) {
      // A probe that threw is a failed measurement, not a connection state
      // change: the tunnel is reported exactly as it was.
      return PingResult.failure(pingFailedKey);
    }
  }

  /// Error key for a measurement that could not complete. Resolved through
  /// the same localization path as every other connection error key.
  static const pingFailedKey = 'ping_failed';

  /// Reset to initial state
  void reset() {
    state = ConnectionEntity.create();
  }
}

/// Connection state for the UI. This is the provider widgets read.
final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionEntity>(
      ConnectionNotifier.new,
    );
