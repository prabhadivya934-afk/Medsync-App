import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';

class ReminderPopupScreen extends StatelessWidget {
  final String? medicineId;
  final String medicineName;
  final String dosage;
  final String time;
  final String? imageUrl;

  const ReminderPopupScreen({
    super.key,
    this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.time,
    this.imageUrl,
  });

  String getTodayKey() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }

  Future<void> markTaken(
    BuildContext context,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || medicineId == null) {
      Navigator.pop(context);
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .doc(medicineId);

    final snapshot = await docRef.get();

    final data = snapshot.data();

    final stock = ((data?['stock'] ?? 0) as num).toInt();

    // =====================
    // SAVE TAKEN STATUS
    // =====================

    await docRef.set(
        {
          "takenDates": {
            getTodayKey(): {
              time.toLowerCase(): "taken",
            },
          },
          if (stock > 0) "stock": stock - 1,
        },
        SetOptions(
          merge: true,
        ));

    // =====================
    // SAVE HISTORY
    // =====================

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .add({
      "name": medicineName,
      "status": "taken",
      "time": Timestamp.now(),
    });

    if (context.mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            "$medicineName marked as taken",
          ),
        ),
      );
    }
  }

  Future<void> markSkipped(
    BuildContext context,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || medicineId == null) {
      Navigator.pop(context);
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .doc(medicineId)
        .set(
            {
          "takenDates": {
            getTodayKey(): {
              time.toLowerCase(): "skipped",
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
        .doc(user.uid)
        .collection('history')
        .add({
      "name": medicineName,
      "status": "skipped",
      "time": Timestamp.now(),
    });

    // =====================
    // ALERT CARETAKER
    // =====================

    await AlertService.sendMedicineAlert(
      patientId: user.uid,
      medicineName: medicineName,
      type: 'skipped',
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        imageUrl!,
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.medication,
                        size: 80,
                        color: Colors.green,
                      ),
                    ),
              const SizedBox(height: 30),
              const Text(
                "Time to take medicine",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                medicineName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (dosage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Dosage: $dosage",
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
              if (time.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Scheduled Time: $time",
                  style: const TextStyle(fontSize: 18, color: Colors.blue),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => markTaken(context),
                  child: const Text(
                    "Mark as Taken",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final snoozeTime = DateTime.now().add(
                      const Duration(
                        minutes: 6,
                      ),
                    );

                    await NotificationService.scheduleMedicineReminder(
                      id: medicineId.hashCode + 3,
                      title: medicineName,
                      body: "Final reminder",
                      scheduledTime: snoozeTime,
                      medicineId: medicineId,
                      payload: jsonEncode({
                        "medicineId": medicineId,
                        "medicineName": medicineName,
                        "dosage": dosage,
                        "time": time,
                        "imageUrl": imageUrl ?? "",
                      }),
                    );

                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Remind me in 10 minutes",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => markSkipped(context),
                  child: const Text("Skip", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
