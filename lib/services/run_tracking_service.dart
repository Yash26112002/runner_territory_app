import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunTrackingService {
  StreamSubscription<Position>? _positionStream;
  final List<LatLng> _routePoints = [];
  double _totalDistanceMeters = 0.0;
  bool _isRunning = false;

  final StreamController<List<LatLng>> _routeController =
      StreamController<List<LatLng>>.broadcast();
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();

  Stream<List<LatLng>> get routeStream => _routeController.stream;
  Stream<double> get distanceStream => _distanceController.stream;

  bool get isRunning => _isRunning;

  void startRun() {
    _isRunning = true;
    _routePoints.clear();
    _totalDistanceMeters = 0.0;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Update every 3 meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
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
    _positionStream = null;
  }

  void dispose() {
    _positionStream?.cancel();
    _routeController.close();
    _distanceController.close();
  }
}
