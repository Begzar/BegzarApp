import 'dart:convert';
import 'dart:io' show Platform;

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/services/macos_permissions_service.dart';
import 'package:begzar/modules/settings/data/dtos/custom_routing_rules_dto.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter/foundation.dart';

/// Persists all settings-module data via secure storage — the module's local
/// data source.
class SettingsStorage {
  static const _adsBlockKey = 'settings_ads_block';
  static const _appExcludeKey = 'settings_app_exclude';
  static const _dnsServerKey = 'settings_dns_server';
  static const _proxyOnlyKey = 'settings_proxy_only';
  static const _bypassLanKey = 'settings_bypass_lan';
  static const _systemProxyKey = 'settings_system_proxy';
  static const _tunnelModeKey = 'settings_tunnel_mode';
  static const _localeKey = 'settings_locale';
  static const _themeModeKey = 'settings_theme_mode';
  static const _excludedAppsKey = 'settings_excluded_apps';
  static const _legacyExcludedAppsKey = 'excluded_apps';
  static const _customRoutingKey = 'settings_custom_routing';
  static const _appRoutingModeKey = 'settings_app_routing_mode';
  static const _onlySelectedAppsKey = 'settings_app_routing_only_selected';
  static const _experimentalKey = 'settings_experimental';
  static const _warpModeKey = 'settings_warp_mode';

  final AppKeyedStorage _storage;

  SettingsStorage({required AppKeyedStorage storage}) : _storage = storage;

  bool get _storageReady =>
      kIsWeb ||
      !Platform.isMacOS ||
      MacOsPermissionsService.instance.canUseKeychain;

  Future<String?> _readValue(String key) async {
    if (!_storageReady) return null;
    return _storage.read(key: key);
  }

  Future<void> _writeBool(String key, bool value) async {
    if (!_storageReady) return;
    await _storage.write(key: key, value: value.toString());
  }

  Future<bool?> _readBool(String key) async {
    final value = await _readValue(key);
    if (value == null) return null;
    return value == 'true';
  }

  Future<void> _writePackages(String key, Set<String> packages) async {
    if (!_storageReady) return;
    await _storage.write(key: key, value: jsonEncode(packages.toList()));
  }

  Future<void> _deleteValue(String key) async {
    if (!_storageReady) return;
    await _storage.delete(key: key);
  }

  /// A stored list of package names, read from [key] or, where the caller
  /// names one, from the [legacyKey] an older build used.
  ///
  /// A list found under the legacy key is moved to [key] on the way out, so
  /// the next read finds it where it now belongs. A move that fails still
  /// returns the list, and the legacy key is left for the next read to retry.
  Future<Set<String>> _readPackages(String key, {String? legacyKey}) async {
    var raw = await _readValue(key);
    var isLegacy = false;
    if (raw == null && legacyKey != null) {
      raw = await _readValue(legacyKey);
      isLegacy = true;
    }

    if (raw == null) return {};

    final Set<String> packages;
    try {
      packages = (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }

    if (isLegacy && packages.isNotEmpty) {
      try {
        await _writePackages(key, packages);
      } catch (_) {}
    }

    return packages;
  }

  Future<bool?> readAdsBlock() => _readBool(_adsBlockKey);

  Future<void> writeAdsBlock(bool enabled) => _writeBool(_adsBlockKey, enabled);

  Future<bool?> readAppExclude() => _readBool(_appExcludeKey);

  Future<void> writeAppExclude(bool enabled) =>
      _writeBool(_appExcludeKey, enabled);

  Future<String?> readDnsServer() => _readValue(_dnsServerKey);

  Future<void> writeDnsServer(String dns) async {
    if (!_storageReady) return;
    await _storage.write(key: _dnsServerKey, value: dns);
  }

  Future<bool?> readProxyOnly() => _readBool(_proxyOnlyKey);

  Future<void> writeProxyOnly(bool enabled) =>
      _writeBool(_proxyOnlyKey, enabled);

  Future<bool?> readBypassLan() => _readBool(_bypassLanKey);

  Future<void> writeBypassLan(bool enabled) =>
      _writeBool(_bypassLanKey, enabled);

  Future<bool?> readSystemProxy() => _readBool(_systemProxyKey);

  Future<void> writeSystemProxy(bool enabled) =>
      _writeBool(_systemProxyKey, enabled);

  /// Windows only. Absent on every install from before the tunnel existed.
  Future<bool?> readTunnelMode() => _readBool(_tunnelModeKey);

  Future<void> writeTunnelMode(bool enabled) =>
      _writeBool(_tunnelModeKey, enabled);

  Future<bool?> readExperimental() => _readBool(_experimentalKey);

  Future<void> writeExperimental(bool enabled) =>
      _writeBool(_experimentalKey, enabled);

  /// The WARP mode by its engine name. Absent until one is picked.
  Future<String?> readWarpMode() => _readValue(_warpModeKey);

  Future<void> writeWarpMode(String engineName) async {
    if (!_storageReady) return;
    await _storage.write(key: _warpModeKey, value: engineName);
  }

  Future<String?> readLocale() => _readValue(_localeKey);

  Future<void> writeLocale(String code) async {
    if (!_storageReady) return;
    await _storage.write(key: _localeKey, value: code);
  }

  /// The theme picked in Settings, by name. Absent until one is picked, which
  /// is what System default is.
  Future<String?> readThemeMode() => _readValue(_themeModeKey);

  Future<void> writeThemeMode(String name) async {
    if (!_storageReady) return;
    await _storage.write(key: _themeModeKey, value: name);
  }

  Future<Set<String>> readExcludedApps() =>
      _readPackages(_excludedAppsKey, legacyKey: _legacyExcludedAppsKey);

  Future<void> writeExcludedApps(Set<String> packages) =>
      _writePackages(_excludedAppsKey, packages);

  /// Removes the legacy record as well: it is only ever copied from, never
  /// rewritten, so leaving it would bring a cleared list back on the next
  /// read. The legacy key goes first so that a failure between the two
  /// deletes leaves the current list in place rather than an older one.
  Future<void> deleteExcludedApps() async {
    await _deleteValue(_legacyExcludedAppsKey);
    await _deleteValue(_excludedAppsKey);
  }

  Future<String?> readAppRoutingMode() => _readValue(_appRoutingModeKey);

  Future<void> writeAppRoutingMode(String mode) async {
    if (!_storageReady) return;
    await _storage.write(key: _appRoutingModeKey, value: mode);
  }

  Future<Set<String>> readOnlySelectedApps() =>
      _readPackages(_onlySelectedAppsKey);

  Future<void> writeOnlySelectedApps(Set<String> packages) =>
      _writePackages(_onlySelectedAppsKey, packages);

  Future<void> deleteOnlySelectedApps() => _deleteValue(_onlySelectedAppsKey);

  Future<CustomRoutingRules> readCustomRoutingRules() async {
    final raw = await _readValue(_customRoutingKey);
    if (raw == null) return CustomRoutingRules.empty;

    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return CustomRoutingRulesDto.fromJson(json);
      }
    } catch (_) {}

    return CustomRoutingRules.empty;
  }

  Future<void> writeCustomRoutingRules(CustomRoutingRules rules) async {
    if (!_storageReady) return;
    await _storage.write(
      key: _customRoutingKey,
      value: jsonEncode(CustomRoutingRulesDto.toJson(rules)),
    );
  }
}
