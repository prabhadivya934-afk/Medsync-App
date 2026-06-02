import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  static Future<void> addMedicine({
    required String name,
    required List<Map<String, int>> times,
    required List<String> days,
    String? dosage,
    int frequency = 1,
    int stock = 0,
    int lowStockThreshold = 5,
    String? imageUrl,
    String? caretakerContact,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .add({
          'name': name,
          'dosage': dosage ?? '',
          'frequency': frequency,
          'times': times,
          'days': days,
          'stock': stock,
          'lowStockThreshold': lowStockThreshold,
          'imageUrl': imageUrl,
          'caretakerContact': caretakerContact ?? '',
          'takenDates': {},
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
