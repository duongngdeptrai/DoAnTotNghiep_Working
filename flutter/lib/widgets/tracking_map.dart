import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../utils/device_color.dart';

class TrackingMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final markers = trackingDeviceIds
        .where((id) => locations.containsKey(id))
        .map((deviceId) {
      final location = locations[deviceId]!;
      final isFocused = focusedDeviceId == deviceId;
      final color = getDeviceColor(deviceId);

      return Marker(
        point: LatLng(location.lat, location.lng),
        width: isFocused ? 50 : 35,
        height: isFocused ? 70 : 50,
        child: GestureDetector(
          onTap: () => onDeviceSelected?.call(deviceId),
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
                child: Container(
                  width: isFocused ? 20 : 14,
                  height: isFocused ? 20 : 14,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
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

    // Plan mode path point markers
    if (isPlanMode && pendingConfig != null && pendingConfig!.mode == 'mobile') {
      for (var i = 0; i < pendingConfig!.path.length; i++) {
        markers.add(Marker(
          point: pendingConfig!.path[i],
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ));
      }
    }

    // Confirmed circle geofences
    final circleMarkers = geofences
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

    // Preview pending circle in plan mode
    if (isPlanMode && pendingConfig != null && pendingConfig!.mode == 'fixed' &&
        pendingConfig!.centerLat != null && pendingConfig!.centerLng != null) {
      circleMarkers.add(CircleMarker(
        point: LatLng(pendingConfig!.centerLat!, pendingConfig!.centerLng!),
        radius: pendingConfig!.radius,
        useRadiusInMeter: true,
        color: const Color(0xFF22D3EE).withValues(alpha: 0.08),
        borderColor: const Color(0xFF22D3EE).withValues(alpha: 0.6),
        borderStrokeWidth: 2,
      ));
    }

    // Confirmed path geofences
    final confirmedPolylines = geofences
        .where((g) => g.mode == 'mobile' && g.path.length > 1)
        .map((g) => Polyline(
              points: g.path,
              color: const Color(0xFFA78BFA).withValues(alpha: 0.8),
              strokeWidth: (g.radiusM / 10).clamp(3.0, 20.0),
              borderColor: const Color(0xFFA78BFA),
              borderStrokeWidth: 1,
            ))
        .toList();

    // Preview pending path in plan mode
    if (isPlanMode && pendingConfig != null && pendingConfig!.mode == 'mobile' &&
        pendingConfig!.path.length > 1) {
      confirmedPolylines.add(Polyline(
        points: pendingConfig!.path,
        color: const Color(0xFFA78BFA).withValues(alpha: 0.5),
        strokeWidth: (pendingConfig!.radius / 10).clamp(3.0, 20.0),
        borderColor: const Color(0xFFA78BFA).withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ));
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        onTap: onMapTap != null
            ? (tapEvent, point) {
                debugPrint('[MapTap] fired: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
                onMapTap!(point);
              }
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.child.tracking',
        ),
        if (confirmedPolylines.isNotEmpty)
          PolylineLayer(polylines: confirmedPolylines),
        if (circleMarkers.isNotEmpty)
          CircleLayer(circles: circleMarkers),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
