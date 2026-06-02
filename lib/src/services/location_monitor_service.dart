import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class LocationMonitorService {
  static void startMonitoring(String uid) {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((Position position) async {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_locations')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        double lat = data['latitude'];
        double lng = data['longitude'];

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        // 🔥 200 meters radius trigger
        if (distance < 200) {
          NotificationService.showNotification(
            title: "Location Alert",
            body: data['note'] ?? "You reached a saved location",
          );
        }
      }
    });
  }
}
