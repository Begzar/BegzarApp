import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';

/// Everything the settings screen lets the user decide.
///
/// This is the notifier's state as well as the repository's read-back: there
/// is nothing the screen shows that is not also what gets stored, so a second
/// state class beside it would only be a copy that can fall behind.
class SettingsPreferences {
  const SettingsPreferences({
    required this.exposure,
    this.adsBlock = false,
    this.appExclude = false,
    this.dns = DnsServer.fallback,
    this.experimental = false,
    this.warpMode = WarpMode.fallback,
  });

  /// Ask the engine to drop known ad and tracker hosts.
  final bool adsBlock;

  /// Android: let some apps stay off the tunnel.
  final bool appExclude;

  /// The resolver the engine is told to use.
  final DnsServer dns;

  /// The resolver as the engine receives it.
  String get dnsServer => dns.address;

  /// How the local proxy is exposed, and to whom.
  final ProxyExposure exposure;

  /// Experimental settings: a free connect runs the WARP engine in
  /// [warpMode] instead of dialling Begzar's servers. A subscriber's connect
  /// is never affected.
  final bool experimental;

  /// The shape the WARP engine runs in while [experimental] is on. Kept when
  /// it is off, so turning it back on finds the last choice.
  final WarpMode warpMode;

  /// The preferences a platform starts with before storage is read.
  static SettingsPreferences initial({required bool systemProxySupported}) {
    return SettingsPreferences(
      exposure: ProxyExposure.initial(
        systemProxySupported: systemProxySupported,
      ),
    );
  }

  SettingsPreferences copyWith({
    bool? adsBlock,
    bool? appExclude,
    DnsServer? dns,
    ProxyExposure? exposure,
    bool? experimental,
    WarpMode? warpMode,
  }) {
    return SettingsPreferences(
      adsBlock: adsBlock ?? this.adsBlock,
      appExclude: appExclude ?? this.appExclude,
      dns: dns ?? this.dns,
      exposure: exposure ?? this.exposure,
      experimental: experimental ?? this.experimental,
      warpMode: warpMode ?? this.warpMode,
    );
  }
}
