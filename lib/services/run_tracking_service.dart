import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunTrackingService {
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  final List<LatLng> _routePoints = [];
  double _totalDistanceMeters = 0.0;
  bool _isRunning = false;

  final StreamController<List<LatLng>> _routeController =
      StreamController<List<LatLng>>.broadcast();
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();
  final StreamController<ServiceStatus> _serviceStatusController =
      StreamController<ServiceStatus>.broadcast();
  final StreamController<double> _accuracyController =
      StreamController<double>.broadcast();

  Stream<List<LatLng>> get routeStream => _routeController.stream;
  Stream<double> get distanceStream => _distanceController.stream;
  Stream<ServiceStatus> get serviceStatusStream =>
      _serviceStatusController.stream;
  Stream<double> get accuracyStream => _accuracyController.stream;

  bool get isRunning => _isRunning;

  void startRun() {
    _isRunning = true;
    _routePoints.clear();
    _totalDistanceMeters = 0.0;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Update every 3 meters
    );

    // Listen for Service Status (GPS toggled on/off)
    _serviceStatusStream =
        Geolocator.getServiceStatusStream().listen((status) {
      _serviceStatusController.add(status);
    });

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      // Emit GPS accuracy so the UI can reflect signal quality
      _accuracyController.add(position.accuracy);

      final newPoint = LatLng(position.latitude, position.longitude);

      if (_routePoints.isNotEmpty) {
        final lastPoint = _routePoints.last;
        final distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        _totalDistanceMeters += distance;
      }

      _routePoints.add(newPoint);

      _routeController.add(List.from(_routePoints));
      _distanceController.add(_totalDistanceMeters);
    }, onError: (error) {
      debugPrint('Location stream error: $error');
    });
  }

  void pauseRun() {
    _isRunning = false;
    _positionStream?.pause();
  }

  void resumeRun() {
    _isRunning = true;
    _positionStream?.resume();
  }

  Future<void> stopRun() async {
    _isRunning = false;
    await _positionStream?.cancel();
    await _serviceStatusStream?.cancel();
    _positionStream = null;
    _serviceStatusStream = null;
  }

  void dispose() {
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    _routeController.close();
    _distanceController.close();
    _serviceStatusController.close();
    _accuracyController.close();
  }
}
