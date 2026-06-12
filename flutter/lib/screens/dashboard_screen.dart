import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/top_nav.dart';
import '../widgets/tracking_map.dart';
import '../widgets/geofence_editor_panel.dart';
import '../widgets/notification_toast.dart';
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
  Timer? _syncTimer;
  Timer? _bannerTimer;
  Alert? _bannerAlert;
  bool _showDeviceList = true;
  bool _showAlerts = false;
  String? _focusedDeviceId;
  int _unreadCount = 0;
  List<ToastItem> _toastAlerts = [];

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _locationService = _provider.locationService;
    _provider.addListener(_onProviderChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.fetchGeofenceState();
      _provider.connectSocket();
      _provider.fetchInitialLocations();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _provider.removeListener(_onProviderChange);
    _syncTimer?.cancel();
    super.dispose();
  }

  void _onProviderChange() {
    final alert = _provider.lastNewAlert;
    if (alert != null) {
      _provider.clearLastNewAlert();
      _showAlertBanner(alert);
      setState(() {
        _toastAlerts = [
          ToastItem(id: '${DateTime.now().millisecondsSinceEpoch}_${alert.deviceId}', alert: alert),
          ..._toastAlerts.take(4),
        ];
        if (!_showAlerts) _unreadCount++;
      });
    }
  }

  void _showAlertBanner(Alert alert) {
    setState(() => _bannerAlert = alert);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _bannerAlert = null);
    });
  }

  void _toggleAlerts() {
    setState(() {
      _showAlerts = !_showAlerts;
      if (_showAlerts) _unreadCount = 0;
    });
  }

  void _dismissToast(String id) {
    setState(() => _toastAlerts.removeWhere((t) => t.id == id));
  }

  void _onMapTap(LatLng point) {
    if (_provider.isPlanMode) {
      _provider.handleMapTap(point);
      return;
    }
    if (_provider.geofenceState.mode == 'fixed' && _provider.isOwner) {
      _provider.updateGeofenceCenter(point.latitude, point.longitude);
    }
  }

  LatLng _getMapCenter() {
    if (_provider.geofenceState.mode == 'mobile' && _locationService.currentPosition != null) {
      final pos = _locationService.currentPosition!;
      return LatLng(pos.latitude, pos.longitude);
    }
    return LatLng(_provider.geofenceState.centerLat, _provider.geofenceState.centerLng);
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final navBar = TopNav(
      token: provider.token,
      userEmail: provider.currentUser?.email,
      onLogout: () {
        provider.logout();
        Navigator.of(context).pushReplacementNamed('/auth');
      },
      onNavigateProfile: () => Navigator.of(context).pushNamed('/profile'),
      onNavigateStats: provider.devices.isNotEmpty
          ? () => Navigator.of(context).pushNamed('/statistics', arguments: provider.selectedDeviceId)
          : null,
    );

    return Scaffold(
      body: Container(
        decoration: _bgDecoration,
        child: Column(
          children: [
            navBar,
            Expanded(
              child: Stack(
                children: [
                  // Map
                  TrackingMap(
                    center: _getMapCenter(),
                    locations: provider.locations,
                    trackingDeviceIds: provider.trackingDeviceIds.toList(),
                    geofences: provider.geofenceState.geofences,
                    pendingConfig: provider.isPlanMode ? provider.pendingConfig : null,
                    isPlanMode: provider.isPlanMode,
                    focusedDeviceId: _focusedDeviceId,
                    onDeviceSelected: (id) => setState(() => _focusedDeviceId = id),
                    onMapTap: _onMapTap,
                  ),

                  // Status pill (top left)
                  Positioned(
                    top: 8,
                    left: 12,
                    child: _StatusPill(
                      status: provider.socketStatus,
                      getColor: _getStatusColor,
                    ),
                  ),

                  // Icon buttons (top right)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Row(
                      children: [
                        _IconPill(
                          icon: Icons.people_outline,
                          label: '${provider.devices.length}',
                          active: _showDeviceList,
                          onTap: () => setState(() => _showDeviceList = !_showDeviceList),
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        _IconPill(
                          icon: Icons.warning_amber_rounded,
                          label: _unreadCount > 0 ? '$_unreadCount' : (provider.alerts.isNotEmpty ? '${provider.alerts.length}' : null),
                          active: _showAlerts,
                          onTap: _toggleAlerts,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 6),
                        _IconPill(
                          icon: provider.shareEnabled ? Icons.share_location : Icons.location_off_outlined,
                          label: null,
                          active: provider.shareEnabled,
                          onTap: () => provider.setGeofenceMode(
                              provider.shareEnabled ? 'fixed' : 'mobile'),
                          color: Colors.greenAccent,
                        ),
                      ],
                    ),
                  ),

                  // Device list panel (toggle)
                  if (_showDeviceList)
                    Positioned(
                      top: 44,
                      right: 12,
                      child: _DeviceListPanel(
                        devices: provider.devices,
                        trackingIds: provider.trackingDeviceIds,
                        locations: provider.locations,
                        focusedDeviceId: _focusedDeviceId,
                        onToggle: provider.toggleTracking,
                        onFocus: (id) => setState(() => _focusedDeviceId = id),
                        onClose: () => setState(() => _showDeviceList = false),
                      ),
                    ),

                  // Alerts panel (toggle)
                  if (_showAlerts)
                    Positioned(
                      top: 44,
                      right: 12,
                      child: _AlertsPanel(
                        alerts: provider.alerts,
                        onClose: _toggleAlerts,
                        onClear: provider.clearAlerts,
                      ),
                    ),

                  // Alert banner (auto-dismiss after 5s)
                  if (_bannerAlert != null)
                    Positioned(
                      top: 8,
                      left: 80,
                      right: 80,
                      child: _AlertBanner(
                        alert: _bannerAlert!,
                        onDismiss: () {
                          _bannerTimer?.cancel();
                          setState(() => _bannerAlert = null);
                        },
                        onTap: () {
                          _bannerTimer?.cancel();
                          setState(() { _showAlerts = true; _bannerAlert = null; });
                        },
                      ),
                    ),

                  // Geofence editor panel (bottom left, always visible)
                  const Positioned(
                    left: 8,
                    bottom: 80,
                    child: GeofenceEditorPanel(),
                  ),

                  // Toast overlay notifications (bottom right)
                  if (_toastAlerts.isNotEmpty)
                    NotificationToast(
                      toasts: _toastAlerts,
                      onDismiss: _dismissToast,
                    ),
                ],
              ),
            ),

            // Mode toggle dock (simplified)
            _ModeDock(
              provider: provider,
              bottomPadding: bottomPadding,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background decoration ───────────────────────────────────────────────────

const _bgDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0F1A), Color(0xFF0F172A), Color(0xFF111827)],
  ),
);

// ─── Status Pill ──────────────────────────────────────────────────────────────

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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('WS: ${status.name}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ─── Icon Pill ────────────────────────────────────────────────────────────────

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _IconPill({
    required this.icon,
    this.label,
    required this.active,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? color : Colors.white54),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!, style: TextStyle(fontSize: 11, color: active ? color : Colors.white54, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Device List Panel ────────────────────────────────────────────────────────

class _DeviceListPanel extends StatelessWidget {
  final List devices;
  final Set<String> trackingIds;
  final Map locations;
  final String? focusedDeviceId;
  final void Function(String) onToggle;
  final void Function(String) onFocus;
  final VoidCallback onClose;

  const _DeviceListPanel({
    required this.devices,
    required this.trackingIds,
    required this.locations,
    required this.onToggle,
    required this.onFocus,
    required this.onClose,
    this.focusedDeviceId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1729).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                const Text('Thiết bị theo dõi',
                    style: TextStyle(color: Color(0xFF22D3EE), fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.white38, size: 16)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final device = devices[i];
                final id = device.deviceId as String;
                final isTracking = trackingIds.contains(id);
                final isFocused = focusedDeviceId == id;
                final color = getDeviceColor(id);
                return GestureDetector(
                  onTap: () => onFocus(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFocused ? const Color(0xFF22D3EE).withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: isFocused ? const Color(0xFF22D3EE) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(id,
                              style: TextStyle(
                                color: isFocused ? const Color(0xFF22D3EE) : Colors.white,
                                fontSize: 12,
                                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Switch(
                          value: isTracking,
                          onChanged: (_) => onToggle(id),
                          activeColor: const Color(0xFF22D3EE),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alerts Panel ─────────────────────────────────────────────────────────────

class _AlertsPanel extends StatelessWidget {
  final List alerts;
  final VoidCallback onClose;
  final VoidCallback onClear;

  const _AlertsPanel({required this.alerts, required this.onClose, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1729).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 6),
                const Text('Cảnh báo',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (alerts.isNotEmpty)
                  GestureDetector(
                    onTap: onClear,
                    child: const Text('Xóa', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                const SizedBox(width: 8),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.white38, size: 16)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có cảnh báo', style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: alerts.length,
                itemBuilder: (context, i) {
                  final alert = alerts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: _eventColor(alert.event), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alert.deviceId,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                              Text(_eventLabel(alert.event),
                                  style: TextStyle(color: _eventColor(alert.event), fontSize: 11, fontWeight: FontWeight.w600)),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(alert.timestamp * 1000).toLocal().toString().substring(0, 16),
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Alert helpers ───────────────────────────────────────────────────────────

String _eventLabel(String event) => switch (event) {
  'outside_entered'  => '⚠️ Rời vùng an toàn',
  'outside_reminder' => '⏰ Vẫn ngoài vùng an toàn',
  'inside_entered'   => '✅ Đã vào vùng an toàn',
  'inside_moved'     => '📍 Chuyển vùng an toàn',
  _                  => event,
};

Color _eventColor(String event) => event.startsWith('outside')
    ? Colors.orangeAccent
    : Colors.greenAccent;

String _eventBannerText(Alert alert) => switch (alert.event) {
  'outside_entered'  => '⚠️ ${alert.deviceId} rời vùng an toàn!',
  'outside_reminder' => '⏰ ${alert.deviceId} vẫn ngoài vùng an toàn',
  'inside_entered'   => '✅ ${alert.deviceId} đã vào vùng an toàn',
  'inside_moved'     => '📍 ${alert.deviceId} chuyển sang vùng an toàn mới',
  _                  => alert.event,
};

// ─── Alert Banner ─────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final Alert alert;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _AlertBanner({required this.alert, required this.onDismiss, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(alert.event);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _eventBannerText(alert),
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: Colors.white38, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mode Dock ────────────────────────────────────────────────────────────────

class _ModeDock extends StatelessWidget {
  final AppProvider provider;
  final double bottomPadding;

  const _ModeDock({required this.provider, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    final isFixed = provider.geofenceState.mode == 'fixed';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPadding + 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Cố định',
                  active: isFixed,
                  onTap: () => provider.setGeofenceMode('fixed'),
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'Dùng điện thoại',
                  active: !isFixed,
                  onTap: () => provider.setGeofenceMode('mobile'),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.circle, size: 6, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                '${provider.geofenceState.radiusM.toStringAsFixed(0)}m · ${provider.geofenceState.mode} · ${provider.geofenceState.geofences.length} vùng',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (provider.shareEnabled ? Colors.green : Colors.orange).withValues(alpha: 0.15),
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

  const _ModeButton({required this.label, required this.active, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.12),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? const Color(0xFF0B0F1A) : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
