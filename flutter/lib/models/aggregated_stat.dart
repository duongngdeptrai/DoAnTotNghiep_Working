class AggregatedStat {
  final String label;
  final double totalDistanceM;

  AggregatedStat({required this.label, required this.totalDistanceM});

  factory AggregatedStat.fromJson(Map<String, dynamic> json) {
    return AggregatedStat(
      label: (json['label'] ?? json['period'] ?? json['time'] ?? '').toString(),
      totalDistanceM: ((json['total_distance_m'] ?? json['totalDistanceM'] ?? json['distance'] ?? 0) as num).toDouble(),
    );
  }
}
