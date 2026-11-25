import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';

/// How the engine carries the device's traffic.
enum ExposureMode {
  /// The engine captures every app's traffic itself, through the platform's
  /// VPN where the platform has one; Linux falls back to a local proxy. On
  /// Windows it is an adapter that asks for admin permission on each connect.
  tunnel('tunnel'),

  /// The OS proxy settings point at the engine. Windows only.
  systemProxy('system_proxy'),

  /// The engine opens a SOCKS port and apps are pointed at it by hand.
  proxyOnly('proxy_only');

  const ExposureMode(this.analyticsValue);

  /// The value analytics records when the user picks this mode.
  final String analyticsValue;
}

/// How the engine exposes its local proxy, and to whom.
///
/// One mode, with exactly one value. Storage holds it as a boolean per mode,
/// and those flags are not independent: on Windows the engine takes exactly
/// one of tunnel, system proxy or proxy-only, and everywhere else there is no
/// system proxy to take over, so that flag stays off whatever disk says. LAN
/// sharing only means anything while a SOCKS port is open.
///
/// Those rules used to be spelled out three times inside the settings
/// notifier — once when loading and once in each setter — which is how the
/// load path ended up resolving "both true" differently from either setter.
/// They live here now, and the notifier just asks.
class ProxyExposure {
  const ProxyExposure._({
    required this.mode,
    required this.bypassLan,
    required this.systemProxySupported,
  });

  /// Which way the engine carries traffic. Never [ExposureMode.systemProxy]
  /// where [systemProxySupported] is false.
  final ExposureMode mode;

  /// Listen on every interface, so other devices on the LAN can route
  /// through this one.
  final bool bypassLan;

  /// Whether this platform has a system proxy to take over at all.
  final bool systemProxySupported;

  /// The engine opens a SOCKS port instead of a device-wide tunnel.
  bool get proxyOnly => mode == ExposureMode.proxyOnly;

  /// The OS proxy settings point at the engine. Windows only.
  bool get systemProxy => mode == ExposureMode.systemProxy;

  /// The engine captures every app's traffic itself, through the platform's
  /// VPN where the platform has one; Linux falls back to a local proxy.
  bool get tunnel => mode == ExposureMode.tunnel;

  /// The exposure a platform shows before anything is read from disk.
  ///
  /// Windows shows the system proxy here even though an empty store resolves
  /// to its tunnel (see [resolve]): this is only the moment before storage
  /// answers, and a connect pressed in it must not raise an admin prompt the
  /// user never asked for. Every other platform starts with its own tunnel.
  static ProxyExposure initial({required bool systemProxySupported}) {
    return ProxyExposure._(
      mode: systemProxySupported
          ? ExposureMode.systemProxy
          : ExposureMode.tunnel,
      bypassLan: false,
      systemProxySupported: systemProxySupported,
    );
  }

  /// Where there is a system proxy.
  ///
  /// A mode is written only when the user picks one, and a pick writes all
  /// three flags, so a store holding none of them is someone who never chose:
  /// they get the tunnel, which carries every app's traffic.
  ///
  /// Once anything was picked, each flag never written means what it meant
  /// before the tunnel existed: proxy-only off, the system proxy on.
  /// Proxy-only wins any conflict, because turning it on is something the
  /// user does. The tunnel asks for admin permission on every connect, so it
  /// never wins one: it takes a stored tunnel that nothing else on disk
  /// contradicts, with proxy-only not on and the system proxy written off. A
  /// store from before the tunnel existed with a mode in it, or one that a
  /// write cut short left with two modes on, resolves to one of the other two.
  static ExposureMode _resolveWithSystemProxy({
    required bool? tunnel,
    required bool? proxyOnly,
    required bool? systemProxy,
  }) {
    final neverPicked =
        tunnel == null && proxyOnly == null && systemProxy == null;
    if (neverPicked) return ExposureMode.tunnel;
    if (proxyOnly ?? false) return ExposureMode.proxyOnly;
    final systemProxyOn = systemProxy ?? true;
    if ((tunnel ?? false) && !systemProxyOn) return ExposureMode.tunnel;
    return ExposureMode.systemProxy;
  }

  /// Reconciles what storage returned. A `null` is a value never written.
  ///
  /// Where there is no system proxy, proxy-only alone decides, as it always
  /// has: anything else is the platform's own tunnel, and the stored system
  /// proxy and tunnel flags are ignored.
  static ProxyExposure resolve({
    required bool? tunnel,
    required bool? proxyOnly,
    required bool? systemProxy,
    required bool? bypassLan,
    required bool systemProxySupported,
  }) {
    final ExposureMode mode;
    if (systemProxySupported) {
      mode = _resolveWithSystemProxy(
        tunnel: tunnel,
        proxyOnly: proxyOnly,
        systemProxy: systemProxy,
      );
    } else {
      mode = (proxyOnly ?? false)
          ? ExposureMode.proxyOnly
          : ExposureMode.tunnel;
    }

    return ProxyExposure._(
      mode: mode,
      bypassLan: bypassLan ?? false,
      systemProxySupported: systemProxySupported,
    );
  }

  /// Switches to [mode]. A platform without a system proxy has nothing to
  /// switch to there, so it reports itself back unchanged.
  ProxyExposure withMode(ExposureMode mode) {
    if (mode == ExposureMode.systemProxy && !systemProxySupported) {
      return this;
    }
    return _copyWith(mode: mode);
  }

  /// Turning proxy-only on hands the other mode off, and turning it off
  /// hands back the platform's default — there is no state with neither.
  /// Where there is a system proxy that default is the system proxy, never
  /// the tunnel, which only [withMode] chooses.
  ProxyExposure withProxyOnly(bool enabled) {
    if (enabled) return _copyWith(mode: ExposureMode.proxyOnly);
    return _copyWith(
      mode: systemProxySupported
          ? ExposureMode.systemProxy
          : ExposureMode.tunnel,
    );
  }

  ProxyExposure withBypassLan(bool enabled) => _copyWith(bypassLan: enabled);

  /// True when the open port is reachable from the rest of the network.
  ///
  /// The flag alone is not enough: with no SOCKS port open there is nothing
  /// for a LAN neighbour to reach, so the toggle reads as off until
  /// proxy-only is on.
  bool get sharesWithLan => proxyOnly && bypassLan;

  /// The address the engine binds its SOCKS port to.
  String get listenAddress =>
      sharesWithLan ? kBypassLanListen : kLocalhostListen;

  ProxyExposure _copyWith({ExposureMode? mode, bool? bypassLan}) {
    return ProxyExposure._(
      mode: mode ?? this.mode,
      bypassLan: bypassLan ?? this.bypassLan,
      systemProxySupported: systemProxySupported,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProxyExposure &&
        other.mode == mode &&
        other.bypassLan == bypassLan &&
        other.systemProxySupported == systemProxySupported;
  }

  @override
  int get hashCode => Object.hash(mode, bypassLan, systemProxySupported);

  @override
  String toString() {
    return 'ProxyExposure(mode: ${mode.name}, bypassLan: $bypassLan, '
        'systemProxySupported: $systemProxySupported)';
  }
}
