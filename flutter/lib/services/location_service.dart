import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/env.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  Position? _currentPosition;
  bool _isSharing = false;

  Position? get currentPosition => _currentPosition;
  bool get isSharing => _isSharing;
  Stream<Position> get positionStream => _positionController.stream;
  Stream<String> get errorStream => _errorController.stream;

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startSharing() async {
    if (_isSharing) return;

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      _errorController.add('Quyền vị trí bị từ chối');
      return;
    }

    _isSharing = true;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _positionController.add(position);
      },
      onError: (error) {
        _isSharing = false;
        _errorController.add('Lỗi lấy vị trí: $error');
      },
    );
  }

  void stopSharing() {
    _isSharing = false;
    _positionStream?.cancel();
    _positionStream = null;
  }

  void dispose() {
    stopSharing();
    _positionController.close();
    _errorController.close();
  }
}
