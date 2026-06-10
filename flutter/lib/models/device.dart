class Device {
  final String deviceId;
  final String role;

  Device({
    required this.deviceId,
    required this.role,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: (json['device_id'] ?? json['deviceId']) as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'role': role,
    };
  }
}
