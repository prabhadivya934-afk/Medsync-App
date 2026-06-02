import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  GoogleMapController? mapController;

  LatLng? selectedLocation;
  double radius = 200;

  String selectedType = "home";

  Future<LatLng> getCurrentLatLng() async {
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> setCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    LatLng pos = await getCurrentLatLng();

    setState(() {
      selectedLocation = pos;
    });

    mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
  }

  void saveLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || selectedLocation == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('locations')
        .doc(selectedType)
        .set({
      'lat': selectedLocation!.latitude,
      'lng': selectedLocation!.longitude,
      'radius': radius,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$selectedType location saved")));
  }

  @override
  void initState() {
    super.initState();
    setCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MedSync Location Setup"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: selectedLocation == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation!,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) {
                      mapController = controller;
                    },
                    onTap: (pos) {
                      setState(() {
                        selectedLocation = pos;
                      });
                    },
                    markers: selectedLocation == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId("selected"),
                              position: selectedLocation!,
                            ),
                          },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButton<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: "home", child: Text("Home")),
                    DropdownMenuItem(
                      value: "hospital",
                      child: Text("Hospital"),
                    ),
                    DropdownMenuItem(
                      value: "pharmacy",
                      child: Text("Pharmacy"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text("Radius: ${radius.toInt()} m"),
                Slider(
                  value: radius,
                  min: 100,
                  max: 1000,
                  divisions: 9,
                  label: radius.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      radius = value;
                    });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: setCurrentLocation,
                        child: const Text("Use My Location"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: saveLocation,
                        child: const Text("Save"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
