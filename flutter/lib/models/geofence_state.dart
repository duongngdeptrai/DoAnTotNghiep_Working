class GeofenceState {
  final String mode;
  final double centerLat;
  final double centerLng;
  final int radiusM;
  final String source;
  final int? updatedAt;

  GeofenceState({
    required this.mode,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.source,
    this.updatedAt,
  });

  factory GeofenceState.fromJson(Map<String, dynamic> json) {
    return GeofenceState(
      mode: json['mode'] as String,
      centerLat: (json['center_lat'] ?? json['centerLat']).toDouble(),
      centerLng: (json['center_lng'] ?? json['centerLng']).toDouble(),
      radiusM: (json['radius_m'] ?? json['radiusM'] ?? json['radius']).toInt(),
      source: json['source'] as String,
      updatedAt: json['updated_at'] ?? json['updatedAt'],
    );
  }
}