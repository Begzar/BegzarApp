// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// What [BegzarEngine.buildEngineConfig] turns into the complete Xray config: a
/// proxy share link and the settings the app decides around it.
///
/// The engine parses [shareLink] with the same parser the real-delay probes
/// use, then writes the inbounds, DNS and routing rules from the rest.
class EngineConfigRequest {
  const EngineConfigRequest({
    required this.shareLink,
    this.socksPort = 2080,
    this.listenAddress = '127.0.0.1',
    this.logLevel = 'warning',
    this.dnsServer = '8.8.8.8',
    this.directDomains = const [],
    this.directIps = const [],
    this.blockDomains = const [],
    this.blockIps = const [],
    this.proxyDomains = const [],
    this.proxyIps = const [],
    this.appsBypassing = const [],
    this.appsOnlyThrough = const [],
    this.httpPort,
    this.resolveServerOutsideTunnel = false,
    this.forwardTunnelDns = false,
  });

  /// A `vless://`, `vmess://`, `trojan://`, `ss://` or other share link. It
  /// carries the server's credentials, so it must never reach a log line.
  final String shareLink;

  final int socksPort;
  final String listenAddress;
  final String logLevel;

  /// The resolver the proxy server's own name, and with [forwardTunnelDns]
  /// every DNS query a tunnel hands over, is sent to.
  final String dnsServer;

  final List<String> directDomains;
  final List<String> directIps;
  final List<String> blockDomains;
  final List<String> blockIps;
  final List<String> proxyDomains;
  final List<String> proxyIps;

  /// The programs that skip the proxy, or the only ones that use it. At most
  /// one is non-empty.
  final List<String> appsBypassing;
  final List<String> appsOnlyThrough;

  /// The port of a local HTTP inbound beside the SOCKS one; null adds none.
  final int? httpPort;

  /// For a tunnel in front of the engine that would carry the engine's own
  /// lookups: the proxy server's name is resolved by Xray, routed direct.
  final bool resolveServerOutsideTunnel;

  /// For a tunnel that hands the system's DNS to the SOCKS inbound: those
  /// queries go to [dnsServer] through the proxy.
  final bool forwardTunnelDns;
  // Shapes only: the share link carries credentials.
  @override
  String toString() => 'EngineConfigRequest(scheme: ${_scheme(shareLink)}, '
      'socksPort: $socksPort, httpPort: $httpPort, '
      'apps: ${appsBypassing.length + appsOnlyThrough.length}, '
      'resolveServerOutsideTunnel: $resolveServerOutsideTunnel, '
      'forwardTunnelDns: $forwardTunnelDns)';

  static String _scheme(String link) {
    final end = link.indexOf('://');
    return end > 0 ? link.substring(0, end) : 'none';
  }
}
