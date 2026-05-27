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
    return LocationData(
      lat: (json['lat'] ?? json['latitude']).toDouble(),
      lng: (json['lng'] ?? json['longitude'] ?? json['lon']).toDouble(),
      insideGeofence: json['insideGeofence'] ?? json['inside_geofence'] ?? false,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}