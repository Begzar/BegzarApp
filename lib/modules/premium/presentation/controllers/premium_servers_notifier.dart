import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/application/services/premium_servers_service.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';

class PremiumServersNotifier extends Notifier<PremiumServersState> {
  late PremiumServersService _servers;
  int _pingGeneration = 0;

  @override
  PremiumServersState build() {
    _servers = ref.watch(premiumServersServiceProvider);
    // The list is entitlement-scoped data: signing out or losing the
    // subscription empties it, and gaining one fetches it.
    //
    // Loading used to be the view's call — the home screen asked for it when
    // the body swapped to the list, and dropped it on the way out. The list is
    // no longer a body, and the home row names its server out of this listing
    // whether or not anything has been opened, so what to hold is decided here
    // by the entitlement rather than by which widget happens to be mounted.
    ref.listen<bool>(premiumProvider.select((state) => state.isEntitled), (
      wasEntitled,
      isEntitled,
    ) {
      if (wasEntitled == true && !isEntitled) {
        reset();
        return;
      }
      if (isEntitled) _loadSoon();
    });
    _listenForConnectionChanges();

    // A session restored on launch is entitled before anything watches this,
    // so the listener above never fires for it.
    if (ref.read(premiumProvider).isEntitled) _loadSoon();

    return const PremiumServersState();
  }

  /// Loads after the current frame's build, since [load] publishes a loading
  /// state and nothing may be published from inside [build].
  void _loadSoon() {
    Future.microtask(() {
      if (ref.mounted) load();
    });
  }

  /// Keeps the list's idea of what is connected in step with the tunnel,
  /// including transitions the list did not start.
  ///
  /// This used to live in the list widget, which meant it only ran while the
  /// list was on screen: connect by hand and navigate away before it lands and
  /// the row never went active. Here it runs for as long as the provider does.
  ///
  /// A connect this list did not start sets no `connectingConfigId` — quick
  /// connect dials a shuffled flattening of every server's configs. That path
  /// resolves what landed and writes the pair before publishing `connected`,
  /// so the pair is on disk by the time this runs; [_adoptStoredLastConnected]
  /// picks it up.
  void _listenForConnectionChanges() {
    ref.listen(connectionProvider, (previous, next) {
      final connectingId = state.connectingConfigId;

      switch (next.status) {
        // In-flight real-delay probes share the Windows/Android engine
        // process with connect's live test. Bumping the generation drops
        // their results; LaunchEngine cancels the cores themselves.
        case ConnectionStatus.connecting:
          _pingGeneration++;
        // The config that was connecting is now the active one. Which server
        // it belongs to is resolved by setActiveConfig itself.
        case ConnectionStatus.connected when connectingId != null:
          setActiveConfig(connectingId);
        case ConnectionStatus.connected:
          _adoptStoredLastConnected();
        // setActiveConfig(null) clears the connecting config too.
        case ConnectionStatus.ready:
        case ConnectionStatus.error:
          setActiveConfig(null);
        case ConnectionStatus.disconnecting:
          setConnectingConfig(null);
      }
    });
  }

  /// Points the badge at whatever the last connect recorded, without going back
  /// to the network.
  ///
  /// The pair is read rather than resolved against [PremiumServersState.servers]
  /// because the list may never have been opened — the ids are the only thing
  /// that survives that, and the rows match on id.
  Future<void> _adoptStoredLastConnected() async {
    final pair = await _servers.readLastConnected();
    final label = await _servers.readLastConnectedLabel();
    if (pair == null || !ref.mounted) return;

    state = state.copyWith(
      activeConfigId: pair.configId,
      activeLabel: label,
      clearConnecting: true,
      lastConnectedServerId: pair.serverId,
      lastConnectedConfigId: pair.configId,
    );
  }

  void reset() {
    _pingGeneration++;
    state = PremiumServersState(
      lastConnectedServerId: state.lastConnectedServerId,
      lastConnectedConfigId: state.lastConnectedConfigId,
    );
  }

  void toggleExpanded(int serverId) {
    if (state.expandedServerId == serverId) {
      state = state.copyWith(clearExpanded: true);
      return;
    }
    state = state.copyWith(expandedServerId: serverId);
    _pingConfigsForServerId(serverId, userAsked: true);
  }

  void setConnectingConfig(int? configId) {
    if (configId == null) {
      state = state.copyWith(clearConnecting: true);
      return;
    }
    state = state.copyWith(connectingConfigId: configId);
  }

  /// The server in the loaded list that offers [configId], with that config,
  /// or null when the list does not hold it.
  (PremiumServer, PremiumServerConfig)? _offering(int configId) {
    for (final server in state.servers) {
      for (final config in server.configs) {
        if (config.id == configId) return (server, config);
      }
    }
    return null;
  }

