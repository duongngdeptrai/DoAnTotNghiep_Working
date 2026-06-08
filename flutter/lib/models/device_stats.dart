import 'stat_point.dart';

class DeviceStats {
  final double totalDistanceM;
  final int pointCount;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final List<StatPoint> trackPath;

  DeviceStats({
    required this.totalDistanceM,
    required this.pointCount,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.trackPath,
  });

  factory DeviceStats.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['track_path'] ?? json['trackPath'] ?? json['points']) as List<dynamic>? ?? [];
    return DeviceStats(
      totalDistanceM: ((json['total_distance_m'] ?? json['totalDistanceM'] ?? json['total_distance'] ?? 0) as num).toDouble(),
      pointCount: (json['point_count'] ?? json['pointCount'] ?? json['count'] ?? 0) as int,
      avgSpeedKmh: ((json['avg_speed_kmh'] ?? json['avgSpeedKmh'] ?? json['avg_speed'] ?? 0) as num).toDouble(),
      maxSpeedKmh: ((json['max_speed_kmh'] ?? json['maxSpeedKmh'] ?? json['max_speed'] ?? 0) as num).toDouble(),
      trackPath: rawPath.map((p) => StatPoint.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}
