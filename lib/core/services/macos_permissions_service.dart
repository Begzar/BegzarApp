import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS helpers for system proxy (no upfront permission gate).
///
/// Storage uses Application Support and needs no user grant.
/// System proxy is applied on connect; the OS may prompt for admin then.
class MacOsPermissionsService {
  MacOsPermissionsService._();

  static final MacOsPermissionsService instance = MacOsPermissionsService._();

  static const _channel = MethodChannel('begzar/system_proxy');

  bool get isSupported => !kIsWeb && Platform.isMacOS;

  /// Always true — macOS storage is local files, not Keychain.
  bool canUseKeychain = true;

  void enableKeychain() {
    canUseKeychain = true;
  }

  Future<({bool secureStorage, bool systemProxy})> loadCachedGrants() async {
    return (secureStorage: true, systemProxy: true);
  }

  Future<void> clearCache() async {}

  /// No-op: storage does not require a user permission dialog.
  Future<bool> requestSecureStorage() async {
    enableKeychain();
    return true;
  }

  /// Optional probe — not used as a launch gate anymore.
  Future<bool> requestSystemProxy() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('probeAccess') == true;
    } catch (e) {
      return false;
    }
  }
}
