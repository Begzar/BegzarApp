import 'package:flutter/material.dart';

import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';

/// Why the home server row is making an offer instead of naming a config.
enum HomeSurfaceLapse { none, notSubscribed, expired, inactive }

HomeSurfaceLapse homeSurfaceLapse(PremiumState state) {
  if (state.isEntitled) return HomeSurfaceLapse.none;

  final account = state.account;
  if (account == null) return HomeSurfaceLapse.notSubscribed;
  if (!account.status.isActive) return HomeSurfaceLapse.inactive;
  if (account.neverSubscribed) return HomeSurfaceLapse.notSubscribed;
  return HomeSurfaceLapse.expired;
}

/// A server and one of its configs, as the home server row names them.
class HomeSurfaceChoice {
  const HomeSurfaceChoice({
    required this.configId,
    required this.serverName,
    required this.configName,
    required this.flagCode,
    this.withdrawn = false,
  });

  final int configId;
  final String serverName;
  final String configName;
  final String? flagCode;

  /// The tunnel is still up on this config, but the list fetched since no
  /// longer offers it.
  final bool withdrawn;
}

/// The config the home server row names, and the server it belongs to, or
/// null while the row is making an offer or names nothing.
///
/// Only a config that is connected, or dialling from the list, is named. The
/// dial quick-connects across every server, so the one connected last is not
/// what a tap would use, and naming it would read as a choice already made.
///
/// A connected config the list does not hold is named from the label stored
/// when it connected. It is [HomeSurfaceChoice.withdrawn] only once a list
/// has loaded without it: a list still on its way, or one that failed, says
/// nothing about whether the server is still offered.
///
/// The IP reading takes its flag from the same answer, so the two cards
/// cannot show different countries for one tunnel.
HomeSurfaceChoice? homeSurfaceChoice(
  PremiumState premium,
  PremiumServersState servers,
) {
  if (homeSurfaceLapse(premium) != HomeSurfaceLapse.none) return null;

  final configId = servers.activeConfigId ?? servers.connectingConfigId;
  if (configId == null) return null;

  for (final server in servers.servers) {
    for (final config in server.configs) {
      if (config.id == configId) {
        return HomeSurfaceChoice(
          configId: config.id,
          serverName: server.name,
          configName: config.name,
          flagCode: server.flagCode,
        );
      }
    }
  }

  final label = servers.activeLabel;
  if (label == null || configId != servers.activeConfigId) return null;
  return HomeSurfaceChoice(
    configId: configId,
    serverName: label.serverName,
    configName: label.configName,
    flagCode: label.flagCode,
    withdrawn: servers.hasLoaded && servers.errorMessage == null,
  );
}

/// The tint both the server row and the IP reading draw their glass from.
Color homeSurfaceBorderColor(
  PremiumPalette palette, {
  required PremiumState premium,
  required PremiumServersState servers,
  required ConnectionStatus status,
}) {
  const live = PremiumPalette.liveAlpha;
  final lapse = homeSurfaceLapse(premium);

  return switch (lapse) {
    HomeSurfaceLapse.notSubscribed => palette.offerBuy.withValues(alpha: live),
    HomeSurfaceLapse.expired => palette.offerRenew.withValues(alpha: live),
    HomeSurfaceLapse.inactive => palette.offerRestore.withValues(alpha: live),
    HomeSurfaceLapse.none when status == ConnectionStatus.connecting =>
      palette.amber.withValues(alpha: live),
    HomeSurfaceLapse.none when servers.activeConfigId != null =>
      palette.blue.withValues(alpha: live),
    // The config connected last earns no tint: the dial will not use it, so a
    // tinted surface would read as a server still picked.
    HomeSurfaceLapse.none => palette.border,
  };
}

/// The server row's own tint: the warning ink while it names a server the
/// list has dropped, the shared surface tint otherwise.
///
/// The IP reading keeps the shared tint even then: the tunnel it reports on is
/// still up, and only the row asks for something to be done.
Color homeServerRowBorderColor(
  PremiumPalette palette, {
  required PremiumState premium,
  required PremiumServersState servers,
  required ConnectionStatus status,
}) {
  if (homeSurfaceChoice(premium, servers)?.withdrawn ?? false) {
    return palette.amberInk.withValues(alpha: PremiumPalette.liveAlpha);
  }
  return homeSurfaceBorderColor(
    palette,
    premium: premium,
    servers: servers,
    status: status,
  );
}
