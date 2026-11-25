import 'dart:io';

import 'package:begzar/core/security/native_security_service.dart';
import 'package:root_checker_plus/root_checker_plus.dart';

/// Startup security gate — fail closed on Android.
class SecurityGate {
  SecurityGate._();

  static Future<void> enforce() async {
    if (Platform.isAndroid) {
      await _enforceAndroid();
      return;
    }
    if (Platform.isIOS) {
      await _enforceIos();
    }
  }

  static Future<void> _enforceAndroid() async {
    try {
      final rooted = await RootCheckerPlus.isRootChecker();
      if (rooted == true) {
        exit(0);
      }
    } on Object {
      exit(0);
    }

    try {
      final flags = await NativeSecurityService.instance
          .performSecurityChecks();
      if (flags != 0) {
        exit(0);
      }
    } on Object {
      exit(0);
    }
  }

  static Future<void> _enforceIos() async {
    try {
      final jailbroken = await RootCheckerPlus.isJailbreak();
      if (jailbroken == true) {
        exit(0);
      }
    } on Object {
      exit(0);
    }
  }
}
