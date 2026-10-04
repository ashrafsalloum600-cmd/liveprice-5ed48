import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/firebase_options.dart';
import 'package:liveprice/screens/notifications_screen.dart';
import 'package:liveprice/services/notification_center.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void registerFcmBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

Future<void> initFcm() async {
  final messaging = FirebaseMessaging.instance;

  if (kIsWeb) {
    final webPermission = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (webPermission.authorizationStatus == AuthorizationStatus.authorized) {
      const webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY', defaultValue: 'REPLACE_WITH_WEB_VAPID_KEY');

      if (webVapidKey != 'REPLACE_WITH_WEB_VAPID_KEY') {
        await messaging.getToken(vapidKey: webVapidKey);
      } else {
        debugPrint('FCM web VAPID key missing. Add --dart-define=FCM_WEB_VAPID_KEY=<key> to the web build.');
      }
    }
  } else {
    await messaging.requestPermission();
    await messaging.subscribeToTopic('all_traders');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n != null) {
      NotificationCenter.instance.addFromRemote(n.title ?? '', n.body ?? '');
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());

  final initial = await messaging.getInitialMessage();
  if (initial != null) _openNotifications();
}

void _openNotifications() {
  navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
}
