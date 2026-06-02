import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool _isScanning = false;

  Future<void> linkPatient(
    String patientId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final currentUid = currentUser.uid;

    // =========================
    // GET CURRENT USER
    // =========================

    final currentUserDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUid)
        .get();

    final currentRole = currentUserDoc.data()?['role'];

    // =========================
    // VERIFY PATIENT
    // =========================

    final patientDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(patientId)
        .get();

    if (!patientDoc.exists) {
      throw Exception(
        "Patient not found",
      );
    }

    final patientRole = patientDoc.data()?['role'];

    if (patientRole != 'patient') {
      throw Exception(
        "QR is not a patient",
      );
    }

    // =========================
    // LINK CARETAKER
    // =========================

    if (currentRole == 'caretaker') {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUid)
          .collection("linked_patients")
          .doc(patientId)
          .set({
        "patientId": patientId,
        "linkedAt": Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .collection("linked_caretakers")
          .doc(currentUid)
          .set({
        "uid": currentUid,
        "email": currentUser.email,
        "role": "caretaker",
        "linkedAt": Timestamp.now(),
      });
    }

    // =========================
    // LINK GUARDIAN
    // =========================

    else if (currentRole == 'guardian') {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUid)
          .collection("linked_patients")
          .doc(patientId)
          .set({
        "patientId": patientId,
        "linkedAt": Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .collection("linked_guardians")
          .doc(currentUid)
          .set({
        "uid": currentUid,
        "email": currentUser.email,
        "role": "guardian",
        "linkedAt": Timestamp.now(),
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scan Patient QR",
        ),
      ),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_isScanning) return;

          _isScanning = true;

          try {
            final barcode = capture.barcodes.first;

            final raw = barcode.rawValue;

            if (raw == null) {
              _isScanning = false;
              return;
            }

            final qrData = jsonDecode(raw);

            if (qrData['type'] != 'patient_link') {
              throw Exception(
                "Invalid QR Code",
              );
            }

            final patientId = qrData['patientId'];

            await linkPatient(
              patientId,
            );

            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Patient linked successfully",
                  ),
                ),
              );

              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString(),
                  ),
                ),
              );
            }
          } finally {
            _isScanning = false;
          }
        },
      ),
    );
  }
}
