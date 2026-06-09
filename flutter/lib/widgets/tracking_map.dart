import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../utils/device_color.dart';

class TrackingMap extends StatefulWidget {
  final LatLng center;
  final Map<String, LocationData> locations;
  final List<String> trackingDeviceIds;
  final List<Geofence> geofences;
  final GeofencePendingConfig? pendingConfig;
  final bool isPlanMode;
  final Function(String deviceId)? onDeviceSelected;
  final String? focusedDeviceId;
  final Function(LatLng)? onMapTap;

  const TrackingMap({
    super.key,
    required this.center,
    required this.locations,
    required this.trackingDeviceIds,
    this.geofences = const [],
    this.pendingConfig,
    this.isPlanMode = false,
    this.onDeviceSelected,
    this.focusedDeviceId,
    this.onMapTap,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDeviceId != null &&
        widget.focusedDeviceId != oldWidget.focusedDeviceId) {
      final loc = widget.locations[widget.focusedDeviceId!];
      if (loc != null) _flyTo(LatLng(loc.lat, loc.lng));
    }
  }

  void _flyTo(LatLng target, {double zoom = 17}) {
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final latTween = Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final anim = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(anim), lngTween.evaluate(anim)),
        zoomTween.evaluate(anim),
      );
    });
    controller.addStatusListener((s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
    controller.forward();
  }

  // Calculates a capsule-shaped polygon around a multi-point path with given buffer radius.
  // Matches React's calculateCapsulePolygon() logic.
  List<LatLng> _calculateCapsulePolygon(List<LatLng> points, double radiusM) {
    if (points.length < 2) return [];
    const earthRadius = 6371000.0;
    final left = <LatLng>[];
    final right = <LatLng>[];

    void addOffset(LatLng p1, LatLng p2, {bool usePt2 = false}) {
      final dx = p2.longitude - p1.longitude;
      final dy = p2.latitude - p1.latitude;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) return;
      final perpX = -dy / len;
      final perpY = dx / len;
      final refLat = usePt2 ? p2.latitude : p1.latitude;
      final dLat = radiusM / earthRadius * (180 / pi);
      final dLng = radiusM / (earthRadius * cos(refLat * pi / 180)) * (180 / pi);
      final pt = usePt2 ? p2 : p1;
      left.add(LatLng(pt.latitude + perpX * dLat, pt.longitude + perpY * dLng));
      right.add(LatLng(pt.latitude - perpX * dLat, pt.longitude - perpY * dLng));
    }

    for (int i = 0; i < points.length - 1; i++) {
      addOffset(points[i], points[i + 1]);
    }
    // Close with last point offsets
    addOffset(points[points.length - 2], points[points.length - 1], usePt2: true);

    return [...left, ...right.reversed];
  }

  void _showMarkerPopup(String deviceId, LocationData loc) {
    final color = getDeviceColor(deviceId);
    final ts = DateTime.fromMillisecondsSinceEpoch(loc.timestamp * 1000);
    final timeStr = ts.toLocal().toString().substring(0, 16);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                deviceId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white12),
            _PopupRow(label: 'Vĩ độ', value: loc.lat.toStringAsFixed(6)),
            _PopupRow(label: 'Kinh độ', value: loc.lng.toStringAsFixed(6)),
            _PopupRow(label: 'Cập nhật', value: timeStr),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: Color(0xFF22D3EE))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Device markers ──────────────────────────────────────────────────────────
    final markers = widget.trackingDeviceIds
        .where((id) => widget.locations.containsKey(id))
        .map((deviceId) {
      final location = widget.locations[deviceId]!;
      final isFocused = widget.focusedDeviceId == deviceId;
      final color = getDeviceColor(deviceId);

      return Marker(
        point: LatLng(location.lat, location.lng),
        width: isFocused ? 50 : 35,
        height: isFocused ? 70 : 50,
        child: GestureDetector(
          onTap: () {
            widget.onDeviceSelected?.call(deviceId);
            _showMarkerPopup(deviceId, location);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isFocused ? 30 : 20,
                height: isFocused ? 30 : 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: isFocused ? 20 : 14,
                    height: isFocused ? 20 : 14,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: isFocused ? 12 : 8,
                        height: isFocused ? 12 : 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isFocused)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deviceId,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B0F1A),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    // ── Plan mode: path point markers ─────────────────────────────────────────
    if (widget.isPlanMode &&
        widget.pendingConfig != null &&
        widget.pendingConfig!.mode == 'mobile') {
      for (var i = 0; i < widget.pendingConfig!.path.length; i++) {
        markers.add(Marker(
          point: widget.pendingConfig!.path[i],
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ));
      }
    }

    // ── Center marker (orange) ────────────────────────────────────────────────
    final centerMarkers = <CircleMarker>[
      CircleMarker(
        point: widget.center,
        radius: 10,
        color: const Color(0xFFF97316).withValues(alpha: 0.9),
        borderColor: const Color(0xFFfb923c),
        borderStrokeWidth: 2,
        useRadiusInMeter: false,
      ),
    ];

    // ── Confirmed circle geofences ────────────────────────────────────────────
    final circleMarkers = geofences_to_circles(widget.geofences);

    // ── Preview pending circle in plan mode ────────────────────────────────────
    if (widget.isPlanMode &&
        widget.pendingConfig != null &&
        widget.pendingConfig!.mode == 'fixed' &&
        widget.pendingConfig!.centerLat != null &&
        widget.pendingConfig!.centerLng != null) {
      circleMarkers.add(CircleMarker(
        point: LatLng(widget.pendingConfig!.centerLat!, widget.pendingConfig!.centerLng!),
        radius: widget.pendingConfig!.radius,
        useRadiusInMeter: true,
        color: const Color(0xFFF97316).withValues(alpha: 0.1),
        borderColor: const Color(0xFFF97316).withValues(alpha: 0.6),
        borderStrokeWidth: 2,
      ));
    }

    // ── Capsule polygons for confirmed path geofences ─────────────────────────
    final polygons = <Polygon>[];
    final polylines = <Polyline>[];

    for (final g in widget.geofences) {
      if (g.mode == 'mobile' && g.path.length > 1) {
        final capsule = _calculateCapsulePolygon(g.path, g.radiusM);
        if (capsule.isNotEmpty) {
          polygons.add(Polygon(
            points: capsule,
            color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
            borderColor: const Color(0xFF22D3EE),
            borderStrokeWidth: 2,
          ));
        }
        // Path centerline for reference
        polylines.add(Polyline(
          points: g.path,
          color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
          strokeWidth: 1.5,
          isDotted: true,
        ));
      }
    }

    // ── Preview pending path geofence in plan mode ────────────────────────────
    if (widget.isPlanMode &&
        widget.pendingConfig != null &&
        widget.pendingConfig!.mode == 'mobile' &&
        widget.pendingConfig!.path.length > 1) {
      final capsule = _calculateCapsulePolygon(
          widget.pendingConfig!.path, widget.pendingConfig!.radius);
      if (capsule.isNotEmpty) {
        polygons.add(Polygon(
          points: capsule,
          color: const Color(0xFFF97316).withValues(alpha: 0.12),
          borderColor: const Color(0xFFF97316).withValues(alpha: 0.6),
          borderStrokeWidth: 2,
        ));
      }
      polylines.add(Polyline(
        points: widget.pendingConfig!.path,
        color: const Color(0xFFF97316).withValues(alpha: 0.6),
        strokeWidth: 2,
        isDotted: true,
      ));
    }

    // ── Device-to-device connecting polyline ───────────────────────────────────
    final trackedWithLocation = widget.trackingDeviceIds
        .where((id) => widget.locations.containsKey(id))
        .toList();
    if (trackedWithLocation.length >= 2) {
      final devicePoints = trackedWithLocation
          .map((id) => LatLng(widget.locations[id]!.lat, widget.locations[id]!.lng))
          .toList();
      polylines.add(Polyline(
        points: devicePoints,
        color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
        strokeWidth: 1.5,
        isDotted: true,
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 16,
        onTap: widget.onMapTap != null
            ? (tapEvent, point) {
                debugPrint('[MapTap] ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
                widget.onMapTap!(point);
              }
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.child.tracking',
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (circleMarkers.isNotEmpty) CircleLayer(circles: circleMarkers),
        CircleLayer(circles: centerMarkers),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

List<CircleMarker> geofences_to_circles(List<Geofence> geofences) {
  return geofences
      .where((g) => g.mode == 'fixed' && g.centerLat != null && g.centerLng != null)
      .map((g) => CircleMarker(
            point: LatLng(g.centerLat!, g.centerLng!),
            radius: g.radiusM,
            useRadiusInMeter: true,
            color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
            borderColor: const Color(0xFF22D3EE),
            borderStrokeWidth: 2,
          ))
      .toList();
}

class _PopupRow extends StatelessWidget {
  final String label;
  final String value;
  const _PopupRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