  Future<void> setActiveConfig(int? configId) async {
    if (configId == null) {
      state = state.copyWith(clearActive: true, clearConnecting: true);
      return;
    }

    final offering = _offering(configId);

    state = state.copyWith(
      activeConfigId: configId,
      activeLabel: offering == null
          ? null
          : PremiumServerLabel.of(offering.$1, offering.$2),
      clearConnecting: true,
      lastConnectedConfigId: configId,
      lastConnectedServerId: offering?.$1.id,
    );

    if (offering != null) {
      await _servers.rememberLastConnected(offering.$1, offering.$2);
    }
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading) return;
    if (state.hasLoaded && !force && state.servers.isNotEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _servers.loadListing();
      if (result case Left(value: final failure)) {
        state = state.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: failure.userFacingKey,
        );
        return;
      }
      final listing = result.getOrElse((_) => throw StateError('no value'));

      state = PremiumServersState(
        isLoading: false,
        hasLoaded: true,
        servers: listing.servers,
        expandedServerId: listing.expandedServerId,
        connectingConfigId: state.connectingConfigId,
        activeConfigId: state.activeConfigId,
        activeLabel: state.activeLabel,
        lastConnectedServerId: listing.lastConnectedServerId,
        lastConnectedConfigId: listing.lastConnectedConfigId,
        pingByConfigId: state.pingByConfigId,
      );

      final expandedId = listing.expandedServerId;
      if (expandedId != null) {
        _pingConfigsForServerId(expandedId, userAsked: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        errorMessage: resolveUserFacingErrorKey(e),
      );
    }
  }

  void _pingConfigsForServerId(int serverId, {required bool userAsked}) {
    PremiumServer? server;
    for (final item in state.servers) {
      if (item.id == serverId) {
        server = item;
        break;
      }
    }
    if (server == null || server.configs.isEmpty) return;
    pingConfigs(server.configs, userAsked: userAsked);
  }

  /// Whether another app's VPN leaves the measurement free to run.
  ///
  /// A delay measured through someone else's tunnel is that tunnel's delay.
  /// When the user opened the server, Begzar turns the other VPN off first and
  /// says so, or refuses to measure while it stays on, unless the user chooses
  /// to go on with it on. The measurement that
  /// runs by itself after the list loads only checks: opening the tab is not
  /// asking for the other VPN to go.
  Future<bool> _clearOfOtherVpn({required bool userAsked}) async {
    final otherVpn = ref.read(otherVpnProvider.notifier);
    if (!userAsked) return !await otherVpn.isOn();
    return await otherVpn.clear() != OtherVpnVerdict.stillOn;
  }

  /// Measures [configs]' delays. [userAsked] is whether a tap asked for it,
  /// which decides what happens when another app's VPN is in the way — see
  /// [_clearOfOtherVpn].
  Future<void> pingConfigs(
    List<PremiumServerConfig> configs, {
    required bool userAsked,
  }) async {
    final status = ref.read(connectionProvider).status;
    if (status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting) {
      return;
    }

    if (!await _clearOfOtherVpn(userAsked: userAsked)) return;
    if (!ref.mounted) return;

    final generation = ++_pingGeneration;
    if (configs.isEmpty) return;

    final loadingMap = Map<int, ConfigPingState>.from(state.pingByConfigId);
    for (final config in configs) {
      loadingMap[config.id] = const ConfigPingState.loading();
    }
    state = state.copyWith(pingByConfigId: loadingMap);

    final List<int?> latencies;
    try {
      latencies = await _servers.measurePings(configs);
    } catch (_) {
      if (!ref.mounted || generation != _pingGeneration) return;
      final next = Map<int, ConfigPingState>.from(state.pingByConfigId);
      for (final config in configs) {
        next[config.id] = const ConfigPingState.failure();
      }
      state = state.copyWith(pingByConfigId: next);
      return;
    }
    if (!ref.mounted || generation != _pingGeneration) return;

    final next = Map<int, ConfigPingState>.from(state.pingByConfigId);
    for (var i = 0; i < configs.length; i++) {
      final ms = i < latencies.length ? latencies[i] : null;
      next[configs[i].id] = ms == null
          ? const ConfigPingState.failure()
          : ConfigPingState.success(ms);
    }
    state = state.copyWith(pingByConfigId: next);
  }
}

final premiumServersProvider =
    NotifierProvider<PremiumServersNotifier, PremiumServersState>(
      PremiumServersNotifier.new,
    );
