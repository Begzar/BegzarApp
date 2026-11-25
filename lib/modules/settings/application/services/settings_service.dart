import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';

/// Reading and changing what the user has configured.
///
/// Every method takes the current value and returns the next one, having
/// persisted it. Holding no state of its own is what lets the controllers
/// stay the only place a value lives, and lets these rules be tested without
/// a Riverpod container.
class SettingsService {
  const SettingsService(this._repository);

  final SettingsRepository _repository;

  Future<SettingsPreferences> loadPreferences() =>
      _repository.readPreferences();

  Future<SettingsPreferences> changeAdsBlock(
    SettingsPreferences current, {
    required bool enabled,
  }) async {
    await _repository.writeAdsBlock(enabled);
    return current.copyWith(adsBlock: enabled);
  }

  Future<SettingsPreferences> changeAppExclude(
    SettingsPreferences current, {
    required bool enabled,
  }) async {
    await _repository.writeAppExclude(enabled);
    return current.copyWith(appExclude: enabled);
  }

  Future<SettingsPreferences> changeExperimental(
    SettingsPreferences current, {
    required bool enabled,
  }) async {
    await _repository.writeExperimental(enabled);
    return current.copyWith(experimental: enabled);
  }

  Future<SettingsPreferences> changeWarpMode(
    SettingsPreferences current,
    WarpMode mode,
  ) async {
    await _repository.writeWarpMode(mode);
    return current.copyWith(warpMode: mode);
  }

  /// Takes the raw text the user typed and reports null when it is not an
  /// address the engine can query, leaving the stored resolver alone.
  Future<SettingsPreferences?> changeDnsServer(
    SettingsPreferences current, {
    required String rawValue,
  }) async {
    final dns = DnsServer.parse(rawValue);
    if (dns == null) return null;

    await _repository.writeDnsServer(dns);
    return current.copyWith(dns: dns);
  }

  /// Applies one change to the proxy exposure and persists the result.
  ///
  /// The domain decides what a change means for the other two flags; a
  /// change it refuses — the system proxy on a platform that has none —
  /// comes back as the value that went in and is never written.
  Future<SettingsPreferences> changeExposure(
    SettingsPreferences current,
    ProxyExposure Function(ProxyExposure exposure) change,
  ) async {
    final next = change(current.exposure);
    if (next == current.exposure) return current;

    await _repository.writeProxyExposure(next);
    return current.copyWith(exposure: next);
  }

  Future<AppRoutingSelection> loadAppRouting() => _repository.readAppRouting();

  /// Switches the mode and leaves both lists as they were, so switching back
  /// finds the other list untouched.
  Future<AppRoutingSelection> changeAppRoutingMode(
    AppRoutingSelection current,
    AppRoutingMode mode,
  ) async {
    await _repository.writeAppRoutingMode(mode);
    return current.withMode(mode);
  }

  /// Adds or removes one app in the list in force. The other list is neither
  /// read nor written.
  Future<AppRoutingSelection> setAppPicked(
    AppRoutingSelection current,
    String id, {
    required bool picked,
  }) async {
    final next = {...current.inForce};
    if (picked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    await _repository.writePickedApps(current.mode, next);
    return current.withInForce(next);
  }

  /// Empties the list in force and leaves the other one alone.
  Future<AppRoutingSelection> clearPickedApps(
    AppRoutingSelection current,
  ) async {
    await _repository.writePickedApps(current.mode, const {});
    return current.withInForce(const {});
  }

  /// The device's apps, in the order the list shows them.
  ///
  /// Deliberately not joined with the live selection: that set changes on
  /// every toggle and the screen already watches it, so a row that carried a
  /// frozen answer would stop matching its own switch. [picked] is the one
  /// exception, taken once when the list opens: an app that holds a pick but
  /// is not in the launcher's answer — a program that is not running, an app
  /// since uninstalled — would otherwise vanish from the only place to undo
  /// the pick.
  Future<List<InstalledApp>> loadInstalledApps({
    Set<String> picked = const {},
  }) async {
    return InstalledApp.withMissing(
      await _repository.readInstalledApps(),
      picked,
    );
  }
}
