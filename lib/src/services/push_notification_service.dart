import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ✅ INITIALIZE
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission();

    // Android setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(
        title: message.notification?.title ?? "MedSync",
        body: message.notification?.body ?? "",
      );
    });
  }

  // ✅ GET TOKEN
  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  // ✅ SHOW LOCAL NOTIFICATION
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medsync_channel',
      'MedSync Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }

  static Future<void> saveTokenToFirestore(
    String userId,
  ) async {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));

    print("FCM TOKEN SAVED");
  }

  static Future<void> sendPushToUser({
    required String token,
    required String title,
    required String body,
  }) async {
    const serverKey = 'YOUR_FIREBASE_SERVER_KEY';

    try {
      await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/fcm/send',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          "priority": "high",
          "notification": {
            "title": title,
            "body": body,
          },
          "to": token,
        }),
      );

      print(
        "PUSH SENT SUCCESS",
      );
    } catch (e) {
      print(
        "PUSH ERROR: $e",
      );
    }
  }
}
