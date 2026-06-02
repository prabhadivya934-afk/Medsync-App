import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/screens/caretaker_dashboard_screen.dart';

import 'package:flutter_application/src/screens/home_screen.dart';
import 'package:flutter_application/src/screens/caretaker_dashboard_screen.dart';
import 'package:flutter_application/src/screens/guardian_dashboard_screen.dart';

class RoleBasedScreen extends StatelessWidget {
  const RoleBasedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final role = data['role'] ?? 'patient';

        // PATIENT
        if (role == 'patient') {
          return const HomeScreen();
        }

        // CARETAKER
        if (role == 'caretaker') {
          return const CaretakerDashboard();
        }

        // GUARDIAN
        if (role == 'guardian') {
          return const GuardianDashboardScreen();
        }

        // DEFAULT
        return const HomeScreen();
      },
    );
  }
}
