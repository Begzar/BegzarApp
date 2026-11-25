import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/application/services/settings_service.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What analytics calls each setting, and the values it records for them.
/// The connection mode's values are the modes' own analytics names.
const _connectionModeSetting = 'connection_mode';
const _proxyOnlySetting = 'proxy_only';
const _bypassLanSetting = 'bypass_lan';
const _appExcludeSetting = 'app_exclude';
const _dnsSetting = 'dns';
const _experimentalSetting = 'experimental';
const _warpModeSetting = 'experimental_mode';
const _switchedOn = 'on';
const _switchedOff = 'off';
const _fallbackDns = 'default';
const _customDns = 'custom';

/// Holds what the settings screen shows and hands every change to the
/// service, which decides what it means and writes it down.
class SettingsNotifier extends Notifier<SettingsPreferences> {
  late SettingsService _service;
  bool _userTouched = false;
  late Future<void> _loadFuture;

  @override
  SettingsPreferences build() {
    _service = ref.watch(settingsServiceProvider);
    _loadFuture = _loadSettings();
    return SettingsPreferences.initial(
      systemProxySupported: supportsSystemProxy,
    );
  }

  Future<void> ensureLoaded() => _loadFuture;

  /// Publishes what was stored, unless the user has already changed
  /// something — the screen is usable before the read lands, and a late
  /// answer must not undo a choice made in the meantime.
  Future<void> _loadSettings() async {
    final stored = await _service.loadPreferences();
    if (!ref.mounted || _userTouched) return;
    state = stored;
  }

  void _recordChange(String setting, String value) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logSettingChanged(setting: setting, value: value),
    );
  }

  void _recordSwitch(String setting, bool enabled) =>
      _recordChange(setting, enabled ? _switchedOn : _switchedOff);

  Future<void> setAdsBlock(bool enabled) async {
    await _touch();
    state = await _service.changeAdsBlock(state, enabled: enabled);
  }

  Future<void> setAppExclude(bool enabled) async {
    await _touch();
    state = await _service.changeAppExclude(state, enabled: enabled);
    _recordSwitch(_appExcludeSetting, enabled);
  }

  /// Experimental settings: a free connect runs the WARP engine instead of
  /// Begzar's servers.
  Future<void> setExperimental(bool enabled) async {
    await _touch();
    state = await _service.changeExperimental(state, enabled: enabled);
    _recordSwitch(_experimentalSetting, enabled);
  }

  /// The shape the WARP engine runs in while Experimental settings are on.
  Future<void> setWarpMode(WarpMode mode) async {
    await _touch();
    state = await _service.changeWarpMode(state, mode);
    _recordChange(_warpModeSetting, mode.analyticsValue);
  }

  /// Reports whether the text names a resolver the engine can query. A value
  /// it cannot leaves the stored one in place.
  ///
  /// Analytics hears only whether it is the fallback or one the user named,
  /// never the address itself.
  Future<bool> setDnsServer(String rawValue) async {
    await ensureLoaded();
    final next = await _service.changeDnsServer(state, rawValue: rawValue);
    if (next == null) return false;

    _userTouched = true;
    state = next;
    _recordChange(
      _dnsSetting,
      next.dnsServer == DnsServer.fallback.address ? _fallbackDns : _customDns,
    );
    return true;
  }

  /// Windows: tunnel, system proxy or proxy only, exactly one at a time.
  Future<void> setConnectionMode(ExposureMode mode) async {
    await _touch();
    state = await _service.changeExposure(
      state,
      (exposure) => exposure.withMode(mode),
    );
    _recordChange(_connectionModeSetting, mode.analyticsValue);
  }

  /// Route apps through a local SOCKS port instead of a device-wide tunnel.
  Future<void> setProxyOnly(bool enabled) async {
    await _touch();
    state = await _service.changeExposure(
      state,
      (exposure) => exposure.withProxyOnly(enabled),
    );
    _recordSwitch(_proxyOnlySetting, enabled);
  }

  /// Let other devices on the LAN reach the SOCKS port.
  Future<void> setBypassLan(bool enabled) async {
    await _touch();
    state = await _service.changeExposure(
      state,
      (exposure) => exposure.withBypassLan(enabled),
    );
    _recordSwitch(_bypassLanSetting, enabled);
  }

  /// Waits for the stored values to land, then claims the state for the
  /// user, so a slow read cannot overwrite what they just chose.
  Future<void> _touch() async {
    await ensureLoaded();
    _userTouched = true;
  }

  /// Check if ads should be blocked
  bool get shouldBlockAds => state.adsBlock;

  /// Check if app exclude is enabled
  bool get isAppExcludeEnabled => state.appExclude;

  /// Get current DNS server
  String get dnsServer => state.dnsServer;
}

/// Settings Provider
final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsPreferences>(
      SettingsNotifier.new,
    );
