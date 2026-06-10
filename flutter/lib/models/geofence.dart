import 'package:latlong2/latlong.dart';

class Geofence {
  final String id;
  final String name;
  final String mode; // 'fixed' | 'mobile'
  final double? centerLat;
  final double? centerLng;
  final double radiusM;
  final List<LatLng> path;
  final int? updatedAt;

  Geofence({
    required this.id,
    required this.name,
    required this.mode,
    this.centerLat,
    this.centerLng,
    required this.radiusM,
    this.path = const [],
    this.updatedAt,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    final lat = json['center_lat'] ?? json['centerLat'] ?? json['lat'];
    final lng = json['center_lng'] ?? json['centerLng'] ?? json['lng'];
    final radius = json['radius_m'] ?? json['radiusM'] ?? json['radius'] ?? 100.0;
    final rawPath = json['path'] as List<dynamic>? ?? [];
    final parsedPath = rawPath.map((p) {
      if (p is List) {
        // [lat, lng] format from backend internal storage
        return LatLng(
          ((p.isNotEmpty ? p[0] as num? : null) ?? 0).toDouble(),
          ((p.length > 1 ? p[1] as num? : null) ?? 0).toDouble(),
        );
      }
      // {"lat": ..., "lng": ...} format
      return LatLng(
        ((p['lat'] as num?) ?? 0).toDouble(),
        ((p['lng'] as num?) ?? 0).toDouble(),
      );
    }).toList();

    return Geofence(
      id: json['geofence_id'] ?? json['id'] ?? '',
      name: json['name'] as String? ?? '',
      mode: json['mode'] as String? ?? 'fixed',
      centerLat: lat is double ? lat : (lat as num?)?.toDouble(),
      centerLng: lng is double ? lng : (lng as num?)?.toDouble(),
      radiusM: radius is double ? radius : (radius as num).toDouble(),
      path: parsedPath,
      updatedAt: json['updated_at'] ?? json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'geofence_id': id,
        'name': name,
        'mode': mode,
        if (centerLat != null) 'lat': centerLat,
        if (centerLng != null) 'lng': centerLng,
        'radius_m': radiusM,
        'path': path.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      };
}
