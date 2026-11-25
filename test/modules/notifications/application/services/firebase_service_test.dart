import 'package:begzar/modules/notifications/application/services/firebase_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_analytics.dart';

void main() {
  group('localNotificationTapRecorder', () {
    // A notification that arrives while the app is open is drawn by the app
    // itself, and Firebase's own notification_open never sees a tap on it.
    test('should record a tap on a notification the app drew', () {
      final analytics = RecordingAnalytics();

      localNotificationTapRecorder(analytics)(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        ),
      );

      expect(analytics.callsTo(#logLocalNotificationOpened), hasLength(1));
    });
  });
}
