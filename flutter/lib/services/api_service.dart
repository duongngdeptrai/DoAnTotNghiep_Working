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
		final h = <String, String>{
			'Content-Type': 'application/json',
		};
		if (_token != null) h['Authorization'] = 'Bearer $_token';
		return h;
	}

	Future<User> login(String email, String password) async {
		final response = await http.post(
			Uri.parse('$baseUrl/auth/login'),
			headers: {'Content-Type': 'application/json'},
			body: jsonEncode({'email': email, 'password': password}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			final data = jsonDecode(response.body) as Map<String, dynamic>;
			// Backend may return access_token (JWT) or just user info (id, email, createdAt)
			_token = data['access_token'] as String? ?? data['id'] as String?;
			final userData = data['user'] as Map<String, dynamic>? ?? data;
			return User.fromJson(userData);
		} else {
			final detail = _parseError(response);
			throw Exception('Đăng nhập thất bại: $detail');
		}
	}

	Future<User> register(String email, String password) async {
		final response = await http.post(
			Uri.parse('$baseUrl/auth/register'),
			headers: {'Content-Type': 'application/json'},
			body: jsonEncode({'email': email, 'password': password}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200 || response.statusCode == 201) {
			final data = jsonDecode(response.body) as Map<String, dynamic>;
			_token = data['access_token'] as String? ?? data['id'] as String?;
			final userData = data['user'] as Map<String, dynamic>? ?? data;
			return User.fromJson(userData);
		} else {
			final detail = _parseError(response);
			throw Exception('Đăng ký thất bại: $detail');
		}
	}

	Future<User> getMe() async {
		final response = await http.get(
			Uri.parse('$baseUrl/auth/me'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			return User.fromJson(jsonDecode(response.body));
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể lấy thông tin user: $detail');
		}
	}

	Future<List<Device>> fetchDevices() async {
		final response = await http.get(
			Uri.parse('$baseUrl/devices'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			final List<dynamic> data = jsonDecode(response.body);
			return data.map((json) => Device.fromJson(json)).toList();
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể lấy danh sách thiết bị: $detail');
		}
	}

	Future<void> registerDevice(String deviceId) async {
		final response = await http.post(
			Uri.parse('$baseUrl/devices'),
			headers: _headers,
			body: jsonEncode({'deviceId': deviceId}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode != 200 && response.statusCode != 201) {
			final detail = _parseError(response);
			throw Exception('Không thể đăng ký thiết bị: $detail');
		}
	}

	Future<void> deleteDevice(String deviceId) async {
		final response = await http.delete(
			Uri.parse('$baseUrl/devices/$deviceId'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));

		if (response.statusCode != 200 && response.statusCode != 204) {
			final detail = _parseError(response);
			throw Exception('Không thể xóa thiết bị: $detail');
		}
	}

	Future<LocationData?> fetchLatest(String deviceId) async {
		final response = await http.get(
			Uri.parse('$baseUrl/latest/$deviceId'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			final data = jsonDecode(response.body);
			if (data == null) return null;
			return LocationData.fromJson(data);
		} else if (response.statusCode == 404) {
			return null;
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể lấy vị trí: $detail');
		}
	}

	Future<GeofenceState> postGeofenceMode(String mode) async {
		final response = await http.post(
			Uri.parse('$baseUrl/geofence/mode'),
			headers: _headers,
			body: jsonEncode({'mode': mode}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể cập nhật chế độ geofence: $detail');
		}
	}

	Future<GeofenceState> fetchGeofenceState() async {
		final response = await http.get(
			Uri.parse('$baseUrl/geofence/state'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể lấy trạng thái geofence: $detail');
		}
	}

	Future<GeofenceState> updateGeofenceRadius(double radiusM) async {
		final response = await http.post(
			Uri.parse('$baseUrl/geofence/radius'),
			headers: _headers,
			body: jsonEncode({'radius_m': radiusM}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể cập nhật bán kính: $detail');
		}
	}

	Future<GeofenceState> updateGeofenceCenter(double lat, double lng) async {
		final response = await http.post(
			Uri.parse('$baseUrl/geofence/center'),
			headers: _headers,
			body: jsonEncode({'lat': lat, 'lng': lng}),
		).timeout(const Duration(seconds: 15));

		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			final detail = _parseError(response);
			throw Exception('Không thể cập nhật tâm vùng: $detail');
		}
	}

	// --- Statistics ---

	Future<DeviceStats> fetchDeviceStats(String deviceId, {int? start, int? end}) async {
		final params = <String, String>{};
		if (start != null) params['start'] = start.toString();
		if (end != null) params['end'] = end.toString();
		final uri = Uri.parse('$baseUrl/stats/$deviceId').replace(queryParameters: params.isEmpty ? null : params);
		final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
		if (response.statusCode == 200) {
			return DeviceStats.fromJson(jsonDecode(response.body));
		} else {
			throw Exception('Không thể lấy thống kê: ${_parseError(response)}');
		}
	}

	Future<List<AggregatedStat>> fetchAggregatedStats(String deviceId, {int? start, int? end, String interval = 'day'}) async {
		final params = <String, String>{'interval': interval};
		if (start != null) params['start'] = start.toString();
		if (end != null) params['end'] = end.toString();
		final uri = Uri.parse('$baseUrl/stats/$deviceId/aggregated').replace(queryParameters: params);
		final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
		if (response.statusCode == 200) {
			final List<dynamic> data = jsonDecode(response.body);
			return data.map((j) => AggregatedStat.fromJson(j as Map<String, dynamic>)).toList();
		} else {
			throw Exception('Không thể lấy thống kê tổng hợp: ${_parseError(response)}');
		}
	}

	// --- Device Sharing ---

	Future<void> shareDevice(String deviceId, String email) async {
		final response = await http.post(
			Uri.parse('$baseUrl/devices/$deviceId/share'),
			headers: _headers,
			body: jsonEncode({'email': email}),
		).timeout(const Duration(seconds: 15));
		if (response.statusCode != 200 && response.statusCode != 201) {
			throw Exception('Không thể chia sẻ thiết bị: ${_parseError(response)}');
		}
	}

	Future<void> unshareDevice(String deviceId, String email) async {
		final encodedEmail = Uri.encodeComponent(email);
		final response = await http.delete(
			Uri.parse('$baseUrl/devices/$deviceId/share/$encodedEmail'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));
		if (response.statusCode != 200 && response.statusCode != 204) {
			throw Exception('Không thể bỏ chia sẻ thiết bị: ${_parseError(response)}');
		}
	}

	// --- Device Config ---

	Future<DeviceConfig> fetchDeviceConfig(String deviceId) async {
		final response = await http.get(
			Uri.parse('$baseUrl/devices/$deviceId/config'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));
		if (response.statusCode == 200) {
			return DeviceConfig.fromJson(jsonDecode(response.body));
		} else {
			throw Exception('Không thể lấy cấu hình: ${_parseError(response)}');
		}
	}

	Future<void> postDeviceConfig(String deviceId, String parentEmail, bool alertEnabled) async {
		final response = await http.post(
			Uri.parse('$baseUrl/devices/$deviceId/config'),
			headers: _headers,
			body: jsonEncode({'parentEmail': parentEmail, 'alertEnabled': alertEnabled}),
		).timeout(const Duration(seconds: 15));
		if (response.statusCode != 200 && response.statusCode != 201) {
			throw Exception('Không thể lưu cấu hình: ${_parseError(response)}');
		}
	}

	Future<void> deleteDeviceConfig(String deviceId) async {
		final response = await http.delete(
			Uri.parse('$baseUrl/devices/$deviceId/config'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));
		if (response.statusCode != 200 && response.statusCode != 204) {
			throw Exception('Không thể xóa cấu hình: ${_parseError(response)}');
		}
	}

	// --- Full Geofence CRUD ---

	Future<GeofenceState> postGeofenceFull({
		required String geofenceId,
		String? name,
		required String mode,
		required double radiusM,
		double? lat,
		double? lng,
		List<dynamic> path = const [],
	}) async {
		final body = <String, dynamic>{
			'geofence_id': geofenceId,
			if (name != null && name.isNotEmpty) 'name': name,
			'mode': mode,
			'radius_m': radiusM,
			if (lat != null) 'lat': lat,
			if (lng != null) 'lng': lng,
			'path': path,
		};
		final response = await http.post(
			Uri.parse('$baseUrl/geofence/update'),
			headers: _headers,
			body: jsonEncode(body),
		).timeout(const Duration(seconds: 15));
		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			throw Exception('Không thể lưu geofence: ${_parseError(response)}');
		}
	}

	Future<GeofenceState> deleteGeofence(String geofenceId) async {
		final response = await http.delete(
			Uri.parse('$baseUrl/geofence/$geofenceId'),
			headers: _headers,
		).timeout(const Duration(seconds: 15));
		if (response.statusCode == 200) {
			return GeofenceState.fromJson(jsonDecode(response.body));
		} else {
			throw Exception('Không thể xóa geofence: ${_parseError(response)}');
		}
	}

	String _parseError(http.Response response) {
		try {
			final data = jsonDecode(response.body);
			final detail = data['detail'] ?? data['message'] ?? data['error'] ?? response.body;
			return '${response.statusCode} - $detail';
		} catch (_) {
			return response.statusCode.toString();
		}
	}
}
