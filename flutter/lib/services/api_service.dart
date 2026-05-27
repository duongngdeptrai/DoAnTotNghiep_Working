import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/models.dart';

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({String? token}) : baseUrl = Env.backend_http_url {
    _token = token;
  }

  void setToken(String token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<User> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      return User.fromJson(data['user']);
    } else {
      throw Exception('Đăng nhập thất bại: ${response.statusCode}');
    }
  }

  Future<User> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      return User.fromJson(data['user']);
    } else {
      throw Exception('Đăng ký thất bại: ${response.statusCode}');
    }
  }

  Future<User> getMe(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Không thể lấy thông tin user: ${response.statusCode}');
    }
  }

  Future<List<Device>> fetchDevices(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Device.fromJson(json)).toList();
    } else {
      throw Exception('Không thể lấy danh sách thiết bị: ${response.statusCode}');
    }
  }

  Future<void> registerDevice(String token, String deviceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/devices/register'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'device_id': deviceId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Không thể đăng ký thiết bị: ${response.statusCode}');
    }
  }

  Future<LocationData?> fetchLatest(String token, String deviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/devices/$deviceId/latest'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      return LocationData.fromJson(data);
    } else {
      throw Exception('Không thể lấy vị trí: ${response.statusCode}');
    }
  }

  Future<GeofenceState> postGeofenceMode(String token, String mode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/geofence/mode'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'mode': mode}),
    );

    if (response.statusCode == 200) {
      return GeofenceState.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Không thể cập nhật chế độ geofence: ${response.statusCode}');
    }
  }

  Future<GeofenceState> fetchGeofenceState(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/geofence/state'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return GeofenceState.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Không thể lấy trạng thái geofence: ${response.statusCode}');
    }
  }
}