import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_provider.dart';
import '../widgets/top_nav.dart';
import '../widgets/tracking_map.dart';
import '../services/socket_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showDeviceList = false;
  bool _showAlerts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.fetchGeofenceState();
      _startSocketConnection();
    });
  }

  void _startSocketConnection() {
    final provider = context.read<AppProvider>();
    // Socket connection handled by provider
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.devices.isEmpty) {
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
                  onNavigateProfile: () => Navigator.of(context).pushNamed('/profile'),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có thiết bị',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hãy thêm thiết bị trong trang Hồ sơ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F1A), Color(0xFF0F172A), Color(0xFF111827)],
          ),
        ),
        child: Stack(
          children: [
            // Map
            Positioned.fill(
              top: 72,
              child: TrackingMap(
                center: LatLng(
                  provider.geofenceState.mode == 'fixed'
                      ? provider.geofenceState.centerLat
                      : provider.geofenceState.centerLat,
                  provider.geofenceState.centerLng,
                ),
                locations: provider.locations,
                trackingDeviceIds: provider.devices.map((d) => d.deviceId).toList(),
                geofenceRadiusM: provider.geofenceState.radiusM,
                focusedDeviceId: null,
              ),
            ),

            // Top-left: WS Status
            Positioned(
              top: 86,
              left: 16,
              child: _FloatingPanel(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(provider.socketStatus).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: _getStatusColor(provider.socketStatus).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(provider.socketStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'WS: ${provider.socketStatus.name}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(provider.socketStatus),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top-right: Device List Button
            Positioned(
              top: 86,
              right: 16,
              child: _FloatingPanel(
                child: GestureDetector(
                  onTap: () => setState(() => _showDeviceList = !_showDeviceList),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.devices.length} thiết bị',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Device List Panel
            if (_showDeviceList)
              Positioned(
                top: 140,
                right: 16,
                child: _FloatingPanel(
                  width: 280,
                  maxHeight: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Thiết bị đang theo dõi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => setState(() => _showDeviceList = false),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      Expanded(
                        child: ListView.builder(
                          itemCount: provider.devices.length,
                          itemBuilder: (context, index) {
                            final device = provider.devices[index];
                            final location = provider.locations[device.deviceId];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _getDeviceColor(device.deviceId),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(
                                device.deviceId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: location != null
                                  ? Text(
                                      '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
                                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                    )
                                  : null,
                              trailing: Text(
                                'ON',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.6),
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Left: Geofence Status
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 100,
              child: _FloatingPanel(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vùng an toàn',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bán kính: ${provider.geofenceState.radiusM} m',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chế độ: ${provider.geofenceState.mode}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // Right: Control Buttons
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 80,
              child: _FloatingPanel(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điều khiển',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => provider.setGeofenceMode('fixed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22D3EE),
                          foregroundColor: const Color(0xFF0B0F1A),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cố định', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => provider.setGeofenceMode('mobile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Dùng điện thoại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (provider.shareEnabled ? Colors.green : Colors.orange).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        'Chia sẻ: ${provider.shareEnabled ? "Bật" : "Tắt"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: provider.shareEnabled ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Alerts Button
            Positioned(
              top: 86,
              right: 200,
              child: _FloatingPanel(
                child: GestureDetector(
                  onTap: () => setState(() => _showAlerts = !_showAlerts),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: const Stack(
                      children: [
                        Text('⚠️', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Alerts Drawer
            if (_showAlerts)
              Positioned(
                top: 140,
                right: 16,
                child: _FloatingPanel(
                  width: 280,
                  maxHeight: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cảnh báo gần đây',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => setState(() => _showAlerts = false),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      if (provider.alerts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Chưa có cảnh báo',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.alerts.length,
                            itemBuilder: (context, index) {
                              final alert = provider.alerts[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  alert.event,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                                subtitle: Text(
                                  '${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}\n${DateTime.fromMillisecondsSinceEpoch(alert.timestamp * 1000).toString()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SocketStatus status) {
    switch (status) {
      case SocketStatus.connected:
        return Colors.green;
      case SocketStatus.connecting:
        return Colors.orange;
      case SocketStatus.disconnected:
      case SocketStatus.error:
        return Colors.red;
    }
  }

  Color _getDeviceColor(String deviceId) {
    final colors = [
      const Color(0xFF22D3EE),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFF472B6),
      const Color(0xFFFB923C),
      const Color(0xFF60A5FA),
    ];
    final index = deviceId.length % colors.length;
    return colors[index];
  }
}

class _FloatingPanel extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? maxHeight;

  const _FloatingPanel({
    required this.child,
    this.width,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: width ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}