import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/data/app_version_catalog_cache.dart';
import 'package:begzar/modules/app_update/data/datasources/installed_build.dart';
import 'package:begzar/modules/app_update/domain/app_version_gate.dart';
import 'package:begzar/modules/app_update/domain/entities/app_version_catalog.dart';
import 'package:begzar/modules/app_update/domain/version_comparison.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// Asks the engine for the release catalog.
///
/// Any network/parse failure returns [AppVersionGateResult.allow] so a down
/// API never locks users out of the app.
class AppVersionRepository {
  AppVersionRepository({BegzarBackend? backend, InstalledBuild? installedBuild})
    : _backendOverride = backend,
      _installedBuild = installedBuild ?? InstalledBuild.instance;

  static const requestTimeout = Duration(seconds: 12);

  final BegzarBackend? _backendOverride;
  final InstalledBuild _installedBuild;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  Future<AppVersionGateResult> evaluateInstalledBuild() async {
    AppVersionCatalog? catalog;
    try {
      catalog = await fetch().timeout(requestTimeout);
    } catch (_) {
      catalog = null;
    }
    AppVersionCatalogCache.latest = catalog;

    final current = await _installedBuild.version();
    return AppVersionGate.evaluate(
      catalog: catalog,
      platform: AppDistribution.catalogPlatform,
      sourceKey: AppDistribution.sourceKey,
      currentVersion: current,
      compareVersions: compareVersions,
    );
  }

  /// The catalog, or null for an answer with nothing usable in it. Throws a
  /// [BackendException] when there was no answer, which
  /// [evaluateInstalledBuild] reads as allowed.
  Future<AppVersionCatalog?> fetch() async {
    final catalog = (await _backend.appVersionCatalog()).value;
    if (catalog == null) return null;
    return AppVersionCatalog(
      platforms: {
        for (final MapEntry(key: platform, value: sources)
            in catalog.platforms.entries)
          platform: {
            for (final MapEntry(key: source, value: release) in sources.entries)
              source: AppVersionSourceRelease(
                version: release.version,
                latestVersion: release.latestVersion,
                url: release.url,
              ),
          },
      },
    );
  }
}
