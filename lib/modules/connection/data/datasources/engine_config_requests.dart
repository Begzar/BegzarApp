import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter/foundation.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// What the engine is asked to build for [shareLink] under the app's settings.
///
/// The engine parses the link with the same parser its real-delay probes use
/// and writes the inbounds, DNS and routing rules around the outbound, so the
/// config a connect starts is built from the same reading of the link as the
/// one that measured it.
///
/// Both flags are for a tunnel in front of the engine that carries the
/// system's traffic and DNS into the SOCKS inbound. With [forwardTunnelDns],
/// DNS arriving there is sent to [dnsServer] through the proxy, whichever
/// resolver it was addressed to. [resolveServerOutsideTunnel] is for a tunnel
/// that would carry the engine's own lookups too: Xray resolves the server's
/// name through the DNS entry written for it, routed direct.
EngineConfigRequest engineConfigRequest({
  required String shareLink,
  int socksPort = 2080,
  String listenAddress = '127.0.0.1',
  String logLevel = 'warning',
  String dnsServer = '8.8.8.8',
  CustomRoutingRules customRouting = CustomRoutingRules.empty,
  AppRouting appRouting = AppRouting.none,
  int? httpPort,
  bool resolveServerOutsideTunnel = false,
  bool forwardTunnelDns = false,
}) {
  return EngineConfigRequest(
    shareLink: shareLink,
    socksPort: socksPort,
    listenAddress: listenAddress,
    logLevel: logLevel,
    dnsServer: dnsServer,
    directDomains: customRouting.directDomains,
    directIps: customRouting.directIps,
    blockDomains: customRouting.blockDomains,
    blockIps: customRouting.blockIps,
    proxyDomains: customRouting.proxyDomains,
    proxyIps: customRouting.proxyIps,
    appsBypassing: appRouting.bypassing,
    appsOnlyThrough: appRouting.onlyThrough,
    httpPort: httpPort,
    resolveServerOutsideTunnel: resolveServerOutsideTunnel,
    forwardTunnelDns: forwardTunnelDns,
  );
}

/// The engine config VPN mode asks for on [platform].
///
/// Android's VpnService and Apple's packet tunnel both hand every app's
/// traffic to the engine's SOCKS inbound, DNS included, addressed to the
/// public resolvers the tunnel names. The engine forwards each of those
/// queries to [dnsServer] through the proxy, so no fixed resolver has to be
/// reachable through every server.
///
/// Neither tunnel carries the engine's own traffic. Android leaves Begzar out
/// of its VpnService, and Apple sends a packet tunnel provider's own
/// connections and lookups around its tunnel. So the server is looked up and
/// dialled as it always was, through the system's resolver.
///
/// Windows and Linux have no VPN mode of their own: Windows's tunnel is proxy
/// mode with the helper in front. Their config is built as it always was.
EngineConfigRequest vpnModeEngineConfigRequest({
  required String shareLink,
  required TargetPlatform platform,
  String dnsServer = '8.8.8.8',
  CustomRoutingRules customRouting = CustomRoutingRules.empty,
}) {
  final tunnelCarriesSystemDns = switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS =>
      true,
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => false,
  };

  return engineConfigRequest(
    shareLink: shareLink,
    dnsServer: dnsServer,
    customRouting: customRouting,
    forwardTunnelDns: tunnelCarriesSystemDns,
  );
}
