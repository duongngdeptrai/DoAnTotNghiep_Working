class Alert {
  final String deviceId;
  final String type;
  final String event;
  final double lat;
  final double lng;
  final int timestamp;

  Alert({
    required this.deviceId,
    required this.type,
    required this.event,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      deviceId: json['deviceId'] as String,
      type: json['type'] as String,
      event: json['event'] as String,
      lat: (json['lat'] ?? json['latitude']).toDouble(),
      lng: (json['lng'] ?? json['longitude'] ?? json['lon']).toDouble(),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}