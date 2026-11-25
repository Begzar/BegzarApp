import 'dart:io';

import 'package:begzar/core/services/firebase_platform.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

/// Checks and requests notification permission required to use the app.
class NotificationPermissionService {
  static final NotificationPermissionService _instance =
      NotificationPermissionService._internal();

  factory NotificationPermissionService() => _instance;

  NotificationPermissionService._internal();

  Future<bool> isGranted() async {
    if (Platform.isIOS && isFirebaseSupported) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }

    return true;
  }

  Future<bool> request() async {
    if (Platform.isIOS && isFirebaseSupported) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }

    return true;
  }

  Future<bool> shouldOpenSettings() async {
    if (Platform.isIOS && isFirebaseSupported) {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.denied;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isPermanentlyDenied;
    }

    return false;
  }

  Future<void> openSettings() => openAppSettings();
}
