import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static final _db = FirebaseFirestore.instance;

  // ➤ SAVE LOCATION
  static Future<void> saveLocation({
    required String name,
    required double lat,
    required double lng,
    double radius = 200,
    String note = "",
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.collection("users").doc(uid).collection("locations").add({
      "name": name,
      "lat": lat,
      "lng": lng,
      "radius": radius,
      "note": note,
      "createdAt": Timestamp.now(),
    });
  }

  // ➤ GET LOCATIONS STREAM
  static Stream<List<Map<String, dynamic>>> getLocations() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection("users")
        .doc(uid)
        .collection("locations")
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {"id": doc.id, ...doc.data()}).toList());
  }

  // ➤ DELETE LOCATION
  static Future<void> deleteLocation(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection("users")
        .doc(uid)
        .collection("locations")
        .doc(id)
        .delete();
  }
}
