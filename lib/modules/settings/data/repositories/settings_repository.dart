import 'dart:io';

import 'package:begzar/modules/settings/data/datasources/installed_apps_data_source.dart';
import 'package:begzar/modules/settings/data/datasources/running_programs_data_source.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/dtos/installed_app_dto.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Begzar's own application id, read when the list of apps is asked for so
/// that building the repository stays synchronous.
Future<String> _platformPackageName() async {
  return (await PackageInfo.fromPlatform()).packageName;
}

/// The one door to settings data.
///
/// Two sources sit behind it: secure storage, which holds what the user
/// chose, and the platform, which reports what there is to choose from — the
/// launcher's apps on a phone, the running programs on a desktop.
///
/// Nothing here throws. Secure storage can fail — a locked keychain on
/// macOS, a device that revoked the key — and the answer in every case is
/// the same: fall back to what the user has on screen and keep going, since
/// a settings screen that crashes is worse than one that quietly does not
/// persist. That decision used to be a try/catch around each of a dozen
/// calls in three notifiers; it is stated once here instead.
class SettingsRepository {
  SettingsRepository({
    required SettingsStorage storage,
    required bool systemProxySupported,
    InstalledAppsDataSource installedApps = const InstalledAppsDataSource(),
    RunningProgramsDataSource runningPrograms =
        const RunningProgramsDataSource(),
    Future<String> Function() ownPackage = _platformPackageName,
  }) : _storage = storage,
       _systemProxySupported = systemProxySupported,
       _installedApps = installedApps,
       _runningPrograms = runningPrograms,
       _ownPackage = ownPackage;

  final SettingsStorage _storage;
  final InstalledAppsDataSource _installedApps;
  final RunningProgramsDataSource _runningPrograms;
  final Future<String> Function() _ownPackage;

  /// Whether this platform has a system proxy to take over at all. The data
  /// layer is where the platform is known, so the resolved [ProxyExposure]
  /// can be handed up already reconciled.
  final bool _systemProxySupported;

  /// What was stored, reconciled. Falls back to the platform's defaults when
  /// storage cannot be read.
  Future<SettingsPreferences> readPreferences() async {
    try {
      return SettingsPreferences(
        adsBlock: await _storage.readAdsBlock() ?? false,
        appExclude: await _storage.readAppExclude() ?? false,
        // A stored value that is not an address predates the check on the
        // way in; the fallback is a resolver that answers, which is better
        // than handing the engine something that never will.
        dns:
            DnsServer.parse(await _storage.readDnsServer() ?? '') ??
            DnsServer.fallback,
        exposure: ProxyExposure.resolve(
          tunnel: await _storage.readTunnelMode(),
          proxyOnly: await _storage.readProxyOnly(),
          systemProxy: await _storage.readSystemProxy(),
          bypassLan: await _storage.readBypassLan(),
          systemProxySupported: _systemProxySupported,
        ),
        experimental: await _storage.readExperimental() ?? false,
        warpMode: WarpMode.fromStored(await _storage.readWarpMode()),
      );
    } catch (_) {
      return SettingsPreferences.initial(
        systemProxySupported: _systemProxySupported,
      );
    }
  }

  Future<void> writeAdsBlock(bool enabled) =>
      _ignoreFailure(() => _storage.writeAdsBlock(enabled));

  Future<void> writeAppExclude(bool enabled) =>
      _ignoreFailure(() => _storage.writeAppExclude(enabled));

  Future<void> writeDnsServer(DnsServer dns) =>
      _ignoreFailure(() => _storage.writeDnsServer(dns.address));

  Future<void> writeExperimental(bool enabled) =>
      _ignoreFailure(() => _storage.writeExperimental(enabled));

  Future<void> writeWarpMode(WarpMode mode) =>
      _ignoreFailure(() => _storage.writeWarpMode(mode.engineName));

