import 'dart:io';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class ReminderScreen extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String time;
  final String imagePath;

  const ReminderScreen({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.imagePath,
  });

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
              /// Medicine Photo
              Container(
                height: 220,
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: imagePath.isNotEmpty
                        ? FileImage(File(imagePath))
                        : const AssetImage('assets/placeholder.png')
                            as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Time to take medicine!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                medicineName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 10),

              Text("Dosage: $dosage", style: const TextStyle(fontSize: 18)),

              const SizedBox(height: 10),

              Text("Time: $time", style: const TextStyle(fontSize: 18)),

              const SizedBox(height: 40),

              /// MARK AS TAKEN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Mark as Taken",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// REMIND LATER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () async {
                    /// 🔥 Schedule snooze after 4 minutes ONLY
                    await NotificationService.scheduleMedicineReminder(
                      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      title: medicineName,
                      body: "Snoozed reminder: take your medicine",
                      scheduledTime:
                          DateTime.now().add(const Duration(minutes: 10)),
                    );

                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Remind me in 10 min",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// SKIP
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () async {
                    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    await NotificationService.cancelReminder(notificationId);

                    Navigator.pop(context);
                  },
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
