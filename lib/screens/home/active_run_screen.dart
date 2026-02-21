import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/run_tracking_service.dart';
import '../../services/database_service.dart';
import '../../services/territory_logic_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';

class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> {
  final RunTrackingService _trackingService = RunTrackingService();
  GoogleMapController? _mapController;

  List<LatLng> _route = [];
  double _distance = 0.0;
  int _secondsElapsed = 0;
  Timer? _timer;

  Set<Polyline> _polylines = {};
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _startRun();
  }

  void _startRun() async {
    // Get initial position for map center
    _currentPosition = await Geolocator.getCurrentPosition();
    if (mounted) setState(() {});

    _trackingService.startRun();

    // Listen to route updates
    _trackingService.routeStream.listen((route) {
      if (mounted) {
        setState(() {
          _route = route;
          _updatePolylines();
          _animateCameraToLatest();
        });
      }
    });

    // Listen to distance updates
    _trackingService.distanceStream.listen((distance) {
      if (mounted) {
        setState(() {
          _distance = distance;
        });
      }
    });

    // Start timer
    _resumeTimer();
  }

  void _resumeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
  }

  void _updatePolylines() {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('active_route'),
        color: AppTheme.primaryOrange,
        width: 6,
        points: _route,
      ),
    };
  }

  void _animateCameraToLatest() {
    if (_route.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_route.last),
      );
    }
  }

  void _togglePause() {
    setState(() {
      if (_trackingService.isRunning) {
        _trackingService.pauseRun();
        _pauseTimer();
      } else {
        _trackingService.resumeRun();
        _resumeTimer();
      }
    });
  }

  void _stopRun() async {
    _trackingService.stopRun();
    _pauseTimer();

    // Get the current user
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
    final String currentUserId = authNotifier.userToken ?? 'unknown_user';
    final String currentUserName =
        'Runner'; // You'd ideally fetch this from a user profile

    // 1. Calculate Territory
    final TerritoryLogicService territoryLogic = TerritoryLogicService();
    Territory? claimedTerritory;
    try {
      claimedTerritory = await territoryLogic.generateTerritoryFromRun(
        userId: currentUserId,
        userName: currentUserName,
        route: _route,
        distanceKm: _distance / 1000,
      );
    } catch (e) {
      debugPrint('Error claiming territory: $e');
    }

    // 2. Save Run History
    final DatabaseService db = DatabaseService();
    final RunHistory run = RunHistory(
      id: '', // db sets ID
      userId: currentUserId,
      distanceKm: _distance / 1000,
      timeSeconds: _secondsElapsed,
      date: DateTime.now(),
    );
    await db.saveRun(run);

    // 3. Post to Social Feed
    if (claimedTerritory != null) {
      final FeedPost post = FeedPost(
        id: '',
        userId: currentUserId,
        userName: currentUserName,
        avatarText: currentUserName.substring(0, 1).toUpperCase(),
        actionText:
            'claimed a territory spanning ${claimedTerritory.areaSqKm.toStringAsFixed(2)} km²!',
        distanceKm: _distance / 1000,
        timestamp: DateTime.now(),
      );
      await db.createFeedPost(post);
    } else {
      final FeedPost post = FeedPost(
        id: '',
        userId: currentUserId,
        userName: currentUserName,
        avatarText: currentUserName.substring(0, 1).toUpperCase(),
        actionText: 'completed a run in ${_formatTime(_secondsElapsed)}.',
        distanceKm: _distance / 1000,
        timestamp: DateTime.now(),
      );
      await db.createFeedPost(post);
    }

    if (!mounted) return;

    // Show summary dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Run Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${(_distance / 1000).toStringAsFixed(2)} km'),
            Text('Time: ${_formatTime(_secondsElapsed)}'),
            const SizedBox(height: 16),
            if (claimedTerritory != null)
              Text(
                  'Territory Claimed! (${claimedTerritory.areaSqKm.toStringAsFixed(2)} km²)',
                  style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold))
            else
              const Text('Run too short to claim territory.',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to dashboard
            },
            child: const Text('Return to Dashboard'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _calculatePace() {
    if (_distance == 0) return "0:00";
    double km = _distance / 1000;
    double minutes = _secondsElapsed / 60;
    double pace = minutes / km;

    int paceMinutes = pace.floor();
    int paceSeconds = ((pace - paceMinutes) * 60).round();

    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _trackingService.dispose();
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(37.7749, -122.4194),
              zoom: 17,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // Top Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    _trackingService.stopRun();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),

          // Bottom Stats Dashboard
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // distance
                  Text(
                    (_distance / 1000).toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'kilometers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Time', _formatTime(_secondsElapsed)),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildStatColumn('Pace', '${_calculatePace()} /km'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pause/Resume
                      InkWell(
                        onTap: _togglePause,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[200],
                          child: Icon(
                            _trackingService.isRunning
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 35,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // Stop
                      InkWell(
                        onTap: _stopRun,
                        child: const CircleAvatar(
                          radius: 35,
                          backgroundColor: AppTheme.errorRed,
                          child: Icon(
                            Icons.stop,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
