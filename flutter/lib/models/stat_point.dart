class StatPoint {
  final double lat;
  final double lng;
  final int timestamp;

  StatPoint({required this.lat, required this.lng, required this.timestamp});

  factory StatPoint.fromJson(Map<String, dynamic> json) {
    return StatPoint(
      lat: ((json['lat'] as num?) ?? 0).toDouble(),
      lng: ((json['lng'] as num?) ?? 0).toDouble(),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}
