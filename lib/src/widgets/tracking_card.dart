import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackingCard extends StatelessWidget {
  final String docId;
  final String name;
  final String time;
  final int stock;

  const TrackingCard({
    super.key,
    required this.docId,
    required this.name,
    required this.time,
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isLowStock = stock <= 5;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 18)),
            Text("Time: $time"),
            Text(
              "Stock: $stock",
              style: TextStyle(color: isLowStock ? Colors.red : Colors.black),
            ),

            Row(
              children: [
                ElevatedButton(
                  onPressed: stock > 0
                      ? () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('medicines')
                              .doc(docId)
                              .update({'stock': stock - 1});
                        }
                      : null,
                  child: const Text("Take"),
                ),

                const SizedBox(width: 10),

                OutlinedButton(onPressed: () {}, child: const Text("Skip")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
