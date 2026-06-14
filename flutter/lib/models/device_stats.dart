import 'stat_point.dart';

class DeviceStats {
  final double totalDistanceM;
  final double avgSpeedKmh;
  final int outsideCount;
  final List<StatPoint> trackPath;

  DeviceStats({
    required this.totalDistanceM,
    required this.avgSpeedKmh,
    required this.outsideCount,
    required this.trackPath,
  });

  factory DeviceStats.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['track_path'] ?? json['trackPath'] ?? json['points']) as List<dynamic>? ?? [];
    return DeviceStats(
      totalDistanceM: ((json['total_distance_m'] ?? json['totalDistanceM'] ?? json['total_distance'] ?? 0) as num).toDouble(),
      avgSpeedKmh: ((json['avg_speed_kmh'] ?? json['avgSpeedKmh'] ?? json['avg_speed'] ?? 0) as num).toDouble(),
      outsideCount: (json['outsideCount'] ?? json['outside_count'] ?? 0) as int,
      trackPath: rawPath.map((p) => StatPoint.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}
