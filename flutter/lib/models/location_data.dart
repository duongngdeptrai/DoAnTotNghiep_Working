class LocationData {
  final double lat;
  final double lng;
  final bool insideGeofence;
  final int timestamp;

  LocationData({
    required this.lat,
    required this.lng,
    required this.insideGeofence,
    required this.timestamp,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    final latVal = json['lat'] ?? json['latitude'];
    final lngVal = json['lng'] ?? json['longitude'] ?? json['lon'];

    return LocationData(
      lat: latVal is double ? latVal : (latVal as num?)?.toDouble() ?? 0.0,
      lng: lngVal is double ? lngVal : (lngVal as num?)?.toDouble() ?? 0.0,
      insideGeofence: json['insideGeofence'] ?? json['inside_geofence'] ?? false,
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  static int _parseTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
