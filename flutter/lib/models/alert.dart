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
    final latVal = json['lat'] ?? json['latitude'];
    final lngVal = json['lng'] ?? json['longitude'] ?? json['lon'];
    final ts = json['timestamp'];

    return Alert(
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      event: json['event'] as String? ?? json['message'] as String? ?? '',
      lat: latVal is double ? latVal : (latVal as num?)?.toDouble() ?? 0.0,
      lng: lngVal is double ? lngVal : (lngVal as num?)?.toDouble() ?? 0.0,
      timestamp: ts is int ? ts : (ts as num?)?.toInt() ?? 0,
    );
  }
}
