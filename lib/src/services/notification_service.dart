import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application/src/screens/reminder_popup_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../main.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// INIT SYSTEM
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;

        if (payload == null) {
          return;
        }

        final data = jsonDecode(payload);

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ReminderPopupScreen(
              medicineId: data['medicineId'],
              medicineName: data['medicineName'],
              dosage: data['dosage'],
              time: data['time'],
              imageUrl: data['imageUrl'],
            ),
          ),
        );
      },
    );
    await _createChannels();
  }

  static Future<void> scheduleFromMedicineTimes({
    required String medicineName,
    required String dosage,
    required List<Map<String, dynamic>> times,
    required String medicineId,
  }) async {
    final patientDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(times.first['patientId'])
        .get();

    final role = patientDoc.data()?['role'];

    if (role != 'patient') {
      return;
    }
    final baseId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (int i = 0; i < times.length; i++) {
      final time = times[i];

      final int hour = time["hour"];

      final int minute = time["minute"];

      DateTime scheduledTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hour,
        minute,
      );

      // ==========================
      // NEXT DAY IF PASSED
      // ==========================

      if (scheduledTime.isBefore(
        DateTime.now(),
      )) {
        scheduledTime = scheduledTime.add(
          const Duration(
            days: 1,
          ),
        );
      }

      // ==========================
      // PRE REMINDER
      // ==========================

      final preReminderTime = scheduledTime.subtract(
        const Duration(
          minutes: 4,
        ),
      );

      await scheduleMedicineReminder(
        id: baseId + i + 1000,
        title: "Upcoming Medicine",
        body: "$medicineName in 4 minutes",
        scheduledTime: preReminderTime,
        patientId: time['patientId'],
        medicineId: medicineId,
        payload: jsonEncode({
          "medicineId": medicineId,
          "medicineName": medicineName,
          "dosage": dosage,
          "time": time['dose'],
          "imageUrl": "",
        }),
      );

      // ==========================
      // MAIN REMINDER
      // ==========================

      await scheduleMedicineReminder(
        id: baseId + i,
        title: "${time['dose']} Medicine Reminder",
        body: "Take $medicineName ($dosage)",
        scheduledTime: scheduledTime,
        patientId: time['patientId'],
        medicineId: medicineId,
        payload: jsonEncode({
          "medicineId": medicineId,
          "medicineName": medicineName,
          "dosage": dosage,
          "time": time['dose'],
          "imageUrl": "",
        }),
      );

      // ==========================
      // MISSED CHECK
      // ==========================

      Future.delayed(
        scheduledTime
            .add(
              const Duration(
                minutes: 10,
              ),
            )
            .difference(DateTime.now()),
        () async {
          await checkMissedDose(
            patientId: time['patientId'],
            medicineId: medicineId,
            medicineName: medicineName,
            dose: time['dose'],
            reminderTime: scheduledTime,
          );
        },
      );
    }
  }

  /// ANDROID CHANNELS (IMPORTANT FOR PRODUCTION)
  static Future<void> _createChannels() async {
    const AndroidNotificationChannel medicineChannel =
        AndroidNotificationChannel(
      'medicine_reminders',
      'Medicine Reminders',
      description: 'Notifications for medicine schedules',
      importance: Importance.max,
      playSound: true,
    );

    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'caretaker_alerts',
      'Caretaker Alerts',
      description: 'Alerts for caretakers',
      importance: Importance.high,
      playSound: true,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(medicineChannel);
    await androidPlugin?.createNotificationChannel(alertChannel);
  }

  /// SCHEDULE MEDICINE REMINDER
  static Future<void> scheduleMedicineReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? patientId,
    String? medicineId,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> checkMissedDose({
    required String patientId,
    required String medicineId,
    required String medicineName,
    required String dose,
    required DateTime reminderTime,
  }) async {
    final now = DateTime.now();

    // =====================
    // WAIT 10 MINUTES
    // =====================

    if (now.isBefore(
      reminderTime.add(
        const Duration(
          minutes: 10,
        ),
      ),
    )) {
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('medicine_schedule')
        .doc(medicineId)
        .get();

    if (!doc.exists) {
      return;
    }

    final data = doc.data();

    if (data == null) {
      return;
    }

    final today = DateTime.now().toIso8601String().split('T').first;

    final takenDates = data['takenDates'] ?? {};

    final todayData = takenDates[today] ?? {};

    final status = todayData[dose];

    // =====================
    // AUTO MARK MISSED
    // =====================

    if (status == null || status == 'pending') {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('medicine_schedule')
          .doc(medicineId)
          .set(
              {
            'takenDates': {
              today: {
                dose: 'missed',
              },
            },
          },
              SetOptions(
                merge: true,
              ));

      await markMissedDose(
        patientId: patientId,
        patientName: data['patientName'] ?? "Patient",
        medicineName: medicineName,
        dose: dose,
      );
    }
  }

  static Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_alerts',
          'Location Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> scheduleSnooze({
    required int id,
    required String medName,
    required String medicineId,
    int snoozeMinutes = 10,
  }) async {
    final scheduledTime = DateTime.now().add(
      Duration(minutes: snoozeMinutes),
    );

    await _notifications.zonedSchedule(
      id,
      "Snoozed Reminder",
      "Time to take $medName",
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> showLowStockNotification(
    String medicineName,
    int stock,
  ) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Low Stock Alert",
      "$medicineName stock is low ($stock remaining)",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'caretaker_alerts',
          'Caretaker Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> scheduleInitialReminders({
    required int id,
    required String medicineName,
    required String dosage,
    required DateTime firstTime,
  }) async {
    await _notifications.zonedSchedule(
      id,
      "Medicine Reminder",
      "Take $medicineName $dosage",
      tz.TZDateTime.from(firstTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// INSTANT CARETAKER ALERT
  static Future<void> sendCaretakerAlert({
    required String caretakerId,
    required String message,
  }) async {
    await FirebaseFirestore.instance.collection('caretaker_alerts').add({
      "caretakerId": caretakerId,
      "message": message,
      "timestamp": FieldValue.serverTimestamp(),
      "type": "alert",
    });

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Caretaker Alert",
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'caretaker_alerts',
          'Caretaker Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> sendPushAlert({
    required String token,
    required String patientName,
    required String medicineName,
    required String dose,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          "http://10.253.207.229:3000/send-push-alert",
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "token": token,
          "patientName": patientName,
          "medicineName": medicineName,
          "dose": dose,
        }),
      );

      print(
        response.body,
      );
    } catch (e) {
      print(
        "SEND PUSH ERROR: $e",
      );
    }
  }

  static Future<void> sendGuardianAlert({
    required String guardianId,
    required String message,
  }) async {
    await FirebaseFirestore.instance.collection('guardian_alerts').add({
      "guardianId": guardianId,
      "message": message,
      "timestamp": FieldValue.serverTimestamp(),
      "type": "alert",
    });

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Guardian Alert",
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'caretaker_alerts',
          'Guardian Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// MISSED DOSE HANDLER
  static Future<void> markMissedDose({
    required String patientId,
    required String patientName,
    required String medicineName,
    required String dose,
  }) async {
    // =====================
    // SAVE MISSED DOSE
    // =====================

    await FirebaseFirestore.instance.collection('missed_doses').add({
      "patientId": patientId,
      "patientName": patientName,
      "medicine": medicineName,
      "dose": dose,
      "timestamp": FieldValue.serverTimestamp(),
    });

    // =====================
    // GET LINKED CARETAKERS
    // =====================

    final caretakerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('linked_caretakers')
        .get();

    for (final caretaker in caretakerSnapshot.docs) {
      final caretakerData = caretaker.data();

      final caretakerToken = caretakerData['fcmToken'];

      if (caretakerToken != null) {
        await sendPushAlert(
          token: caretakerToken,
          patientName: patientName,
          medicineName: medicineName,
          dose: dose,
        );
      }
    }

    // =====================
    // GET LINKED GUARDIANS
    // =====================

    final guardianSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('linked_guardians')
        .get();

    for (final guardian in guardianSnapshot.docs) {
      final guardianData = guardian.data();

      final guardianToken = guardianData['fcmToken'];

      if (guardianToken != null) {
        await sendPushAlert(
          token: guardianToken,
          patientName: patientName,
          medicineName: medicineName,
          dose: dose,
        );
      }
    }
  }

  static Future<void> requestPermission() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
  }
}
