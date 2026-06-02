import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class LocationReminderService {
  static StreamSubscription<Position>? _positionSubscription;
  static bool _outsideAlertSent = false;

  static Future<bool> saveCurrentLocationAsHome() async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return false;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_latitude', position.latitude);
    await prefs.setDouble('home_longitude', position.longitude);
    await prefs.setDouble('home_radius_meters', 150);
    await prefs.setBool('location_reminders_enabled', true);

    await startMonitoring();
    return true;
  }

  static Future<void> startMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('location_reminders_enabled') ?? false;
    final homeLatitude = prefs.getDouble('home_latitude');
    final homeLongitude = prefs.getDouble('home_longitude');
    final radiusMeters = prefs.getDouble('home_radius_meters') ?? 150;

    if (!enabled || homeLatitude == null || homeLongitude == null) return;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    await _positionSubscription?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
      position,
    ) {
      final distance = Geolocator.distanceBetween(
        homeLatitude,
        homeLongitude,
        position.latitude,
        position.longitude,
      );

      if (distance > radiusMeters && !_outsideAlertSent) {
        _outsideAlertSent = true;
        NotificationService.showNotification(
          title: "Travel Reminder",
          body: "You left your saved location. Please check your medicines.",
        );
      }

      if (distance <= radiusMeters) {
        _outsideAlertSent = false;
      }
    });
  }

  static Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_reminders_enabled', false);
  }

  static Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
