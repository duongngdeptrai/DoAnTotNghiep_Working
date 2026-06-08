class DeviceConfig {
  final String parentEmail;
  final bool alertEnabled;

  DeviceConfig({required this.parentEmail, required this.alertEnabled});

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      parentEmail: json['parent_email'] ?? json['parentEmail'] ?? '',
      alertEnabled: json['alert_enabled'] ?? json['alertEnabled'] ?? true,
    );
  }
}
