class Env {
  static String get backend_http_url =>
      const String.fromEnvironment('BACKEND_HTTP_URL', defaultValue: 'http://192.168.76.41:9000');

  static String get backend_ws_url =>
      const String.fromEnvironment('BACKEND_WS_URL', defaultValue: 'ws://192.168.76.41:9000/ws');

  static String get default_device_id =>
      const String.fromEnvironment('DEFAULT_DEVICE_ID', defaultValue: 'child_01');

  static double get default_lat => 21.0285;

  static double get default_lng => 105.8542;

  static int get geofence_radius_m => 100;
}