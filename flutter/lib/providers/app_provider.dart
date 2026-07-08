import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../config/env.dart';

class AppProvider with ChangeNotifier {
	final ApiService _apiService;
	final LocationService _locationService = LocationService();

	SocketService? _socketService;
	StreamSubscription<Map<String, dynamic>>? _socketMessageSub;
	StreamSubscription<SocketStatus>? _socketStatusSub;
	Timer? _pollTimer;
	Timer? _locationNotifyTimer;
	StreamSubscription<dynamic>? _locationSub;
	Timer? _locationSyncTimer;

	String? _token;
	User? _currentUser;
	List<Device> _devices = [];
	String _selectedDeviceId = Env.default_device_id;
	String _deviceRole = '';
	Map<String, LocationData> _locations = {};
	GeofenceState _geofenceState = GeofenceState(
		mode: 'fixed',
		centerLat: Env.default_lat,
		centerLng: Env.default_lng,
		radiusM: Env.geofence_radius_m.toDouble(),
		source: 'fixed',
	);
	List<Alert> _alerts = [];
	Alert? _lastNewAlert;
	SocketStatus _socketStatus = SocketStatus.disconnected;
	bool _shareEnabled = false;
	bool _isLoading = false;
	String? _error;

	// Multi-device tracking
	Set<String> _trackingDeviceIds = {};

	// Geofence editor state
	bool _isPlanMode = false;
	String? _editingGeofenceId;
	GeofencePendingConfig _pendingConfig = GeofencePendingConfig.defaults();

	AppProvider({String? token}) : _apiService = ApiService(token: token) {
		_token = token;
		_loadFromStorage();
	}

	// --- Getters ---
	String? get token => _token;
	User? get currentUser => _currentUser;
	List<Device> get devices => _devices;
	String get selectedDeviceId => _selectedDeviceId;
	String get deviceRole => _deviceRole;
	Map<String, LocationData> get locations => _locations;
	GeofenceState get geofenceState => _geofenceState;
	List<Alert> get alerts => _alerts;
	Alert? get lastNewAlert => _lastNewAlert;
	SocketStatus get socketStatus => _socketStatus;
	bool get shareEnabled => _shareEnabled;
	bool get isLoading => _isLoading;
	String? get error => _error;
	bool get isOwner => _deviceRole == 'owner';
	Set<String> get trackingDeviceIds => Set.unmodifiable(_trackingDeviceIds);
	bool get isPlanMode => _isPlanMode;
	String? get editingGeofenceId => _editingGeofenceId;
	GeofencePendingConfig get pendingConfig => _pendingConfig;
	ApiService get apiService => _apiService;
	LocationService get locationService => _locationService;

	Future<void> _loadFromStorage() async {
		_isLoading = true;
		notifyListeners();

		final prefs = await SharedPreferences.getInstance();
		_token = prefs.getString('auth_token');
		if (_token != null) {
			_apiService.setToken(_token!);
			// Restore user info from local storage (backend has no /auth/me endpoint)
			final savedEmail = prefs.getString('user_email');
			final savedId = prefs.getString('user_id');
			if (savedEmail != null && savedId != null) {
				_currentUser = User(email: savedEmail, userId: savedId);
			}
			await _loadDevices();
		}

		_selectedDeviceId = prefs.getString('selected_device_id') ?? Env.default_device_id;

		final savedTracking = prefs.getStringList('tracking_devices');
		if (savedTracking != null && savedTracking.isNotEmpty) {
			_trackingDeviceIds = savedTracking.toSet();
		}

		if (_token != null) {
			connectSocket();
			fetchInitialLocations();
			fetchPersistedAlerts();
		}

		_isLoading = false;
		notifyListeners();
	}

