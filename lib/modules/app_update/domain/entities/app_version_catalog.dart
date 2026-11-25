/// One channel's minimum version, its newest release, and where to get it.
class AppVersionSourceRelease {
  const AppVersionSourceRelease({
    required this.version,
    this.latestVersion,
    this.url,
  });

  final String version;

  /// The newest release on this channel. Absent when the server names none,
  /// in which case the app offers no update beyond the forced one.
  final String? latestVersion;

  /// Store or download page. Absent when the channel has no landing page,
  /// in which case the update dialog offers no destination.
  final String? url;
}

/// What the release catalog says, keyed `platform` then install `source`.
///
/// A build only ever asks about its own pair, so a catalog listing platforms
/// or channels this binary knows nothing about is normal.
class AppVersionCatalog {
  const AppVersionCatalog({required this.platforms});

  final Map<String, Map<String, AppVersionSourceRelease>> platforms;

  AppVersionSourceRelease? lookup(String platform, String source) {
    return platforms[platform]?[source];
  }
}
