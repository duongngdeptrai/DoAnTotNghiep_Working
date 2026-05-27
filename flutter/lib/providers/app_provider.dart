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

  String? _token;
  User? _currentUser;
  List<Device> _devices = [];
  String _selectedDeviceId = '';
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

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    if (_token == null) return;
    try {
      _currentUser = await _apiService.getMe(_token!);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadDevices() async {
    if (_token == null) return;
    try {
      _devices = await _apiService.fetchDevices(_token!);
      if (_devices.isNotEmpty && _selectedDeviceId.isEmpty) {
        _selectedDeviceId = _devices.first.deviceId;
        _deviceRole = _devices.first.role;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
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

  void logout() {
    _token = null;
    _currentUser = null;
    _devices = [];
    _selectedDeviceId = Env.default_device_id;
    _deviceRole = '';
    _locations = {};
    _alerts = [];

    _saveToStorage();
    notifyListeners();
  }

  Future<void> registerDevice(String deviceId) async {
    if (_token == null) {
      _error = 'Không có token đăng nhập';
      notifyListeners();
      return;
    }

    try {
      await _apiService.registerDevice(_token!, deviceId);
      await _loadDevices();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void selectDevice(String deviceId) {
    final device = _devices.firstWhere((d) => d.deviceId == deviceId, orElse: () => Device(deviceId: '', role: ''));
    _selectedDeviceId = deviceId;
    _deviceRole = device.role;
    _saveToStorage();
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
      final state = await _apiService.postGeofenceMode(_token!, mode);
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
      final state = await _apiService.fetchGeofenceState(_token!);
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
      final location = await _apiService.fetchLatest(_token!, deviceId);
      if (location != null) {
        updateLocation(deviceId, location);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  LocationService get locationService => _locationService;

  void _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('auth_token', _token!);
    } else {
      await prefs.remove('auth_token');
    }
    await prefs.setString('selected_device_id', _selectedDeviceId);
  }
}