	Future<void> _loadDevices() async {
		if (_token == null) {
			_isLoading = false;
			notifyListeners();
			return;
		}
		try {
			_devices = await _apiService.fetchDevices();
			if (_devices.isNotEmpty) {
				final stored = _selectedDeviceId;
				final match = _devices.firstWhere((d) => d.deviceId == stored, orElse: () => _devices.first);
				_selectedDeviceId = match.deviceId;
				_deviceRole = match.role;
			}
			// Seed tracking set if empty
			if (_trackingDeviceIds.isEmpty && _devices.isNotEmpty) {
				_trackingDeviceIds = {_selectedDeviceId};
				await _saveTrackingDevices();
			}
			_isLoading = false;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			_isLoading = false;
			notifyListeners();
		}
	}

	Future<void> fetchPersistedAlerts() async {
		if (_token == null || _devices.isEmpty) return;
		final allAlerts = <Alert>[];
		await Future.wait(_devices.map((d) async {
			try {
				final alerts = await _apiService.fetchAlerts(d.deviceId);
				allAlerts.addAll(alerts);
			} catch (e) {
				debugPrint('fetchPersistedAlerts error (${d.deviceId}): $e');
			}
		}));
		allAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
		_alerts = allAlerts.take(50).toList();
		notifyListeners();
	}

	Future<void> login(String email, String password) async {
		_isLoading = true;
		_error = null;
		notifyListeners();

		try {
			final user = await _apiService.login(email, password);
			_token = _apiService.token;
			if (_token == null) throw Exception('Server không trả về token đăng nhập');
			_currentUser = user;

			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('auth_token', _token!);
			await prefs.setString('user_email', user.email);
			await prefs.setString('user_id', user.userId);

			await _loadDevices();
			connectSocket();
			fetchInitialLocations();
			fetchPersistedAlerts();

			_isLoading = false;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			_isLoading = false;
			notifyListeners();
			rethrow;
		}
	}

	Future<void> register(String email, String password) async {
		_isLoading = true;
		_error = null;
		notifyListeners();

		try {
			final user = await _apiService.register(email, password);
			_token = _apiService.token;
			if (_token == null) throw Exception('Server không trả về token đăng ký');
			_currentUser = user;

			final prefs = await SharedPreferences.getInstance();
			await prefs.setString('auth_token', _token!);
			await prefs.setString('user_email', user.email);
			await prefs.setString('user_id', user.userId);

			await _loadDevices();
			connectSocket();
			fetchInitialLocations();
			fetchPersistedAlerts();

			_isLoading = false;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			_isLoading = false;
			notifyListeners();
			rethrow;
		}
	}

	Future<void> logout() async {
		_token = null;
		_currentUser = null;
		_devices = [];
		_selectedDeviceId = Env.default_device_id;
		_deviceRole = '';
		_locations = {};
		_alerts = [];
		_shareEnabled = false;
		_trackingDeviceIds = {};
		_isPlanMode = false;
		_editingGeofenceId = null;

		disconnectSocket();
		_stopPolling();
		_locationService.stopSharing();
		_cancelPositionSubscription();

		await _saveToStorage();
		notifyListeners();
	}

	Future<void> registerDevice(String deviceId) async {
		if (_token == null) {
			_error = 'Không có token đăng nhập';
			notifyListeners();
			return;
		}
		try {
			await _apiService.registerDevice(deviceId);
			await _loadDevices();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
			rethrow;
		}
	}

