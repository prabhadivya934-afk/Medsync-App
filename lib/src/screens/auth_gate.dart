import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/screens/caretaker_dashboard_screen.dart';
import 'package:flutter_application/src/screens/guardian_dashboard_screen.dart';
import 'package:flutter_application/src/screens/home_screen.dart';
import 'package:flutter_application/src/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // NOT LOGGED IN
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // FETCH USER ROLE
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    "Something went wrong",
                  ),
                ),
              );
            }

            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              return const LoginScreen();
            }

            final data = roleSnapshot.data!.data() as Map<String, dynamic>?;

            if (data == null) {
              return const LoginScreen();
            }

            final role = data['role'] ?? 'patient';

            // PATIENT
            if (role == 'patient') {
              return const HomeScreen();
            }

            // CARETAKER
            else if (role == 'caretaker') {
              return const CaretakerDashboard();
            }

            // GUARDIAN
            else if (role == 'guardian') {
              return const GuardianDashboardScreen();
            }

            // DEFAULT
            return const HomeScreen();
          },
        );
      },
    );
  }
}
