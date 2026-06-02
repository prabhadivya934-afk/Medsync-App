import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class RefillScreen extends StatefulWidget {
  final String docId;

  const RefillScreen({super.key, required this.docId});

  @override
  State<RefillScreen> createState() => _RefillScreenState();
}

class _RefillScreenState extends State<RefillScreen> {
  final stockController = TextEditingController();

  Future updateStock() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (stockController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter stock value")));
      return;
    }

    int addedStock = int.tryParse(stockController.text) ?? 0;

    if (addedStock <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid stock")));
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicines')
        .doc(widget.docId);

    /// 🔹 Get current data safely
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Medicine not found")));
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>;

    int currentStock = (data['stock'] ?? 0) as int;
    int threshold = data['lowStockThreshold'] ?? 5;
    String medName = data['name'] ?? "Medicine";

    int newStock = currentStock + addedStock;

    /// 🔹 Update Firestore
    await docRef.update({'stock': newStock});

    /// 🔔 LOW STOCK NOTIFICATION
    if (newStock <= threshold) {
      await NotificationService.showLowStockNotification(medName, newStock);
    }

    /// ✅ SUCCESS MESSAGE
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Stock updated successfully")));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Refill Stock")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔢 STOCK INPUT
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Add Stock (e.g. 10 tablets)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            /// 🔘 BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateStock,
                child: const Text("Update Stock"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
