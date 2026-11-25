import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/data/app_version_catalog_cache.dart';

/// Picks the version to enforce at connect time.
///
/// The catalog entry for this install channel wins when there is one, so a
/// lagging store listing is never compared against a GitHub-only bump. Without
/// a catalog the legacy subscription fields stand in.
abstract final class AppVersionEnforcement {
  static ({String version, String? url})? target({
    String? fallbackVersion,
    String? fallbackUrl,
  }) {
    final catalog = AppVersionCatalogCache.latest;
    if (catalog != null) {
      final release = catalog.lookup(
        AppDistribution.catalogPlatform,
        AppDistribution.sourceKey,
      );
      if (release == null || release.version.isEmpty) return null;
      return (version: release.version, url: release.url);
    }

    final raw = fallbackVersion?.trim();
    if (raw == null || raw.isEmpty) return null;
    return (version: raw, url: fallbackUrl);
  }
}
