import 'package:begzar/modules/premium/domain/entities/premium_server.dart';

/// A fetched server list with the stored last-connected pair resolved
/// against it.
///
/// The resolution is a rule, not a lookup: the server the user last used may
/// be gone from the list, or still there with that config removed, and each
/// case changes what the list should highlight and open. Keeping it here
/// rather than in the notifier makes it something a test can state directly.
class PremiumServerListing {
  const PremiumServerListing({
    required this.servers,
    this.lastConnectedServerId,
    this.lastConnectedConfigId,
    this.expandedServerId,
  });

  final List<PremiumServer> servers;

  /// Null when the stored server is no longer offered.
  final int? lastConnectedServerId;

  /// Null when the stored config is gone, even if its server remains — the
  /// row it would mark does not exist any more.
  final int? lastConnectedConfigId;

  /// Which card opens on arrival: the one the user last connected through,
  /// or the first, so the list never opens with everything collapsed.
  final int? expandedServerId;

  factory PremiumServerListing.resolve({
    required List<PremiumServer> servers,
    ({int serverId, int configId})? lastConnected,
  }) {
    final matchedServer = _serverById(servers, lastConnected?.serverId);
    final lastConfigId = lastConnected?.configId;
    final configStillOffered =
        matchedServer != null &&
        lastConfigId != null &&
        matchedServer.configs.any((config) => config.id == lastConfigId);

    return PremiumServerListing(
      servers: servers,
      lastConnectedServerId: matchedServer?.id,
      lastConnectedConfigId: configStillOffered ? lastConfigId : null,
      expandedServerId:
          matchedServer?.id ?? (servers.isEmpty ? null : servers.first.id),
    );
  }

  static PremiumServer? _serverById(List<PremiumServer> servers, int? id) {
    if (id == null) return null;
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }
}
