import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/top_nav.dart';

class StatisticsScreen extends StatefulWidget {
  final String? initialDeviceId;

  const StatisticsScreen({super.key, this.initialDeviceId});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late String _deviceId;
  String _range = '24h';
  bool _loading = false;
  String? _error;
  DeviceStats? _stats;
  List<AggregatedStat> _aggregated = [];

  static const _ranges = ['24h', '7d', '30d', 'all'];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _deviceId = widget.initialDeviceId ??
        (provider.devices.isNotEmpty ? provider.devices.first.deviceId : '');
    if (_deviceId.isNotEmpty) _loadStats();
  }

  Future<void> _loadStats() async {
    if (_deviceId.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final (interval, start) = switch (_range) {
      '24h'  => ('hour',  now - 86400),
      '7d'   => ('day',   now - 604800),
      '30d'  => ('week',  now - 2592000),
      _      => ('year',  now - 31536000),
    };

    final api = context.read<AppProvider>().apiService;
    try {
      final results = await Future.wait([
        api.fetchDeviceStats(_deviceId, start: start, end: now),
        api.fetchAggregatedStats(_deviceId, start: start, end: now, interval: interval),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as DeviceStats;
          _aggregated = results[1] as List<AggregatedStat>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F1A), Color(0xFF0F172A), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              TopNav(
                token: provider.token,
                userEmail: provider.currentUser?.email,
                onLogout: () {
                  provider.logout();
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                onNavigateHome: () => Navigator.of(context).pop(),
                onNavigateProfile: () => Navigator.of(context).pushNamed('/profile'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(provider),
                      const SizedBox(height: 20),
                      if (_loading)
                        const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
                        ))
                      else if (_error != null)
                        _buildError()
                      else if (_stats == null)
                        _buildEmpty()
                      else ...[
                        _buildStatsGrid(),
                        const SizedBox(height: 20),
                        if (_aggregated.isNotEmpty) ...[
                          _buildBarChart(),
                          const SizedBox(height: 20),
                        ],
                        if (_stats!.trackPath.length > 1) ...[
                          _buildTrackMap(),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thống kê thiết bị',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        // Device selector
        if (provider.devices.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: DropdownButton<String>(
              value: provider.devices.any((d) => d.deviceId == _deviceId) ? _deviceId : null,
              underline: const SizedBox(),
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              hint: const Text('Chọn thiết bị', style: TextStyle(color: Colors.white54)),
              isExpanded: true,
              items: provider.devices.map((d) => DropdownMenuItem(
                value: d.deviceId,
                child: Text(d.deviceId, style: const TextStyle(color: Colors.white)),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() { _deviceId = v; _stats = null; _aggregated = []; });
                _loadStats();
              },
            ),
          ),
        const SizedBox(height: 12),
        // Range selector
        Row(
          children: _ranges.map((r) {
            final active = _range == r;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_range != r) {
                    setState(() { _range = r; _stats = null; _aggregated = []; });
                    _loadStats();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                      color: active ? Colors.black87 : Colors.white54,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
          TextButton(
            onPressed: _loadStats,
            child: const Text('Thử lại', style: TextStyle(color: Color(0xFF22D3EE))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu', style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 4),
            Text('Chọn thiết bị và khoảng thời gian khác',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final s = _stats!;
    final cards = [
      ('Tổng quãng đường', _formatDistance(s.totalDistanceM), Icons.route),
      ('Số điểm vị trí', '${s.pointCount}', Icons.location_on_outlined),
      ('Tốc độ TB', '${s.avgSpeedKmh.toStringAsFixed(1)} km/h', Icons.speed),
      ('Tốc độ tối đa', '${s.maxSpeedKmh.toStringAsFixed(1)} km/h', Icons.flash_on),
    ];

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((c) => _StatCard(label: c.$1, value: c.$2, icon: c.$3)).toList(),
    );
  }

  Widget _buildBarChart() {
    final maxY = _aggregated.map((s) => s.totalDistanceM / 1000).reduce((a, b) => a > b ? a : b);
    final safeMax = maxY < 0.1 ? 1.0 : maxY * 1.2;
    final showInterval = _aggregated.length > 12 ? 3 : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quãng đường theo thời gian',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: safeMax,
                barGroups: _aggregated.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.totalDistanceM / 1000,
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.8),
                      width: _aggregated.length > 20 ? 6 : 12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                )).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: showInterval.toDouble(),
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= _aggregated.length) return const SizedBox();
                        final label = _aggregated[i].label;
                        final short = label.length > 5 ? label.substring(label.length - 5) : label;
                        return Transform.rotate(
                          angle: -0.5,
                          child: Text(short, style: const TextStyle(color: Colors.white38, fontSize: 8)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, meta) => Text(
                        '${v.toStringAsFixed(1)}km',
                        style: const TextStyle(color: Colors.white38, fontSize: 8),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackMap() {
    final path = _stats!.trackPath;
    final points = path.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = points[points.length ~/ 2];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đường đi',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.child.tracking',
                  ),
                  PolylineLayer(polylines: [
                    Polyline(
                      points: points,
                      color: const Color(0xFF22D3EE),
                      strokeWidth: 5,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    _buildPathMarker(points.first, Colors.green, 'Bắt đầu'),
                    _buildPathMarker(points.last, Colors.red, 'Kết thúc'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildPathMarker(LatLng point, Color color, String label) {
    return Marker(
      point: point,
      width: 70,
      height: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Container(width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF22D3EE),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