  /// Writes every flag, not just the one that changed: they constrain each
  /// other, so a partial write can leave disk in a state
  /// [ProxyExposure.resolve] has to guess its way out of on the next launch.
  ///
  /// The tunnel flag goes last, so a write cut short never leaves a tunnel on
  /// disk that the other flags do not already agree with.
  Future<void> writeProxyExposure(ProxyExposure exposure) {
    return _ignoreFailure(() async {
      await _storage.writeProxyOnly(exposure.proxyOnly);
      await _storage.writeBypassLan(exposure.bypassLan);
      if (exposure.systemProxySupported) {
        await _storage.writeSystemProxy(exposure.systemProxy);
        await _storage.writeTunnelMode(exposure.tunnel);
      }
    });
  }

  /// Begzar's own application id, or null when the platform will not say.
  Future<String?> _readOwnPackage() async {
    try {
      return await _ownPackage();
    } catch (_) {
      return null;
    }
  }

  /// The mode and both lists. An install from before the choice existed has
  /// only the excluded list, which is the all-except list, so it reads as
  /// all-except with what the user had picked.
  ///
  /// Begzar's own id is dropped from both lists: an old picker let the user
  /// toggle it, and a list that kept it would show a row the VPN service
  /// skips, counted as a pick that does nothing.
  Future<AppRoutingSelection> readAppRouting() async {
    try {
      final ownPackageName = await _readOwnPackage();
      return AppRoutingSelection(
        mode: AppRoutingMode.fromStored(await _storage.readAppRoutingMode()),
        allExcept: (await _storage.readExcludedApps())..remove(ownPackageName),
        onlySelected: (await _storage.readOnlySelectedApps())
          ..remove(ownPackageName),
      );
    } catch (_) {
      return AppRoutingSelection.initial;
    }
  }

  Future<void> writeAppRoutingMode(AppRoutingMode mode) =>
      _ignoreFailure(() => _storage.writeAppRoutingMode(mode.storedName));

  /// Writes the list that belongs to [mode]. An empty set removes the record
  /// rather than storing an empty one.
  Future<void> writePickedApps(AppRoutingMode mode, Set<String> apps) {
    return _ignoreFailure(() {
      return switch (mode) {
        AppRoutingMode.allExcept =>
          apps.isEmpty
              ? _storage.deleteExcludedApps()
              : _storage.writeExcludedApps(apps),
        AppRoutingMode.onlySelected =>
          apps.isEmpty
              ? _storage.deleteOnlySelectedApps()
              : _storage.writeOnlySelectedApps(apps),
      };
    });
  }

  Future<CustomRoutingRules> readRoutingRules() async {
    try {
      return await _storage.readCustomRoutingRules();
    } catch (_) {
      return CustomRoutingRules.empty;
    }
  }

  Future<void> writeRoutingRules(CustomRoutingRules rules) =>
      _ignoreFailure(() => _storage.writeCustomRoutingRules(rules));

  /// Windows and Linux have no installed-apps list, so the programs running
  /// now stand in for it; every other platform has the launcher.
  static bool get _listsRunningPrograms =>
      Platform.isWindows || Platform.isLinux;

  Future<List<InstalledApp>> _readRunningPrograms() async {
    return InstalledAppDto.fromExecutablePaths(
      await _runningPrograms.fetchExecutablePaths(),
      selfPath: Platform.resolvedExecutable,
      // The engine matches program names without regard to case on Windows.
      ignoreCase: Platform.isWindows,
      // Only Windows keeps the programs the system needs in one folder.
      systemFolder: Platform.isWindows
          ? Platform.environment['SystemRoot']
          : null,
    );
  }

  Future<List<InstalledApp>> _readLaunchableApps() async {
    final apps = InstalledAppDto.fromPlatform(
      await _installedApps.fetchLaunchable(),
    )..sort(InstalledApp.byName);
    final ownPackageName = await _readOwnPackage();
    // A list that still shows Begzar is better than no list at all.
    if (ownPackageName == null) return apps;
    return apps.where((app) => app.packageName != ownPackageName).toList();
  }

  /// The apps the user can pick from, in the order the list shows them, and
  /// never Begzar itself.
  ///
  /// An empty list is the honest answer on a platform that has no such
  /// concept, or when the query fails; the screen renders its empty state
  /// either way.
  Future<List<InstalledApp>> readInstalledApps() async {
    try {
      return _listsRunningPrograms
          ? await _readRunningPrograms()
          : await _readLaunchableApps();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _ignoreFailure(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // A setting that could not be persisted still applies to this run.
    }
  }
}
