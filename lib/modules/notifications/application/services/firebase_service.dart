import 'dart:async';

import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/core/services/firebase_platform.dart';
import 'package:begzar/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// What a tap on a notification the app drew itself does.
///
/// A message that arrives while the app is open is shown as a local
/// notification, and Firebase's own `notification_open` never sees a tap on
/// one, so it is recorded here.
DidReceiveNotificationResponseCallback localNotificationTapRecorder(
  AnalyticsService analytics,
) =>
    (_) => unawaited(analytics.logLocalNotificationOpened());

/// Firebase Cloud Messaging Service
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  FirebaseMessaging get _messaging =>
      _firebaseMessaging ??= FirebaseMessaging.instance;

  /// Lightweight deferred startup path used after the first UI frame.
  ///
  /// [analytics] is handed in rather than reached for: this service is a
  /// singleton with no container of its own.
  Future<void> initializeDeferred({required AnalyticsService analytics}) async {
    if (!isFirebaseSupported || _initialized) {
      return;
    }
    _initialized = true;

    _setupMessageHandlers();
    await _initializeLocalNotifications(analytics);
  }

  /// Registers for FCM after notification permission has been granted.
  ///
  /// Nothing in the app reads the id registration hands back, so it is not
  /// kept.
  Future<void> ensureMessagingReady() async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      await _messaging.register().timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (_) {
      // Registration is optional at startup.
    }
  }

  /// Initialize local notifications (for Android foreground notifications)
  Future<void> _initializeLocalNotifications(AnalyticsService analytics) async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_vpn');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      // TODO: Navigate to specific screen based on payload
      onDidReceiveNotificationResponse: localNotificationTapRecorder(analytics),
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Show local notification when app is in foreground
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO: Navigate to specific screen based on message data
    });

    // Handle notification that opened the app from terminated state
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // TODO: Navigate to specific screen based on message data
      }
    });
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_vpn',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    if (!isFirebaseSupported) {
      return;
    }
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!isFirebaseSupported) {
      return;
    }
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!isFirebaseSupported) {
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
