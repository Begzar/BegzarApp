import 'dart:io' show Platform;

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/services/macos_permissions_service.dart';
import 'package:flutter/foundation.dart';

/// Persists the post-connect ad-gate flags across app sessions.
///
/// Deliberately stores no connection status. The tunnel itself answers whether
/// a connection is live, and `ConnectionNotifier.reconcileWithNative` asks it —
/// a persisted status could only ever disagree with that answer.
///
/// What it does store is the gate, and it has to survive the process because
/// the way to skip an ad is to end the process. Backgrounding is caught while
/// the app is on its way out; being killed outright is not caught at all, and
/// the tunnel outlives the app either way. So the gate writes down that it is
/// running, and the next launch reads that back: a flag still set means the
/// ad was never finished, whatever became of the app that was showing it.
class ConnectionStateStorage {
  static const String _adSkipWarningPendingKey = 'ad_skip_warning_pending';
  static const String _adGateActiveKey = 'ad_gate_active';

  /// Takes its storage rather than reaching for it, like every other keyed
  /// store in the app. Reach for `connectionStateStorageProvider` to get one.
  const ConnectionStateStorage({required AppKeyedStorage storage})
    : _storage = storage;

  final AppKeyedStorage _storage;

  bool get _storageReady =>
      kIsWeb ||
      !Platform.isMacOS ||
      MacOsPermissionsService.instance.canUseKeychain;

  /// Mark that the user left before finishing the post-connect ad.
  Future<void> setAdSkipWarningPending(bool pending) async {
    if (!_storageReady) return;
    if (pending) {
      await _storage.write(key: _adSkipWarningPendingKey, value: 'true');
    } else {
      await _storage.delete(key: _adSkipWarningPendingKey);
    }
  }

  Future<bool> hasAdSkipWarningPending() async {
    if (!_storageReady) return false;
    return await _storage.read(key: _adSkipWarningPendingKey) == 'true';
  }

  /// Mark that an ad gate is on screen and has not been watched out.
  ///
  /// Set when the countdown starts, cleared when it reaches zero. A launch
  /// that finds this set alongside a live tunnel is looking at an ad the user
  /// walked out of.
  Future<void> setAdGateActive(bool active) async {
    if (!_storageReady) return;
    if (active) {
      await _storage.write(key: _adGateActiveKey, value: 'true');
    } else {
      await _storage.delete(key: _adGateActiveKey);
    }
  }

  Future<bool> hasAdGateActive() async {
    if (!_storageReady) return false;
    return await _storage.read(key: _adGateActiveKey) == 'true';
  }
}
