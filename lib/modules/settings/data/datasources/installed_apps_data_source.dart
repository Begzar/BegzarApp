import 'package:installed_apps/installed_apps.dart';

/// The device's launcher entries — the module's platform data source.
///
/// Only apps that can actually be launched are asked for, since an app with
/// no launcher entry is not something the user would recognise in a list.
/// System apps are included: several of them do talk to the network, and
/// excluding one is a legitimate choice.
class InstalledAppsDataSource {
  const InstalledAppsDataSource();

  Future<List<AppInfo>> fetchLaunchable() {
    return InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
  }
}
