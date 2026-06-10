import 'geofence.dart';

class GeofenceState {
  final String mode;
  final double centerLat;
  final double centerLng;
  final double radiusM;
  final String source;
  final int? updatedAt;
  final List<Geofence> geofences;

  GeofenceState({
    required this.mode,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.source,
    this.updatedAt,
    this.geofences = const [],
  });

  factory GeofenceState.fromJson(Map<String, dynamic> json) {
    final lat = json['center_lat'] ?? json['centerLat'];
    final lng = json['center_lng'] ?? json['centerLng'];
    final radius = json['radius_m'] ?? json['radiusM'] ?? json['radius'];
    final rawGeofences = json['geofences'] as List<dynamic>? ?? [];

    return GeofenceState(
      mode: json['mode'] as String? ?? 'fixed',
      centerLat: lat is double ? lat : (lat as num?)?.toDouble() ?? 0.0,
      centerLng: lng is double ? lng : (lng as num?)?.toDouble() ?? 0.0,
      radiusM: radius is double ? radius : (radius as num?)?.toDouble() ?? 100.0,
      source: json['source'] as String? ?? 'fixed',
      updatedAt: json['updated_at'] ?? json['updatedAt'],
      geofences: rawGeofences
          .whereType<Map<String, dynamic>>()
          .map((g) {
            try {
              return Geofence.fromJson(g);
            } catch (_) {
              return null;
            }
          })
          .whereType<Geofence>()
          .toList(),
    );
  }
}
