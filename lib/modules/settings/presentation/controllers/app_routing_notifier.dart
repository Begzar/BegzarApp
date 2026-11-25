import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/settings/application/services/settings_service.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What analytics calls the routing mode. Its values are the modes' own
/// stored names.
const _appRoutingModeSetting = 'app_routing_mode';

/// Which apps the tunnel carries, and the list picked for each mode.
class AppRoutingNotifier extends Notifier<AppRoutingSelection> {
  late SettingsService _service;
  bool _userTouched = false;
  late Future<void> _loadFuture;

  @override
  AppRoutingSelection build() {
    _service = ref.watch(settingsServiceProvider);
    _loadFuture = _loadAppRouting();
    return AppRoutingSelection.initial;
  }

  Future<void> ensureLoaded() => _loadFuture;

  Future<void> _loadAppRouting() async {
    final stored = await _service.loadAppRouting();
    if (!ref.mounted || _userTouched) return;
    state = stored;
  }

  /// Waits for the stored selection to land, then claims the state for the
  /// user, so a slow read cannot overwrite what they just chose.
  Future<void> _touch() async {
    await ensureLoaded();
    _userTouched = true;
  }

  Future<void> setMode(AppRoutingMode mode) async {
    await _touch();
    state = await _service.changeAppRoutingMode(state, mode);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logSettingChanged(
            setting: _appRoutingModeSetting,
            value: mode.storedName,
          ),
    );
  }

  /// Adds or removes one app in the list the current mode reads. Analytics
  /// is not told: which apps a user picked is theirs.
  Future<void> setPicked(String id, {required bool picked}) async {
    await _touch();
    state = await _service.setAppPicked(state, id, picked: picked);
  }

  Future<void> clearPicked() async {
    await _touch();
    state = await _service.clearPickedApps(state);
  }
}

/// App Routing Provider
final appRoutingProvider =
    NotifierProvider<AppRoutingNotifier, AppRoutingSelection>(
      AppRoutingNotifier.new,
    );
