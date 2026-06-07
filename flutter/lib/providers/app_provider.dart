import 'dart:async';
import 'package:flutter/foundation.dart';
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
    radiusM: Env.geofence_radius_m,
    source: 'fixed',
  );
  List<Alert> _alerts = [];
  SocketStatus _socketStatus = SocketStatus.disconnected;
  Map<String, dynamic>? _latestMessage;
  bool _shareEnabled = false;
  bool _isLoading = false;
  String? _error;

  AppProvider({String? token}) : _apiService = ApiService(token: token) {
    _token = token;
    _loadFromStorage();
  }

  String? get token => _token;
  User? get currentUser => _currentUser;
  List<Device> get devices => _devices;
  String get selectedDeviceId => _selectedDeviceId;
  String get deviceRole => _deviceRole;
  Map<String, LocationData> get locations => _locations;
  GeofenceState get geofenceState => _geofenceState;
  List<Alert> get alerts => _alerts;
  SocketStatus get socketStatus => _socketStatus;
  Map<String, dynamic>? get latestMessage => _latestMessage;
  bool get shareEnabled => _shareEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOwner => _deviceRole == 'owner';

  Future<void> _loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      _apiService.setToken(_token!);
      await _loadCurrentUser();
      await _loadDevices();
    }

    _selectedDeviceId = prefs.getString('selected_device_id') ?? Env.default_device_id;

    if (_token != null) {
      connectSocket();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    if (_token == null) return;
    try {
      _currentUser = await _apiService.getMe();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _apiService.login(email, password);
      _token = _apiService.token;
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);

      await _loadDevices();
      connectSocket();

      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<User> register(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _apiService.register(email, password);
      _token = _apiService.token;
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);

      await _loadDevices();
      connectSocket();

      _isLoading = false;
      notifyListeners();
      return user;
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

    disconnectSocket();
    _locationService.stopSharing();

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
    }
  }

  Future<void> unregisterDevice(String deviceId) async {
    if (_token == null) return;
    try {
      await _apiService.deleteDevice(deviceId);
      _devices.removeWhere((d) => d.deviceId == deviceId);
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

  void updateLocation(String deviceId, LocationData location) {
    _locations[deviceId] = location;
    notifyListeners();
  }

  void setAlerts(List<Alert> alerts) {
    _alerts = alerts;
    notifyListeners();
  }

  void addAlert(Alert alert) {
    _alerts.insert(0, alert);
    if (_alerts.length > 10) _alerts.removeLast();
    notifyListeners();
  }

  void clearAlerts() {
    _alerts = [];
    notifyListeners();
  }

  Future<void> setGeofenceMode(String mode) async {
    if (_token == null) return;

    try {
      final state = await _apiService.postGeofenceMode(mode);
      _geofenceState = state;
      if (mode == 'mobile') {
        _shareEnabled = true;
        _locationService.startSharing();
      } else {
        _shareEnabled = false;
        _locationService.stopSharing();
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchGeofenceState() async {
    if (_token == null) return;
    try {
      final state = await _apiService.fetchGeofenceState();
      _geofenceState = state;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchLatestLocation(String deviceId) async {
    if (_token == null) return;
    try {
      final location = await _apiService.fetchLatest(deviceId);
      if (location != null) {
        updateLocation(deviceId, location);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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

  LocationService get locationService => _locationService;

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

    _socketService!.connect();

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
      notifyListeners();
    });
  }

  void _handleSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'location' || type == 'location_update') {
      try {
        final deviceId = message['deviceId'] ?? message['device_id'] as String?;
        final data = message['data'] as Map<String, dynamic>? ?? message;
        if (deviceId != null) {
          _locations[deviceId] = LocationData.fromJson(data);
          notifyListeners();
        }
      } catch (e) {
        print('Error handling location message: $e');
      }
    } else if (type == 'alert') {
      try {
        final alertData = message['data'] as Map<String, dynamic>? ?? message;
        final alert = Alert.fromJson(alertData);
        _alerts.insert(0, alert);
        if (_alerts.length > 10) _alerts.removeLast();
        notifyListeners();
      } catch (e) {
        print('Error handling alert message: $e');
      }
    } else if (type == 'geofence_state_update') {
      try {
        _geofenceState = GeofenceState.fromJson(message);
        notifyListeners();
      } catch (e) {
        print('Error handling geofence_state_update: $e');
      }
    }

    _latestMessage = message;
    notifyListeners();
  }

  void disconnectSocket() {
    _socketMessageSub?.cancel();
    _socketMessageSub = null;
    _socketStatusSub?.cancel();
    _socketStatusSub = null;
    _socketService?.disconnect();
    _socketService = null;
    _socketStatus = SocketStatus.disconnected;
    _latestMessage = null;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('auth_token', _token!);
    } else {
      await prefs.remove('auth_token');
    }
    await prefs.setString('selected_device_id', _selectedDeviceId);
  }
}
