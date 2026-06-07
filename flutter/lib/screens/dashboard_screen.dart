import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_provider.dart';
import '../widgets/top_nav.dart';
import '../widgets/tracking_map.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../utils/device_color.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AppProvider _provider;
  late final LocationService _locationService;
  final _radiusController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _locationService = _provider.locationService;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchGeofenceState();
      _provider.connectSocket();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGeofenceControllers();
  }

  void _syncGeofenceControllers() {
    final state = _provider.geofenceState;
    final radiusVal = double.tryParse(_radiusController.text);
    if (radiusVal == null || (radiusVal - state.radiusM).abs() > 0.001) {
      _radiusController.text = state.radiusM.toStringAsFixed(0);
    }
    if (_latController.text != state.centerLat.toStringAsFixed(4)) {
      _latController.text = state.centerLat.toStringAsFixed(4);
    }
    if (_lngController.text != state.centerLng.toStringAsFixed(4)) {
      _lngController.text = state.centerLng.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _radiusController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _applyRadius() {
    final val = double.tryParse(_radiusController.text);
    if (val != null && val > 0 && mounted) {
      _provider.updateGeofenceRadius(val);
    }
  }

  void _applyCenter() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null && mounted) {
      _provider.updateGeofenceCenter(lat, lng);
    }
  }

  void _onMapTap(LatLng point) {
    if (_provider.geofenceState.mode != 'fixed' || !_provider.isOwner) {
      debugPrint('[MapTap] blocked: mode=${_provider.geofenceState.mode}, isOwner=${_provider.isOwner}');
      return;
    }
    debugPrint('[MapTap] tapped: lat=${point.latitude}, lng=${point.longitude}');
    _latController.text = point.latitude.toStringAsFixed(6);
    _lngController.text = point.longitude.toStringAsFixed(6);
    _provider.updateGeofenceCenter(point.latitude, point.longitude).then((_) {
      debugPrint('[MapTap] updateGeofenceCenter success');
    }).catchError((e) {
      debugPrint('[MapTap] updateGeofenceCenter ERROR: $e');
    });
  }

  LatLng _getMapCenter() {
    final provider = _provider;
    if (provider.geofenceState.mode == 'mobile' && _locationService.currentPosition != null) {
      final pos = _locationService.currentPosition!;
      return LatLng(pos.latitude, pos.longitude);
    }
    return LatLng(provider.geofenceState.centerLat, provider.geofenceState.centerLng);
  }

  void _showDeviceListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final devices = _provider.devices;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thiết bị đang theo dõi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              if (devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có thiết bị', style: TextStyle(color: Colors.white54)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final location = _provider.locations[device.deviceId];
                      final colors = getDeviceColor(device.deviceId);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colors, shape: BoxShape.circle),
                        ),
                        title: Text(
                          device.deviceId,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: location != null
                            ? Text(
                                '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            'ON',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white60),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAlertsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final alerts = _provider.alerts;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cảnh báo gần đây',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              if (alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Chưa có cảnh báo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                        ),
                        title: Text(
                          alert.event,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orangeAccent),
                        ),
                        subtitle: Text(
                          '${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}\n'
                              '${DateTime.fromMillisecondsSinceEpoch(alert.timestamp * 1000).toLocal()}',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isFixed = provider.geofenceState.mode == 'fixed';
    final isOwner = provider.isOwner;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Hãy thêm thiết bị trong trang Hồ sơ',
                          style: TextStyle(fontSize: 14, color: Colors.white54),
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
            Expanded(
              child: Stack(
                children: [
                  TrackingMap(
                    center: _getMapCenter(),
                    locations: provider.locations,
                    trackingDeviceIds: provider.devices.map((d) => d.deviceId).toList(),
                    geofenceRadiusM: provider.geofenceState.radiusM,
                    geofenceCenter: LatLng(provider.geofenceState.centerLat, provider.geofenceState.centerLng),
                    focusedDeviceId: null,
                    onMapTap: (isFixed && isOwner) ? _onMapTap : null,
                  ),
                  Positioned(
                    top: 8,
                    left: 16,
                    child: _StatusPill(
                      status: provider.socketStatus,
                      getColor: _getStatusColor,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 16,
                    child: Row(
                      children: [
                        _IconPill(
                          icon: Icons.people_outline,
                          label: '${provider.devices.length} thiết bị',
                          onTap: _showDeviceListSheet,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 8),
                        _IconPill(
                          icon: Icons.warning_amber_rounded,
                          label: null,
                          onTap: _showAlertsSheet,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ControlDock(
              provider: provider,
              bottomPadding: bottomPadding,
              isFixed: isFixed,
              isOwner: isOwner,
              radiusController: _radiusController,
              latController: _latController,
              lngController: _lngController,
              onApplyRadius: _applyRadius,
              onApplyCenter: _applyCenter,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SocketStatus status;
  final Color Function(SocketStatus) getColor;

  const _StatusPill({required this.status, required this.getColor});

  @override
  Widget build(BuildContext context) {
    final color = getColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            'WS: ${status.name}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color color;

  const _IconPill({
    required this.icon,
    this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon, size: 16, color: color),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label!,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ],
    );
    final isCircle = label == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCircle ? 12 : 14,
          vertical: isCircle ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.85),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: child,
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  final AppProvider provider;
  final double bottomPadding;
  final bool isFixed;
  final bool isOwner;
  final TextEditingController radiusController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final VoidCallback onApplyRadius;
  final VoidCallback onApplyCenter;

  const _ControlDock({
    required this.provider,
    required this.bottomPadding,
    required this.isFixed,
    required this.isOwner,
    required this.radiusController,
    required this.latController,
    required this.lngController,
    required this.onApplyRadius,
    required this.onApplyCenter,
  });

  @override
  Widget build(BuildContext context) {
    final state = provider.geofenceState;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFixed && isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: radiusController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Bán kính (m)',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, size: 16, color: Colors.cyanAccent),
                        onPressed: onApplyRadius,
                        tooltip: 'Áp dụng',
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onSubmitted: (_) => onApplyRadius(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tâm vùng', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Lat',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Lng',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              onSubmitted: (_) => onApplyCenter(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, size: 16, color: Colors.cyanAccent),
                            onPressed: onApplyCenter,
                            tooltip: 'Áp dụng tọa độ',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else if (isFixed && !isOwner) ...[
            Row(
              children: [
                Icon(Icons.lock_outline, size: 12, color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 6),
                Text(
                  'Bán kính: ${state.radiusM}m | Tâm: ${state.centerLat.toStringAsFixed(4)}, ${state.centerLng.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Cố định',
                  active: provider.geofenceState.mode == 'fixed',
                  onTap: () => provider.setGeofenceMode('fixed'),
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Dùng điện thoại',
                  active: provider.geofenceState.mode == 'mobile',
                  onTap: () => provider.setGeofenceMode('mobile'),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.circle, size: 6, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                '${provider.geofenceState.radiusM}m · ${provider.geofenceState.mode}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (provider.shareEnabled ? Colors.green : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Chia sẻ: ${provider.shareEnabled ? "Bật" : "Tắt"}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: provider.shareEnabled ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.white.withOpacity(0.12),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? const Color(0xFF0B0F1A) : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
