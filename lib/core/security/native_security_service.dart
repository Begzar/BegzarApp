import 'dart:io';

import 'package:flutter/services.dart';

/// Native Android security bridge (JNI → C++).
class NativeSecurityService {
  NativeSecurityService._();

  static const MethodChannel _channel = MethodChannel(
    'cloud.begzar.begzar/security',
  );

  static final NativeSecurityService instance = NativeSecurityService._();

  static const int threatDebugger = 1;
  static const int threatInstrumentation = 2;
  static const int threatTampered = 4;
  static const int threatEmulator = 8;

  Future<int> performSecurityChecks() async {
    if (!Platform.isAndroid) return 0;
    final flags = await _channel.invokeMethod<int>('performSecurityChecks');
    return flags ?? 0;
  }
}
