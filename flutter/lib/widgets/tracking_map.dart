import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';

class TrackingMap extends StatelessWidget {
  final LatLng center;
  final Map<String, LocationData> locations;
  final List<String> trackingDeviceIds;
  final int geofenceRadiusM;
  final Function(String deviceId)? onDeviceSelected;
  final String? focusedDeviceId;

  const TrackingMap({
    super.key,
    required this.center,
    required this.locations,
    required this.trackingDeviceIds,
    required this.geofenceRadiusM,
    this.onDeviceSelected,
    this.focusedDeviceId,
  });

  Color _getDeviceColor(String deviceId) {
    final colors = [
      const Color(0xFF22D3EE),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFF472B6),
      const Color(0xFFFB923C),
      const Color(0xFF60A5FA),
      const Color(0xFFFBF124),
      const Color(0xFFF87171),
    ];
    final index = deviceId.length % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final markers = trackingDeviceIds
        .where((id) => locations.containsKey(id))
        .map((deviceId) {
      final location = locations[deviceId]!;
      final isFocused = focusedDeviceId == deviceId;
      final color = _getDeviceColor(deviceId);

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
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: isFocused ? 20 : 14,
                  height: isFocused ? 20 : 14,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: isFocused ? 12 : 8,
                    height: isFocused ? 12 : 8,
                    decoration: BoxDecoration(
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

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.child.tracking',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}