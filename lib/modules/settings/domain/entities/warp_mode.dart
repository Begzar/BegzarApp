/// The shape the experimental WARP engine runs in, when Experimental settings
/// are on and a free user connects.
///
/// Every mode reaches the internet through Cloudflare WARP; they differ in
/// how WARP is reached and what, if anything, sits behind it.
enum WarpMode {
  /// WARP over MASQUE: HTTP/3, the transport Cloudflare's own client moved to.
  masque('masque'),

  /// WARP over WireGuard.
  warp('warp'),

  /// WARP inside WARP: two WireGuard hops.
  gool('gool'),

  /// Psiphon, reached through WARP over MASQUE.
  masquePsiphon('masque-psiphon'),

  /// Psiphon, reached through WARP over WireGuard.
  psiphon('psiphon');

  const WarpMode(this.engineName);

  /// The name the engine's launch payload uses, which is also what is
  /// written to disk. Renaming a value of this enum must not change it, or
  /// every stored choice would read as the default.
  final String engineName;

  /// What a mode is recorded as in analytics: the engine's name with the
  /// dash every other recorded value avoids.
  String get analyticsValue => engineName.replaceAll('-', '_');

  /// The mode a user who has not picked one gets. MASQUE comes up fastest and
  /// gets through where WARP's WireGuard is blocked.
  static const fallback = masque;

  /// Reads a stored name back. A missing or unknown value is [fallback].
  static WarpMode fromStored(String? value) {
    for (final mode in values) {
      if (mode.engineName == value) return mode;
    }
    return fallback;
  }
}
