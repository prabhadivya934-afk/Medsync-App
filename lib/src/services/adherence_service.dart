import 'package:cloud_firestore/cloud_firestore.dart';

class AdherenceService {
  static Future<double> calculateAdherence(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .get();

    int totalDoses = 0;
    int takenDoses = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      List times = data['times'] ?? [];
      List takenStatus = data['takenStatus'] ?? [];

      totalDoses += times.length;

      for (var status in takenStatus) {
        if (status == true) takenDoses++;
      }
    }

    if (totalDoses == 0) return 0;

    return (takenDoses / totalDoses) * 100;
  }
}
