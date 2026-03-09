import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/run_tracking_service.dart';
import '../../services/database_service.dart';
import '../../services/territory_logic_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/sound_service.dart';
import '../../utils/constants.dart';

class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen>
    with TickerProviderStateMixin {
  final RunTrackingService _trackingService = RunTrackingService();
  final SoundService _soundService = SoundService();
  GoogleMapController? _mapController;

  // Stream subscriptions stored so they can be cancelled on dispose
  StreamSubscription<List<LatLng>>? _routeSub;
  StreamSubscription<double>? _distanceSub;
  StreamSubscription<ServiceStatus>? _statusSub;
  StreamSubscription<double>? _accuracySub;

  List<LatLng> _route = [];
  double _distance = 0.0;
  int _secondsElapsed = 0;
  int _pauseSeconds = 0;
  Timer? _timer;
  Timer? _pauseTimer;
  bool _isScreenLocked = false;
  bool _audioEnabled = true;
  bool _isPaused = false;

  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};
  Position? _currentPosition;
  int _gpsAccuracy = 0; // in meters — updated live from position stream
  final double _maxSpeed = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // GPS indicator colours
  Color get _gpsColor {
    if (_gpsAccuracy <= 10) return AppTheme.successGreen;
    if (_gpsAccuracy <= 30) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    
    // Read user settings
    final settings = Provider.of<SettingsNotifier>(context, listen: false).settings;
    _audioEnabled = settings.audioCuesEnabled;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRun();
  }

  void _startRun() async {
    final settings = Provider.of<SettingsNotifier>(context, listen: false).settings;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: settings.highAccuracyGps ? LocationAccuracy.high : LocationAccuracy.medium,
    );
    if (mounted) setState(() {});

    if (_audioEnabled) _soundService.playStartWhistle();
    _trackingService.startRun(highAccuracy: settings.highAccuracyGps);

    _routeSub = _trackingService.routeStream.listen((route) {
      if (mounted) {
        setState(() {
          _route = route;
          _updatePolylines();
          _updateTerritoryPreview();
          _animateCameraToLatest();
        });
      }
    });

    _distanceSub = _trackingService.distanceStream.listen((distance) {
      if (mounted) {
        setState(() {
          _distance = distance;
          // Km milestones (audio)
          final int kmNow = (distance / 1000).floor();
          if (kmNow > 0 && distance % 1000 < 5 && _audioEnabled) {
            _soundService.playCheer();
          }
        });
      }
    });

    _statusSub = _trackingService.serviceStatusStream.listen((status) {
      if (status == ServiceStatus.disabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.gps_off, color: Colors.white),
              SizedBox(width: 8),
              Text('GPS Signal Lost! Reconnecting…'),
            ]),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _accuracySub = _trackingService.accuracyStream.listen((accuracy) {
      if (mounted) {
        setState(() {
          _gpsAccuracy = accuracy.round();
        });
      }
    });

    _resumeTimer();
  }

  void _resumeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _cancelRunTimer() => _timer?.cancel();

  void _updatePolylines() {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('active_route'),
        color: const Color(0xFF00E5FF),
        width: 6,
        points: _route,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ),
    };
  }

  void _updateTerritoryPreview() {
    if (_route.length < 3) {
      _polygons = {};
      return;
    }
    _polygons = {
      Polygon(
        polygonId: const PolygonId('territory_preview'),
        points: _route,
        fillColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
        strokeColor: AppTheme.primaryOrange.withValues(alpha: 0.7),
        strokeWidth: 2,
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
      _isPaused = !_isPaused;
      if (_isPaused) {
        _trackingService.pauseRun();
        _cancelRunTimer();
        _pulseController.stop();
        _pauseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _pauseSeconds++);
        });
      } else {
        _trackingService.resumeRun();
        _resumeTimer();
        _pulseController.repeat(reverse: true);
        _pauseTimer?.cancel();
      }
    });
  }

  void _confirmStop() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('End Run?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Your run will be saved and territories will be calculated.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _stopRun();
            },
            child:
                const Text('Stop Run', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _stopRun() async {
    _trackingService.stopRun();
    _cancelRunTimer();
    _pauseTimer?.cancel();
    WakelockPlus.disable();

    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
    final String currentUserId = authNotifier.userToken ?? 'unknown_user';
    final UserProfile? user = await DatabaseService().getUser(currentUserId);
    final String currentUserName = user?.displayName ?? 'Runner';

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

    final DatabaseService db = DatabaseService();
    final RunHistory run = RunHistory(
      id: '',
      userId: currentUserId,
      distanceKm: _distance / 1000,
      timeSeconds: _secondsElapsed,
      date: DateTime.now(),
    );
    await db.saveRun(run);

    if (claimedTerritory != null) {
      _soundService.playCheer();
      final FeedPost post = FeedPost(
        id: '',
        userId: currentUserId,
        userName: currentUserName,
        avatarText: currentUserName.isNotEmpty
                ? currentUserName.substring(0, 1).toUpperCase()
                : 'R',
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
        avatarText: currentUserName.isNotEmpty
                ? currentUserName.substring(0, 1).toUpperCase()
                : 'R',
        actionText: 'completed a run in ${_formatTime(_secondsElapsed)}.',
        distanceKm: _distance / 1000,
        timestamp: DateTime.now(),
      );
      await db.createFeedPost(post);
    }

    if (!mounted) return;

    // Navigate to run summary screen
    Navigator.pushReplacementNamed(
      context,
      AppConstants.routeRunSummary,
      arguments: {
        'distanceKm': _distance / 1000,
        'timeSeconds': _secondsElapsed,
        'route': _route,
        'claimedTerritory': claimedTerritory,
        'maxSpeedKph': _maxSpeed,
        'userId': currentUserId,
        'userName': currentUserName,
      },
    );
  }

  // ─── Formatters ────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _calculatePace() {
    if (_distance < 10) return '--:--';
    final km = _distance / 1000;
    final minutes = _secondsElapsed / 60;
    final pace = minutes / km;
    final pm = pace.floor();
    final ps = ((pace - pm) * 60).round();
    return '$pm:${ps.toString().padLeft(2, '0')}';
  }

  double _calculateCalories() => (_distance / 1000) * 62; // ~62 kcal/km average
  double _calculateArea() {
    if (_route.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < _route.length; i++) {
      final j = (i + 1) % _route.length;
      area += _route[i].longitude * _route[j].latitude;
      area -= _route[j].longitude * _route[i].latitude;
    }
    return (area.abs() / 2) * 111319 * 111319 / 1e6; // approx km²
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _distanceSub?.cancel();
    _statusSub?.cancel();
    _accuracySub?.cancel();
    _trackingService.dispose();
    _timer?.cancel();
    _pauseTimer?.cancel();
    _mapController?.dispose();
    _pulseController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // ── Map (full screen) ───────────────────────────────────────────
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
              mapType: MapType.normal,
              polylines: _polylines,
              polygons: _polygons,
              onMapCreated: (c) => _mapController = c,
              style: _darkMapStyle,
            ),

            // ── Dark gradient overlay at bottom for readability ─────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 340,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── Top bar ────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back
                    _glassButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () {
                        _timer?.cancel();
                        _pauseTimer?.cancel();
                        _trackingService.stopRun();
                        WakelockPlus.disable();
                        Navigator.pop(context);
                      },
                    ),
                    // GPS indicator
                    _buildGpsIndicator(),
                    // Lock
                    _glassButton(
                      icon: _isScreenLocked ? Icons.lock : Icons.lock_open,
                      onTap: () =>
                          setState(() => _isScreenLocked = !_isScreenLocked),
                    ),
                  ],
                ),
              ),
            ),

            // ── Top Stats Glassmorphism Card ────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: _buildStatsCard(),
            ),

            // ── Bottom Controls ─────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // ── Lock overlay ─────────────────────────────────────────────────
            if (_isScreenLocked)
              GestureDetector(
                onLongPress: () => setState(() => _isScreenLocked = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.01),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.white54, size: 40),
                        SizedBox(height: 8),
                        Text('Screen Locked\nLong press to unlock',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _glassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gpsColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _gpsColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _gpsAccuracy <= 10
                ? 'GPS Strong'
                : _gpsAccuracy <= 30
                    ? 'GPS OK'
                    : 'GPS Weak',
            style: TextStyle(
                color: _gpsColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Duration – biggest
          ScaleTransition(
            scale:
                _isPaused ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
            child: Text(
              _formatTime(_secondsElapsed),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isPaused ? 'PAUSED – ${_formatTime(_pauseSeconds)}' : 'DURATION',
            style: TextStyle(
              color: _isPaused ? AppTheme.warningYellow : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCell(
                (_distance / 1000).toStringAsFixed(2),
                'km',
                AppTheme.secondaryBlue,
              ),
              _vDivider(),
              _statCell(_calculatePace(), '/km pace', AppTheme.successGreen),
              _vDivider(),
              _statCell(
                _calculateCalories().toStringAsFixed(0),
                'kcal',
                AppTheme.warningYellow,
              ),
              _vDivider(),
              _statCell(
                _calculateArea().toStringAsFixed(3),
                'km² area',
                AppTheme.primaryOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: accent, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white12);

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Audio toggle
          _controlButton(
            icon: _audioEnabled ? Icons.volume_up : Icons.volume_off,
            label: 'Audio',
            color: Colors.white38,
            size: 50,
            onTap: () => setState(() => _audioEnabled = !_audioEnabled),
          ),

          // Pause / Resume (center, large)
          GestureDetector(
            onTap: _isScreenLocked ? null : _togglePause,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isPaused
                      ? [AppTheme.successGreen, const Color(0xFF1ABC9C)]
                      : [AppTheme.primaryOrange, AppTheme.primaryRed],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isPaused
                            ? AppTheme.successGreen
                            : AppTheme.primaryOrange)
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),

          // Stop (only visible when paused)
          AnimatedOpacity(
            opacity: _isPaused ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 300),
            child: _controlButton(
              icon: Icons.stop,
              label: 'Stop',
              color: AppTheme.errorRed,
              size: 50,
              onTap: _isPaused ? _confirmStop : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required double size,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border:
                  Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Dark map style ────────────────────────────────────────────────────────
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.province","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"poi","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#6f9ba5"}]},
  {"featureType":"poi","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3C7680"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
  {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023747"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"transit","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit.line","elementType":"geometry.fill","stylers":[{"color":"#283d6a"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';
}
