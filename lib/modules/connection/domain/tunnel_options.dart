import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';

/// Everything the engine needs from the user's settings to bring a tunnel up.
///
/// The repository used to read these straight out of the Riverpod container,
/// which coupled the data layer to three other modules' providers and made it
/// impossible to construct without one. Assembling them is the job of whoever
/// owns the container; the repository just receives the answer.
class TunnelOptions {
  const TunnelOptions({
    required this.dnsServer,
    required this.proxyOnly,
    required this.systemProxy,
    required this.listenAddress,
    required this.customRouting,
    required this.appRouting,
  });

  /// DNS the engine resolves through.
  final String dnsServer;

  /// Run as a local proxy instead of capturing all traffic.
  final bool proxyOnly;

  /// Windows only: point the system proxy at the engine's HTTP port.
  final bool systemProxy;

  /// Loopback, or every interface when the device acts as a LAN gateway.
  final String listenAddress;

  final CustomRoutingRules customRouting;

  /// Which apps the tunnel carries. Already resolved: [AppRouting.none] means
  /// "every app", whether the feature is off or simply unused.
  final AppRouting appRouting;

  /// Neither proxy mode was chosen, so the user asked for a tunnel that
  /// carries every app. Whether one opens is the platform's call: Windows has
  /// one only through its tunnel helper, and Linux has none.
  bool get wantsTunnel => !proxyOnly && !systemProxy;
}
