import 'package:latlong2/latlong.dart';

class GeofencePendingConfig {
  String id;
  String name;
  String mode; // 'fixed' | 'path' — chỉ dùng phía client trong trình sửa;
  // luôn chuẩn hóa về 'fixed' trước khi gửi lên API (shape thật do path[] quyết định)
  double radius;
  double? centerLat;
  double? centerLng;
  List<LatLng> path;

  GeofencePendingConfig({
    required this.id,
    required this.name,
    required this.mode,
    required this.radius,
    this.centerLat,
    this.centerLng,
    List<LatLng>? path,
  }) : path = path ?? [];

  factory GeofencePendingConfig.defaults() => GeofencePendingConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '',
        mode: 'fixed',
        radius: 100,
        path: [],
      );

  GeofencePendingConfig copyWith({
    String? id,
    String? name,
    String? mode,
    double? radius,
    double? centerLat,
    double? centerLng,
    List<LatLng>? path,
  }) {
    return GeofencePendingConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      radius: radius ?? this.radius,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      path: path ?? List.from(this.path),
    );
  }
}
