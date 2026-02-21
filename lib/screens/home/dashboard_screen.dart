import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/stats_widget.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import 'territories_screen.dart';
import 'leaderboard_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';
import 'active_run_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  int _currentNavIndex = 0;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  MapType _currentMapType = MapType.normal;
  final DatabaseService _db = DatabaseService();

  // Mock data
  final double _territoryOwned = 12.5;
  final int _currentRank = 42;
  final int _runningStreak = 7;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() {
        _isLoadingLocation = false;
      });
      _showPermissionDialog();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to track your runs and show territories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _centerOnUserLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _showTerritoryDetails(Territory territory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Territory Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Owner', territory.ownerName),
            _buildDetailRow(
                'Area', '${territory.areaSqKm.toStringAsFixed(2)} km²'),
            _buildDetailRow('Claimed At',
                '${territory.createdAt.day}/${territory.createdAt.month}/${territory.createdAt.year}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Go run to claim this!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget mapBody = Stack(
      children: [
        // Google Map
        _isLoadingLocation
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<Territory>>(
                stream: _db.streamGlobalTerritories(),
                builder: (context, snapshot) {
                  Set<Polygon> polygons = {};
                  final currentUserId =
                      Provider.of<AuthNotifier>(context, listen: false)
                          .userToken;

                  if (snapshot.hasData) {
                    for (var territory in snapshot.data!) {
                      bool isMine = territory.ownerId == currentUserId;
                      polygons.add(
                        Polygon(
                          polygonId: PolygonId(territory.id),
                          points: territory.polygonPoints,
                          fillColor: isMine
                              ? AppTheme.primaryOrange.withValues(
                                  alpha: AppConstants.territoryOpacity)
                              : AppTheme.secondaryBlue.withValues(
                                  alpha: AppConstants.territoryOpacity),
                          strokeColor: isMine
                              ? AppTheme.primaryOrange
                              : AppTheme.secondaryBlue,
                          strokeWidth: 2,
                          onTap: () => _showTerritoryDetails(territory),
                          consumeTapEvents: true,
                        ),
                      );
                    }
                  }

                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            )
                          : const LatLng(
                              37.7749, -122.4194), // Default: San Francisco
                      zoom: AppConstants.defaultMapZoom,
                    ),
                    mapType: _currentMapType,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    polygons: polygons,
                  );
                }),

        // Top Overlay: Search Bar & Stats Widget
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search location...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey[600]),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Search feature coming soon!'),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Stats Widget
                StatsWidget(
                  territoryOwned: _territoryOwned,
                  currentRank: _currentRank,
                  runningStreak: _runningStreak,
                ),
              ],
            ),
          ),
        ),

        // Map Controls
        Positioned(
          right: 16,
          bottom: 180,
          child: Column(
            children: [
              // Center on location
              FloatingActionButton(
                heroTag: 'center',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _centerOnUserLocation,
                child: const Icon(
                  Icons.my_location,
                  color: AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(height: 8),
              // Toggle map type
              FloatingActionButton(
                heroTag: 'mapType',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: _toggleMapType,
                child: Icon(
                  _currentMapType == MapType.normal
                      ? Icons.satellite
                      : Icons.map,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ],
          ),
        ),

        // Start Run Button
        Positioned(
          bottom: 100,
          right: 16,
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.1).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveRunScreen(),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryOrange,
              icon: const Icon(Icons.directions_run),
              label: const Text(
                'Start Run',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          mapBody,
          const TerritoriesScreen(),
          const LeaderboardScreen(),
          const SocialScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }
}
