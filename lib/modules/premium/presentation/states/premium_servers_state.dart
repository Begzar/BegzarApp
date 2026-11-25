import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';

/// How far away one config's server measured, as its row shows it.
class ConfigPingState {
  final bool isLoading;
  final int? latencyMs;
  final bool failed;

  const ConfigPingState({
    this.isLoading = false,
    this.latencyMs,
    this.failed = false,
  });

  const ConfigPingState.loading() : this(isLoading: true);

  const ConfigPingState.success(int latencyMs) : this(latencyMs: latencyMs);

  const ConfigPingState.failure() : this(failed: true);

  bool get hasResult => !isLoading && (latencyMs != null || failed);

  /// Full antenna when under [_strongSignalCeilingMs], otherwise low.
  bool get isStrongSignal =>
      latencyMs != null && !failed && latencyMs! < _strongSignalCeilingMs;

  static const _strongSignalCeilingMs = 200;
}

/// The premium server list, and everything the list screen tracks about it.
///
/// Both kinds of state live here on purpose: what the server said
/// ([servers]), and what the user has done with it ([expandedServerId],
/// [connectingConfigId]). The screen needs them in one snapshot to decide
/// what each row looks like.
class PremiumServersState {
  final bool isLoading;
  final bool hasLoaded;
  final List<PremiumServer> servers;
  final String? errorMessage;
  final int? expandedServerId;
  final int? connectingConfigId;
  final int? activeConfigId;

  /// The names [activeConfigId] connected under, so the home row can still
  /// name it once a newer list no longer offers it.
  final PremiumServerLabel? activeLabel;

  /// The last config that connected, remembered across launches so the list
  /// can point the user back at what worked.
  final int? lastConnectedServerId;
  final int? lastConnectedConfigId;

  final Map<int, ConfigPingState> pingByConfigId;

  const PremiumServersState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.servers = const [],
    this.errorMessage,
    this.expandedServerId,
    this.connectingConfigId,
    this.activeConfigId,
    this.activeLabel,
    this.lastConnectedServerId,
    this.lastConnectedConfigId,
    this.pingByConfigId = const {},
  });

  ConfigPingState? pingFor(int configId) => pingByConfigId[configId];

  PremiumServersState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    List<PremiumServer>? servers,
    String? errorMessage,
    int? expandedServerId,
    int? connectingConfigId,
    int? activeConfigId,
    PremiumServerLabel? activeLabel,
    int? lastConnectedServerId,
    int? lastConnectedConfigId,
    Map<int, ConfigPingState>? pingByConfigId,
    bool clearError = false,
    bool clearExpanded = false,
    bool clearConnecting = false,
    bool clearActive = false,
    bool clearLastConnected = false,
  }) {
    return PremiumServersState(
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      servers: servers ?? this.servers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      expandedServerId: clearExpanded
          ? null
          : (expandedServerId ?? this.expandedServerId),
      connectingConfigId: clearConnecting
          ? null
          : (connectingConfigId ?? this.connectingConfigId),
      activeConfigId: clearActive
          ? null
          : (activeConfigId ?? this.activeConfigId),
      activeLabel: clearActive ? null : (activeLabel ?? this.activeLabel),
      lastConnectedServerId: clearLastConnected
          ? null
          : (lastConnectedServerId ?? this.lastConnectedServerId),
      lastConnectedConfigId: clearLastConnected
          ? null
          : (lastConnectedConfigId ?? this.lastConnectedConfigId),
      pingByConfigId: pingByConfigId ?? this.pingByConfigId,
    );
  }
}
