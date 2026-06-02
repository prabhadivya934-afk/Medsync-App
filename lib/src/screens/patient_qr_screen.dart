import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PatientQRScreen extends StatelessWidget {
  const PatientQRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("My QR Code")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Show this QR to caretaker / guardian",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: jsonEncode({
                "type": "patient_link",
                "patientId": FirebaseAuth.instance.currentUser!.uid,
                "role": "patient",
              }),
              size: 220,
            ),
            const SizedBox(height: 20),
            Text(
              "Patient ID: ${user?.uid}",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
