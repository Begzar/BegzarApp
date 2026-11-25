import 'dart:async';

import 'package:begzar/modules/ads/presentation/controllers/connection_ad_handler.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/core/services/firebase_platform.dart';
import 'package:begzar/modules/notifications/application/services/firebase_service.dart';
import 'package:begzar/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';

/// Runs heavy startup work after the first frame so UI can appear immediately.
class AppBootstrap {
  static Future<void>? _firebaseCoreFuture;
  static bool _deferredStarted = false;

  static Future<void> ensureFirebaseCore() {
    if (!isFirebaseSupported) {
      return Future.value();
    }

    if (Firebase.apps.isNotEmpty) {
      return Future.value();
    }

    return _firebaseCoreFuture ??= Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  /// [adHandler] and [analytics] are handed in rather than reached for:
  /// bootstrap is static and has no container of its own, and the caller that
  /// does have one is the right place to resolve them.
  static void startDeferredInitialization(
    ConnectionAdHandler adHandler,
    AnalyticsService analytics,
  ) {
    if (_deferredStarted) {
      return;
    }
    _deferredStarted = true;
    unawaited(_runDeferredInitialization(adHandler, analytics));
  }

  static Future<void> _runDeferredInitialization(
    ConnectionAdHandler adHandler,
    AnalyticsService analytics,
  ) async {
    try {
      final tasks = <Future<void>>[adHandler.initialize()];

      if (isFirebaseSupported) {
        await ensureFirebaseCore();
        tasks.addAll([
          FirebaseService().initializeDeferred(analytics: analytics),
          FirebaseInAppMessaging.instance.setMessagesSuppressed(false),
        ]);
      }

      await Future.wait(tasks);
    } catch (_) {
      // Non-critical services; app should remain usable.
    }
  }
}
