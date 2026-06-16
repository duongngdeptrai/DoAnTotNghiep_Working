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
  final Function(Geofence)? onGeofenceTapped;
  final String? focusedGeofenceId;
  final bool isMobileMode;

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
    this.onGeofenceTapped,
    this.focusedGeofenceId,
    this.isMobileMode = false,
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
    if (widget.focusedGeofenceId != null &&
        widget.focusedGeofenceId != oldWidget.focusedGeofenceId) {
      final g = widget.geofences.where((g) => g.id == widget.focusedGeofenceId).firstOrNull;
      if (g != null) _flyToGeofence(g);
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

  void _flyToGeofence(Geofence g) {
    if (g.mode == 'fixed' && g.centerLat != null && g.centerLng != null) {
      _flyTo(LatLng(g.centerLat!, g.centerLng!), zoom: _zoomForRadius(g.radiusM));
    } else if (g.mode == 'mobile' && g.path.isNotEmpty) {
      _flyTo(g.path[g.path.length ~/ 2], zoom: _zoomForPath(g.path));
    }
  }

  double _zoomForRadius(double radiusM) {
    if (radiusM < 50) return 18;
    if (radiusM < 150) return 17;
    if (radiusM < 500) return 15;
    if (radiusM < 2000) return 14;
    return 13;
  }

  double _zoomForPath(List<LatLng> pts) {
    final minLat = pts.map((p) => p.latitude).reduce(min);
    final maxLat = pts.map((p) => p.latitude).reduce(max);
    final minLng = pts.map((p) => p.longitude).reduce(min);
    final maxLng = pts.map((p) => p.longitude).reduce(max);
    final span = max(maxLat - minLat, maxLng - minLng);
    if (span < 0.001) return 17;
    if (span < 0.005) return 15;
    if (span < 0.02) return 13;
    return 12;
  }

  void _showGeofencePopup(Geofence g) {
    final center = g.mode == 'fixed' && g.centerLat != null
        ? '${g.centerLat!.toStringAsFixed(5)}, ${g.centerLng!.toStringAsFixed(5)}'
        : '${g.path.length} điểm';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF22D3EE), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                g.name.isNotEmpty ? g.name : g.id,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white12),
            _PopupRow(label: 'Loại', value: g.mode == 'fixed' ? 'Vùng cố định' : 'Đường di chuyển'),
            _PopupRow(label: 'Bán kính', value: '${g.radiusM.toStringAsFixed(0)} m'),
            _PopupRow(label: 'Vị trí', value: center),
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

  // Builds a capsule polygon around a multi-point path.
  // All geometry is computed in a local flat metric space (metres, x=east, y=north)
  // using cos(lat) to correctly scale longitude degrees, then converted back to LatLng.
  // This matches the backend's haversine-based _distance_to_segment check exactly.
  List<LatLng> _calculateCapsulePolygon(List<LatLng> points, double radiusM) {
    if (points.length < 2) return [];

    const metersPerDegLat = 111320.0;
    final double cosLat = cos(points[0].latitude * pi / 180.0);
    final double metersPerDegLng = metersPerDegLat * cosLat;
    final LatLng orig = points[0];

    // Convert LatLng → local metric (x=east metres, y=north metres) relative to orig.
    double toX(LatLng p) => (p.longitude - orig.longitude) * metersPerDegLng;
    double toY(LatLng p) => (p.latitude - orig.latitude) * metersPerDegLat;

    // Convert local metric back to LatLng.
    LatLng fromXY(double x, double y) => LatLng(
          orig.latitude + y / metersPerDegLat,
          orig.longitude + x / metersPerDegLng,
        );

    final n = points.length;
    const capSegs = 8;
    final R = radiusM; // radius in metres

    // CCW unit perpendicular of segment i→i+1 in metric space [px, py].
    List<double> segPerp(int i) {
      final dx = toX(points[i + 1]) - toX(points[i]);
      final dy = toY(points[i + 1]) - toY(points[i]);
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) return [0.0, 0.0];
      // CCW 90° rotation of (dx, dy) → (-dy, dx)
      return [-dy / len, dx / len]; // [px=east, py=north]
    }

    final sPerps = [for (var i = 0; i < n - 1; i++) segPerp(i)];

    // Smooth normal at vertex i via miter join.
    List<double> normalAt(int i) {
      if (i == 0) return sPerps[0];
      if (i == n - 1) return sPerps[n - 2];
      final a = sPerps[i - 1];
      final b = sPerps[i];
      final mx = a[0] + b[0];
      final my = a[1] + b[1];
      final mlen = sqrt(mx * mx + my * my);
      if (mlen < 0.001) return sPerps[i - 1];
      return [mx / mlen, my / mlen];
    }

    // Point on a circle of radius R at angle from the x-axis (standard math convention).
    LatLng arcPt(double cx, double cy, double angle) =>
        fromXY(cx + cos(angle) * R, cy + sin(angle) * R);

    final polygon = <LatLng>[];

    // Start cap: arc from right[0] → backward → left[0]
    final sn = normalAt(0);
    final x0 = toX(points[0]);
    final y0 = toY(points[0]);
    final startAngle = atan2(sn[1], sn[0]); // angle of left-side normal
    for (var j = 0; j <= capSegs; j++) {
      polygon.add(arcPt(x0, y0, (startAngle + pi) - j * pi / capSegs));
    }

    // Left side: vertices 1 .. n-1
    for (var i = 1; i < n; i++) {
      final nm = normalAt(i);
      final xi = toX(points[i]);
      final yi = toY(points[i]);
      polygon.add(fromXY(xi + nm[0] * R, yi + nm[1] * R));
    }

    // End cap: arc from left[n-1] → forward → right[n-1]
    final en = normalAt(n - 1);
    final xn = toX(points[n - 1]);
    final yn = toY(points[n - 1]);
    final endAngle = atan2(en[1], en[0]);
    for (var j = 0; j <= capSegs; j++) {
      polygon.add(arcPt(xn, yn, endAngle - j * pi / capSegs));
    }

    // Right side: vertices n-2 .. 1
    for (var i = n - 2; i >= 1; i--) {
      final nm = normalAt(i);
      final xi = toX(points[i]);
      final yi = toY(points[i]);
      polygon.add(fromXY(xi - nm[0] * R, yi - nm[1] * R));
    }

    return polygon;
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

    // ── Geofence tap markers ──────────────────────────────────────────────────
    if (!widget.isMobileMode) for (final g in widget.geofences) {
      LatLng? tapCenter;
      if (g.mode == 'fixed' && g.centerLat != null && g.centerLng != null) {
        tapCenter = LatLng(g.centerLat!, g.centerLng!);
      } else if (g.mode == 'mobile' && g.path.isNotEmpty) {
        tapCenter = g.path[g.path.length ~/ 2];
      }
      if (tapCenter == null) continue;

      final isFocused = widget.focusedGeofenceId == g.id;
      markers.add(Marker(
        point: tapCenter,
        width: isFocused ? 40 : 30,
        height: isFocused ? 40 : 30,
        child: GestureDetector(
          onTap: () {
            widget.onGeofenceTapped?.call(g);
            _showGeofencePopup(g);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withValues(alpha: isFocused ? 0.25 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: isFocused ? 0.9 : 0.45),
                width: isFocused ? 2 : 1.5,
              ),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: const Color(0xFF22D3EE).withValues(alpha: isFocused ? 1.0 : 0.65),
              size: isFocused ? 20 : 15,
            ),
          ),
        ),
      ));
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
    final circleMarkers = widget.isMobileMode
        ? <CircleMarker>[]
        : geofences_to_circles(widget.geofences);
    if (widget.isMobileMode) {
      circleMarkers.add(CircleMarker(
        point: widget.center,
        radius: 50.0,
        useRadiusInMeter: true,
        color: const Color(0xFFF97316).withValues(alpha: 0.15),
        borderColor: const Color(0xFFF97316),
        borderStrokeWidth: 2.5,
      ));
    }

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

    if (!widget.isMobileMode) for (final g in widget.geofences) {
      if (g.mode == 'mobile' && g.path.length > 1) {
        final capsule = _calculateCapsulePolygon(g.path, g.radiusM);
        if (capsule.isNotEmpty) {
          polygons.add(Polygon(
            points: capsule,
            isFilled: true,
            color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
            borderColor: const Color(0xFF22D3EE),
            borderStrokeWidth: 2,
          ));
        }
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
          isFilled: true,
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
        PolylineLayer(polylines: polylines),
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
