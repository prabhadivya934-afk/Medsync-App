import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_service.dart';

class AlertService {
  static Future<void> sendMedicineAlert({
    required String patientId,
    required String medicineName,
    required String type,
  }) async {
    final patientDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .get();

    final patientData = patientDoc.data() ?? {};

    final patientName = patientData['name'] ?? 'Patient';

    // =========================
    // GET LINKED CARETAKERS
    // =========================

    final caretakerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('linked_caretakers')
        .get();

    for (final caretaker in caretakerSnapshot.docs) {
      final caretakerId = caretaker.id;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(caretakerId)
          .collection('alerts')
          .add({
        'type': type,
        'medicineName': medicineName,
        'patientName': patientName,
        'time': Timestamp.now(),
        'read': false,
      });
    }

    // =========================
    // GET LINKED GUARDIANS
    // =========================

    final guardianSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(patientId)
        .collection('linked_guardians')
        .get();

    for (final guardian in guardianSnapshot.docs) {
      final guardianId = guardian.id;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(guardianId)
          .collection('alerts')
          .add({
        'type': type,
        'medicineName': medicineName,
        'patientName': patientName,
        'time': Timestamp.now(),
        'read': false,
      });
    }
  }

  static Future<void> checkMissedDose({
    required String patientId,
    required String medicineId,
    required String medicineName,
    required String dose,
    required DateTime reminderTime,
  }) async {
    final now = DateTime.now();

    // =========================
    // WAIT 30 MINUTES
    // =========================

    if (now.isBefore(
      reminderTime.add(
        const Duration(
          minutes: 10,
        ),
      ),
    )) {
      return;
    }

    // =========================
    // GET MEDICINE DOC
    // =========================

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

    // =========================
    // TODAY KEY
    // =========================

    final today = DateTime.now().toIso8601String().split('T').first;

    final takenDates = data['takenDates'] ?? {};

    final todayData = takenDates[today] ?? {};

    final status = todayData[dose];

    // =========================
    // ONLY MARK IF PENDING
    // =========================

    if (status == null || status == 'pending') {
      // =====================
      // SAVE MISSED
      // =====================

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

      // =====================
      // SAVE HISTORY
      // =====================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('history')
          .add({
        'name': medicineName,
        'status': 'missed',
        'time': Timestamp.now(),
      });

      // =====================
      // SEND ALERT
      // =====================

      await sendMedicineAlert(
        patientId: patientId,
        medicineName: medicineName,
        type: 'missed',
      );
    }
  }
}
