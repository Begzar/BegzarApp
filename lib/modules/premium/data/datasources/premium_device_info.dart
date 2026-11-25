import 'dart:io';

import 'package:flutter/services.dart';

/// Resolves a human-readable device label for Premium API (login / device list).
class PremiumDeviceInfo {
  static const _channel = MethodChannel('cloud.begzar.begzar/device_info');

  String? _cachedName;

  Future<String> getDeviceName() async {
    if (_cachedName != null && _cachedName!.isNotEmpty) {
      return _cachedName!;
    }

    try {
      final name = await _channel.invokeMethod<String>('getDeviceName');
      _cachedName = name != null && name.trim().isNotEmpty
          ? name.trim()
          : _fallbackName();
    } catch (_) {
      _cachedName = _fallbackName();
    }

    return _cachedName!;
  }

  String _fallbackName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    return Platform.operatingSystem;
  }
}
