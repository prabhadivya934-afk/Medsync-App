class SavedLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final String note;

  SavedLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "lat": lat,
      "lng": lng,
      "radius": radius,
      "note": note,
    };
  }

  factory SavedLocation.fromMap(String id, Map<String, dynamic> data) {
    return SavedLocation(
      id: id,
      name: data["name"] ?? "",
      lat: (data["lat"] ?? 0).toDouble(),
      lng: (data["lng"] ?? 0).toDouble(),
      radius: (data["radius"] ?? 200).toDouble(),
      note: data["note"] ?? "",
    );
  }
}
