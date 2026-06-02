import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? role;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  Future<void> loadRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          role = null;
          loading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      role = doc.data()?['role']?.toString().toLowerCase().trim();
    } catch (e) {
      role = null;
      debugPrint("Role fetch error: $e");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Widget _placeholder(String title) {
    return Scaffold(
      body: Center(
        child: Text(
          "$title Dashboard\n(Not implemented yet)",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (role) {
      case "caretaker":
        return _placeholder("Caretaker");

      case "guardian":
        return _placeholder("Guardian");

      case "patient":
        return _placeholder("Patient");

      default:
        return const Scaffold(
          body: Center(child: Text("Invalid or missing role")),
        );
    }
  }
}
