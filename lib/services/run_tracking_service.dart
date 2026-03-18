import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/network_log_entry.dart';
import 'network_log_store.dart';

class RunTrackingService {
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  final List<LatLng> _routePoints = [];
  double _totalDistanceMeters = 0.0;
  bool _isRunning = false;
  DateTime? _lastUpdateTime;
  final NetworkLogStore _logStore = NetworkLogStore();
  int _logCounter = 0;

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

  void startRun({bool highAccuracy = true}) {
    _isRunning = true;
    _routePoints.clear();
    _totalDistanceMeters = 0.0;
    _lastUpdateTime = null;

    final LocationSettings locationSettings = LocationSettings(
      accuracy: highAccuracy ? LocationAccuracy.bestForNavigation : LocationAccuracy.high,
      distanceFilter: 5, // Only fire after 5m movement
    );

    // Listen for Service Status (GPS toggled on/off)
    _serviceStatusStream =
        Geolocator.getServiceStatusStream().listen((status) {
      _serviceStatusController.add(status);
    });

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      // Time-based throttle: skip if < 3 seconds since last accepted update
      final now = DateTime.now();
      if (_lastUpdateTime != null &&
          now.difference(_lastUpdateTime!).inSeconds < 3) {
        return; // Too soon — skip this update
      }
      _lastUpdateTime = now;

      // Emit GPS accuracy so the UI can reflect signal quality
      _accuracyController.add(position.accuracy);

      final newPoint = LatLng(position.latitude, position.longitude);
      double segmentDistance = 0;

      if (_routePoints.isNotEmpty) {
        final lastPoint = _routePoints.last;
        segmentDistance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        _totalDistanceMeters += segmentDistance;
      }

      _routePoints.add(newPoint);

      // Log this position update
      final entry = NetworkLogEntry(
        id: 'gps_${now.millisecondsSinceEpoch}_${_logCounter++}',
        method: 'STREAM',
        path: 'geolocator/positionStream',
        operation: 'locationUpdate',
        requestData: {
          'distanceFilter': '5m',
          'timeThrottle': '3s',
          'point': _routePoints.length,
        },
        timestamp: now,
      );
      entry.complete(
        durationMs: 0,
        responseData: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'segmentDistance': '${segmentDistance.toStringAsFixed(1)}m',
          'totalDistance': '${(_totalDistanceMeters / 1000).toStringAsFixed(3)}km',
        },
      );
      _logStore.addLog(entry);

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
