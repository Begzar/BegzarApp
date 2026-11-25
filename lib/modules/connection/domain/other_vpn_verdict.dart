/// What became of another app's VPN when Begzar went to measure servers.
///
/// Anything measured beside the tunnel — quick connect's probe, the server
/// list's delays — travels through whatever VPN is up, so another app's tunnel
/// makes every number wrong. Begzar turns it off where the platform lets it,
/// and the verdict is what a check afterwards found, never what the attempt
/// claimed.
enum OtherVpnVerdict {
  /// No other VPN was on. Nothing to tell anyone.
  none,

  /// One was on, and Begzar turned it off. The user is told, and whatever they
  /// asked for goes ahead.
  disconnected,

  /// One is on, and Begzar could not turn it off. Nothing goes ahead until the
  /// user turns it off themselves.
  stillOn,

  /// One is on, Begzar could not turn it off, and the user chose to go ahead
  /// with it on.
  ///
  /// The check reads the device, and a reading can be wrong: a modem or a
  /// network adapter Begzar does not know can look like a VPN. The user can
  /// see what is really on, so a warning they cannot clear must never be the
  /// end of the road.
  overridden,
}
