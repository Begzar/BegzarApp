import 'package:begzar/modules/app_update/domain/installed_build_label.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version string of the binary that is running.
///
/// Read once from the platform and kept, because the answer cannot change
/// while the process lives.
class InstalledBuild {
  InstalledBuild._();

  static final InstalledBuild instance = InstalledBuild._();

  /// Stand-in for a platform answer that carried no version. Reads as older
  /// than every release, so the gate would ask for an update rather than wave
  /// an unidentifiable build through.
  static const String _unknownVersion = '0.0.0';

  PackageInfo? _packageInfo;

  Future<String> version() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo?.version ?? _unknownVersion;
  }

  /// The version with its build number, for a person to read: two builds of
  /// one version, such as a rebuild that replaced a release, read apart.
  Future<String> label() async {
    final version = await this.version();
    return installedBuildLabel(version, _packageInfo?.buildNumber ?? '');
  }
}
