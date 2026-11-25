import 'package:begzar/modules/app_update/domain/entities/app_version_catalog.dart';

/// Whether this build may keep running, and what to show if it may not.
class AppVersionGateResult {
  const AppVersionGateResult.allow()
    : isUpdateRequired = false,
      currentVersion = '',
      requiredVersion = '',
      latestVersion = null,
      updateUrl = null;

  const AppVersionGateResult.updateRequired({
    required this.currentVersion,
    required this.requiredVersion,
    this.updateUrl,
  }) : isUpdateRequired = true,
       latestVersion = null;

  const AppVersionGateResult.updateAvailable({
    required this.currentVersion,
    required String this.latestVersion,
    required String this.updateUrl,
  }) : isUpdateRequired = false,
       requiredVersion = '';

  final bool isUpdateRequired;
  final String currentVersion;
  final String requiredVersion;

  /// A newer release the user may install but does not have to. Set only
  /// when the build is allowed and the channel names a page to get it from.
  final String? latestVersion;

  final String? updateUrl;
}

/// Fail-open version gate against the catalog entry for this install channel.
///
/// Every uncertainty allows: no catalog, no entry for this platform/source
/// pair, an empty version. A version check that cannot reach an answer must
/// not be the thing that stops someone connecting.
///
/// An allowed build older than the channel's latest release is offered that
/// release, but only when the channel names a page to get it from.
abstract final class AppVersionGate {
  static AppVersionGateResult evaluate({
    required AppVersionCatalog? catalog,
    required String platform,
    required String sourceKey,
    required String currentVersion,
    required int Function(String, String) compareVersions,
  }) {
    if (catalog == null) return const AppVersionGateResult.allow();

    final release = catalog.lookup(platform, sourceKey);
    if (release == null || release.version.isEmpty) {
      return const AppVersionGateResult.allow();
    }

    if (compareVersions(currentVersion, release.version) < 0) {
      return AppVersionGateResult.updateRequired(
        currentVersion: currentVersion,
        requiredVersion: release.version,
        updateUrl: release.url,
      );
    }

    final latestVersion = release.latestVersion;
    final updateUrl = release.url;
    if (latestVersion == null ||
        updateUrl == null ||
        compareVersions(currentVersion, latestVersion) >= 0) {
      return const AppVersionGateResult.allow();
    }

    return AppVersionGateResult.updateAvailable(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      updateUrl: updateUrl,
    );
  }
}
