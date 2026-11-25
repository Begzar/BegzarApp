import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls OS system proxy (Windows WinINET).
class WindowsSystemProxyService {
  WindowsSystemProxyService._();

  static final WindowsSystemProxyService instance =
      WindowsSystemProxyService._();

  static const _channel = MethodChannel('begzar/system_proxy');

  bool get isSupported => !kIsWeb && Platform.isWindows;

  /// Sets system proxy to `host:port` (HTTP/HTTPS).
  Future<bool> setProxy({required String host, required int port}) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setProxy', {
        'host': host,
        'port': port,
      });
      return ok == true;
    } catch (e) {
      return false;
    }
  }

  /// Restores the previous system proxy settings if we changed them.
  Future<bool> clearProxy() async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('clearProxy');
      return ok == true;
    } catch (e) {
      return false;
    }
  }
}