	Future<void> unregisterDevice(String deviceId) async {
		if (_token == null) return;
		try {
			await _apiService.deleteDevice(deviceId);
			_devices.removeWhere((d) => d.deviceId == deviceId);
			_trackingDeviceIds.remove(deviceId);
			if (_selectedDeviceId == deviceId) {
				_selectedDeviceId = _devices.isNotEmpty ? _devices.first.deviceId : Env.default_device_id;
				_deviceRole = _devices.isNotEmpty ? _devices.first.role : '';
			}
			_locations.remove(deviceId);
			await _saveToStorage();
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	Future<void> selectDevice(String deviceId) async {
		final device = _devices.firstWhere((d) => d.deviceId == deviceId, orElse: () => Device(deviceId: '', role: ''));
		_selectedDeviceId = deviceId;
		_deviceRole = device.role;
		await _saveToStorage();
		notifyListeners();
	}

	// --- Multi-device tracking ---

	void toggleTracking(String deviceId) {
		if (_trackingDeviceIds.contains(deviceId)) {
			_trackingDeviceIds.remove(deviceId);
		} else {
			_trackingDeviceIds.add(deviceId);
			// Set fallback location immediately so the marker appears in the first rebuild.
			// This prevents the PolylineLayer from appearing in a separate delayed rebuild
			// (which would cause shader compilation jank when ≥2 devices are tracked).
			if (!_locations.containsKey(deviceId)) {
				final lat = _geofenceState.centerLat != 0.0 ? _geofenceState.centerLat : Env.default_lat;
				final lng = _geofenceState.centerLng != 0.0 ? _geofenceState.centerLng : Env.default_lng;
				_locations[deviceId] = LocationData(lat: lat, lng: lng, insideGeofence: false, timestamp: 0);
			}
			fetchLatestLocation(deviceId);
		}
		_saveTrackingDevices();
		notifyListeners();
	}

	Future<void> _saveTrackingDevices() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setStringList('tracking_devices', _trackingDeviceIds.toList());
	}

	// --- Location ---

	void _scheduleLocationNotify() {
		if (_locationNotifyTimer?.isActive != true) {
			_locationNotifyTimer = Timer(
				const Duration(milliseconds: 100),
				notifyListeners,
			);
		}
	}

	void updateLocation(String deviceId, LocationData location) {
		_locations[deviceId] = location;
		_scheduleLocationNotify();
	}

	// --- Alerts ---

	void setAlerts(List<Alert> alerts) {
		_alerts = alerts;
		notifyListeners();
	}

	void addAlert(Alert alert) {
		_alerts.insert(0, alert);
		if (_alerts.length > 10) _alerts.removeLast();
		notifyListeners();
	}

	Future<void> clearAlerts() async {
		_alerts = [];
		_lastNewAlert = null;
		notifyListeners();
		for (final d in _devices) {
			try {
				await _apiService.clearAlerts(d.deviceId);
			} catch (e) {
				debugPrint('clearAlerts error (${d.deviceId}): $e');
			}
		}
	}

	void clearLastNewAlert() {
		_lastNewAlert = null;
	}

	// --- Geofence mode ---

	void _subscribeToPosition() {
		_locationSub?.cancel();
		_locationSub = _locationService.positionStream.listen((_) {
			notifyListeners();
			_scheduleGeofenceCenterSync();
		});
	}

	void _scheduleGeofenceCenterSync() {
		_locationSyncTimer?.cancel();
		_locationSyncTimer = Timer(const Duration(seconds: 10), () {
			if (!_shareEnabled) return;
			final pos = _locationService.currentPosition;
			if (pos != null) _syncMobileCenter(pos.latitude, pos.longitude);
		});
	}

	// Fire-and-forget: chỉ đẩy vị trí lên backend, KHÔNG cập nhật _geofenceState
	// Tránh race condition với setGeofenceMode khi timer fires gần thời điểm switch mode
	Future<void> _syncMobileCenter(double lat, double lng) async {
		if (_token == null || !isOwner || !_shareEnabled) return;
		try {
			await _apiService.updateGeofenceCenter(lat, lng);
		} catch (e) {
			debugPrint('Mobile center sync error: $e');
		}
	}

	void _cancelPositionSubscription() {
		_locationSub?.cancel();
		_locationSub = null;
		_locationSyncTimer?.cancel();
		_locationSyncTimer = null;
	}

	Future<void> setGeofenceMode(String mode) async {
		debugPrint('[GeofenceMode] setGeofenceMode("$mode") called, token=${_token != null}, shareEnabled=$_shareEnabled, currentMode=${_geofenceState.mode}');
		if (_token == null) {
			debugPrint('[GeofenceMode] Aborted: token is null');
			return;
		}
		try {
			final state = await _apiService.postGeofenceMode(mode);
			debugPrint('[GeofenceMode] API response: mode=${state.mode}, radiusM=${state.radiusM}');
			_geofenceState = state;
			if (mode == 'mobile') {
				_shareEnabled = true;
				_locationService.startSharing();
				_subscribeToPosition();
			} else {
				_shareEnabled = false;
				_locationService.stopSharing();
				_cancelPositionSubscription();
			}
			_error = null;
			notifyListeners();
			debugPrint('[GeofenceMode] Done: geofenceState.mode=${_geofenceState.mode}, shareEnabled=$_shareEnabled');
		} catch (e) {
			debugPrint('[GeofenceMode] ERROR: $e');
			_error = 'Chuyển mode thất bại: $e';
			notifyListeners();
		}
	}

	Future<void> fetchGeofenceState() async {
		if (_token == null) return;
		try {
			final state = await _apiService.fetchGeofenceState();
			_geofenceState = state;
			if (state.mode == 'mobile' && !_shareEnabled) {
				_shareEnabled = true;
				_locationService.startSharing();
				_subscribeToPosition();
			}
			// Retry loading devices if the initial load failed (e.g. server was sleeping)
			if (_devices.isEmpty) {
				await _loadDevices();
			}
			// Seed tracking from geofence state if still empty
			if (_trackingDeviceIds.isEmpty && _devices.isNotEmpty) {
				_trackingDeviceIds = {_selectedDeviceId};
				await _saveTrackingDevices();
				fetchInitialLocations();
			}
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	Future<void> fetchLatestLocation(String deviceId) async {
		try {
			final location = await _apiService.fetchLatest(deviceId);
			if (location != null) {
				updateLocation(deviceId, location);
			} else if (!_locations.containsKey(deviceId)) {
				_applyFallbackLocation(deviceId);
			}
		} catch (e) {
			debugPrint('fetchLatestLocation error ($deviceId): $e');
			// Fallback chỉ áp dụng nếu chưa có vị trí nào
			if (!_locations.containsKey(deviceId)) {
				_applyFallbackLocation(deviceId);
			}
		}
	}

	void _applyFallbackLocation(String deviceId) {
		final lat = _geofenceState.centerLat != 0.0 ? _geofenceState.centerLat : Env.default_lat;
		final lng = _geofenceState.centerLng != 0.0 ? _geofenceState.centerLng : Env.default_lng;
		_locations[deviceId] = LocationData(
			lat: lat,
			lng: lng,
			insideGeofence: false,
			timestamp: 0,
		);
		_scheduleLocationNotify();
	}

	void fetchInitialLocations() {
		for (final deviceId in _trackingDeviceIds) {
			fetchLatestLocation(deviceId);
		}
	}

	Future<void> updateGeofenceRadius(double radiusM) async {
		if (_token == null || !isOwner) return;
		try {
			final state = await _apiService.updateGeofenceRadius(radiusM);
			_geofenceState = state;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	Future<void> updateGeofenceCenter(double lat, double lng) async {
		if (_token == null || !isOwner) return;
		try {
			final state = await _apiService.updateGeofenceCenter(lat, lng);
			_geofenceState = state;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	// --- Geofence CRUD (Plan Mode) ---

	void startPlanMode({Geofence? editTarget}) {
		if (editTarget != null) {
			_editingGeofenceId = editTarget.id;
			_pendingConfig = GeofencePendingConfig(
				id: editTarget.id,
				name: editTarget.name,
				mode: editTarget.mode,
				radius: editTarget.radiusM,
				centerLat: editTarget.centerLat,
				centerLng: editTarget.centerLng,
				path: List.from(editTarget.path),
			);
		} else {
			_editingGeofenceId = null;
			_pendingConfig = GeofencePendingConfig.defaults();
		}
		_isPlanMode = true;
		notifyListeners();
	}

	void cancelPlanMode() {
		_isPlanMode = false;
		_editingGeofenceId = null;
		notifyListeners();
	}

	void updatePendingConfig(GeofencePendingConfig config) {
		_pendingConfig = config;
		notifyListeners();
	}

	void handleMapTap(LatLng point) {
		if (!_isPlanMode) return;
		if (_pendingConfig.mode == 'path') {
			_pendingConfig = _pendingConfig.copyWith(
				path: [..._pendingConfig.path, point],
			);
		} else {
			_pendingConfig = _pendingConfig.copyWith(
				centerLat: point.latitude,
				centerLng: point.longitude,
			);
		}
		notifyListeners();
	}

	void removeLastPathPoint() {
		if (_pendingConfig.path.isEmpty) return;
		_pendingConfig = _pendingConfig.copyWith(
			path: _pendingConfig.path.sublist(0, _pendingConfig.path.length - 1),
		);
		notifyListeners();
	}

	Future<void> saveGeofence() async {
		if (_token == null) return;
		_isLoading = true;
		_error = null;
		notifyListeners();
		try {
			final cfg = _pendingConfig;
			// Send as [[lat, lng], ...] to match backend's list[list[float]] type
			final pathJson = cfg.path.map((p) => [p.latitude, p.longitude]).toList();
			// Editor chỉ tạo vùng cố định (tròn hoặc đường đi); 'mobile' (GPS-follow)
			// chỉ được thiết lập qua dock toggle, không qua trình sửa này.
			final apiMode = cfg.mode == 'path' ? 'fixed' : cfg.mode;
			final state = await _apiService.postGeofenceFull(
				geofenceId: cfg.id,
				name: cfg.name,
				mode: apiMode,
				radiusM: cfg.radius,
				lat: cfg.centerLat,
				lng: cfg.centerLng,
				path: pathJson,
			);
			_geofenceState = state;
			_isPlanMode = false;
			_editingGeofenceId = null;
			_isLoading = false;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			_isLoading = false;
			notifyListeners();
		}
	}

	Future<void> removeGeofence(String geofenceId) async {
		if (_token == null) return;
		try {
			final state = await _apiService.deleteGeofence(geofenceId);
			_geofenceState = state;
			notifyListeners();
		} catch (e) {
			_error = e.toString();
			notifyListeners();
		}
	}

	// --- Socket ---

	void connectSocket() {
		if (_token == null) return;

		if (_socketService != null) {
			final currentStatus = _socketService!.status;
			if (currentStatus == SocketStatus.connected || currentStatus == SocketStatus.connecting) {
				return;
			}
			_socketService!.disconnect();
			_socketService = null;
		}

		_socketService = SocketService(Env.backend_ws_url, _token!);
		_socketStatus = SocketStatus.connecting;
		notifyListeners();

		_socketMessageSub?.cancel();
		_socketMessageSub = _socketService!.messageStream.listen(
			_handleSocketMessage,
			onError: (e) {
				_socketStatus = SocketStatus.error;
				notifyListeners();
			},
		);

		_socketStatusSub?.cancel();
		_socketStatusSub = _socketService!.statusStream.listen((status) {
			_socketStatus = status;
			if (status == SocketStatus.connected) {
				_stopPolling();
			} else if (status == SocketStatus.error) {
				_startPolling();
			}
			notifyListeners();
		});

		_socketService!.connect();
	}

	Alert _enrichAlertWithZoneName(Alert alert) {
		if (alert.geofenceId == null) return alert;
		final zone = _geofenceState.geofences
				.where((g) => g.id == alert.geofenceId)
				.map((g) => g.name)
				.firstOrNull;
		return zone != null ? alert.copyWith(zoneName: zone) : alert;
	}

	void _handleSocketMessage(Map<String, dynamic> message) {
		final type = message['type'] as String?;

		if (type == 'location' || type == 'location_update') {
			try {
				final deviceId = (message['deviceId'] ?? message['device_id']) as String?;
				final data = message['data'] as Map<String, dynamic>? ?? message;
				if (deviceId != null && _trackingDeviceIds.contains(deviceId)) {
					_locations[deviceId] = LocationData.fromJson(data);
					_scheduleLocationNotify();
				}
			} catch (e) {
				debugPrint('Error handling location message: $e');
			}
		} else if (type == 'alert') {
			try {
				final alertData = message['data'] as Map<String, dynamic>? ?? message;
				final alert = _enrichAlertWithZoneName(Alert.fromJson(alertData));
				_alerts.insert(0, alert);
				if (_alerts.length > 50) _alerts.removeLast();
				_lastNewAlert = alert;
				final lat = (alertData['lat'] ?? alertData['latitude']) as num?;
				final lng = (alertData['lng'] ?? alertData['longitude']) as num?;
				if (alert.deviceId.isNotEmpty && lat != null && lng != null &&
						_trackingDeviceIds.contains(alert.deviceId)) {
					_locations[alert.deviceId] = LocationData.fromJson(alertData);
				}
				notifyListeners();
			} catch (e) {
				debugPrint('Error handling alert message: $e');
			}
		} else if (type == 'geofence_alert') {
			try {
				final alert = _enrichAlertWithZoneName(Alert.fromJson(message));
				_alerts.insert(0, alert);
				if (_alerts.length > 50) _alerts.removeLast();
				_lastNewAlert = alert;
				if (alert.deviceId.isNotEmpty && alert.lat != 0.0 && alert.lng != 0.0 &&
					_trackingDeviceIds.contains(alert.deviceId)) {
					_locations[alert.deviceId] = LocationData(
						lat: alert.lat,
						lng: alert.lng,
						timestamp: alert.timestamp,
						insideGeofence: message['insideGeofence'] as bool? ?? false,
					);
				}
				notifyListeners();
			} catch (e) {
				debugPrint('Error handling geofence_alert message: $e');
			}
		} else if (type == 'geofence_state_update') {
			try {
				final newState = GeofenceState.fromJson(message);
				debugPrint('[WS] geofence_state_update: mode=${newState.mode}, shareEnabled=$_shareEnabled, currentMode=${_geofenceState.mode}');
				// Guard: nếu _shareEnabled=false (đã switch sang fixed) nhưng broadcast
				// nói mode='mobile', đây là stale message từ center-update race condition —
				// bỏ qua để tránh re-activate mobile mode ngoài ý muốn.
				if (newState.mode == 'mobile' && !_shareEnabled) {
					debugPrint('[WS] SKIPPED stale mobile broadcast (already in fixed mode)');
					notifyListeners();
				} else {
					_geofenceState = newState;
					if (newState.mode != 'mobile' && _shareEnabled) {
						// Mode bị đổi sang fixed từ nguồn bên ngoài (thiết bị khác)
						debugPrint('[WS] External fixed-mode switch detected, stopping sharing');
						_shareEnabled = false;
						_locationService.stopSharing();
						_cancelPositionSubscription();
					}
					notifyListeners();
				}
			} catch (e) {
				debugPrint('Error handling geofence_state_update: $e');
			}
		}
	}

	void disconnectSocket() {
		_locationNotifyTimer?.cancel();
		_locationNotifyTimer = null;
		_socketMessageSub?.cancel();
		_socketMessageSub = null;
		_socketStatusSub?.cancel();
		_socketStatusSub = null;
		_socketService?.dispose();
		_socketService = null;
		_socketStatus = SocketStatus.disconnected;
		_stopPolling();
		notifyListeners();
	}

	void _startPolling() {
		if (_pollTimer?.isActive == true) return;
		fetchInitialLocations();
		_pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
			final ids = _trackingDeviceIds.toList();
			bool changed = false;
			await Future.wait(ids.map((id) async {
				try {
					final location = await _apiService.fetchLatest(id);
					if (location != null) {
						_locations[id] = location;
						changed = true;
					}
				} catch (e) {
					debugPrint('Polling error ($id): $e');
				}
			}));
			if (changed) notifyListeners();
		});
	}

	void _stopPolling() {
		_pollTimer?.cancel();
		_pollTimer = null;
	}


	@override
	void dispose() {
		_locationNotifyTimer?.cancel();
		_cancelPositionSubscription();
		_stopPolling();
		disconnectSocket();
		super.dispose();
	}

	Future<void> _saveToStorage() async {
		final prefs = await SharedPreferences.getInstance();
		if (_token != null) {
			await prefs.setString('auth_token', _token!);
		} else {
			await prefs.remove('auth_token');
		}
		await prefs.setString('selected_device_id', _selectedDeviceId);
		await prefs.setStringList('tracking_devices', _trackingDeviceIds.toList());
	}
}
