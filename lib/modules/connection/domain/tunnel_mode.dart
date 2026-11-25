/// How the tunnel was actually opened.
///
/// What the user asked for and what the platform allows are different things —
/// Linux has no TUN, Windows has one only through its tunnel helper, Apple
/// platforms have nothing but — so the mode is settled while connecting rather
/// than read off a setting. Anything above the repository that needs to know
/// which it was has to be told, because working it out again would mean
/// repeating the platform rules.
enum TunnelMode {
  /// A system-wide tunnel: every app's traffic. On Windows, the helper's
  /// adapter in front of the engine.
  vpn,

  /// A local SOCKS listener, for the user to point things at themselves.
  proxy,

  /// A local listener, additionally registered as the Windows system proxy.
  systemProxy;

  /// What analytics has recorded for this mode since before it was a type.
  /// Kept verbatim so the events stay comparable across the change.
  String get analyticsLabel => switch (this) {
    TunnelMode.vpn => 'vpn',
    TunnelMode.proxy => 'proxy',
    TunnelMode.systemProxy => 'system_proxy',
  };
}
