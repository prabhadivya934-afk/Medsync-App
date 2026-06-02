import 'package:flutter/services.dart';

class GeofenceService {
  static const platform = MethodChannel('geofence_channel');

  static Future<void> startGeofence({
    required String id,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    await platform.invokeMethod('addGeofence', {
      "id": id,
      "lat": lat,
      "lng": lng,
      "radius": radius,
    });
  }
}
