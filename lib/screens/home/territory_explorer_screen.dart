import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../utils/constants.dart';

class TerritoryExplorerScreen extends StatefulWidget {
  const TerritoryExplorerScreen({super.key});

  @override
  State<TerritoryExplorerScreen> createState() =>
      _TerritoryExplorerScreenState();
}

class _TerritoryExplorerScreenState extends State<TerritoryExplorerScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _loadingLocation = true;

  // Layer filter: 0=All, 1=Mine, 2=Top100, 3=Heatmap
  int _selectedLayer = 0;
  final List<String> _layerLabels = ['All', 'Mine', 'Top 100', 'Heatmap'];

  Set<Polygon> _polygons = {};
  List<Territory> _allTerritories = [];
  List<Territory> _visibleTerritories = [];

  Territory? _selectedTerritory;
  bool _bottomPanelExpanded = false;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _panelController;

  String? _currentUserId;

  // Colors for different users
  final List<Color> _userColors = AppConstants.territoryColors;

  final Map<String, Color> _userColorMap = {};
  int _colorIndex = 0;

  Color _colorForUser(String userId, String currentUserId) {
    if (userId == currentUserId) return AppTheme.secondaryBlue;
    if (!_userColorMap.containsKey(userId)) {
      _userColorMap[userId] = _userColors[_colorIndex % _userColors.length];
      _colorIndex++;
    }
    return _userColorMap[userId]!;
  }

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _getLocation();
    _loadTerritories();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _loadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(pos.latitude, pos.longitude),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _loadTerritories() async {
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
    _currentUserId = authNotifier.userToken;

    try {
      final territories = await DatabaseService().getAllTerritories();
      if (mounted) {
        setState(() {
          _allTerritories = territories;
          _applyLayerFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading territories: $e');
    }
  }

  void _applyLayerFilter() {
    final uid = _currentUserId ?? '';
    List<Territory> filtered;
    switch (_selectedLayer) {
      case 1: // Mine only
        filtered = _allTerritories.where((t) => t.ownerId == uid).toList();
        break;
      case 2: // Top 100 by area
        final sorted = [..._allTerritories]
          ..sort((a, b) => b.areaSqKm.compareTo(a.areaSqKm));
        filtered = sorted.take(100).toList();
        break;
      default:
        filtered = _allTerritories;
    }

    _visibleTerritories = filtered;
    _buildPolygons();
  }

  void _buildPolygons() {
    final uid = _currentUserId ?? '';
    final newPolygons = <Polygon>{};

    for (final t in _visibleTerritories) {
      if (t.polygonPoints.length < 3) continue;
      final color = _colorForUser(t.ownerId, uid);
      newPolygons.add(Polygon(
        polygonId: PolygonId(t.id),
        points: t.polygonPoints,
        fillColor: color.withValues(alpha: 0.3),
        strokeColor: color,
        strokeWidth: 2,
        consumeTapEvents: true,
        onTap: () {
          setState(() {
            _selectedTerritory = t;
            _bottomPanelExpanded = false;
          });
        },
      ));
    }

    setState(() => _polygons = newPolygons);
  }

  void _centerOnMe() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _centerOnMyTerritories() {
    final uid = _currentUserId ?? '';
    final mine = _allTerritories.where((t) => t.ownerId == uid).toList();
    if (mine.isEmpty || _mapController == null) return;

    // Build bounds
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final t in mine) {
      for (final p in t.polygonPoints) {
        minLat = minLat < p.latitude ? minLat : p.latitude;
        maxLat = maxLat > p.latitude ? maxLat : p.latitude;
        minLng = minLng < p.longitude ? minLng : p.longitude;
        maxLng = maxLng > p.longitude ? maxLng : p.longitude;
      }
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full screen dark map ─────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(20.0, 0.0),
              zoom: _currentPosition != null ? 14 : 2,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polygons: _polygons,
            style: _explorerMapStyle,
            onMapCreated: (c) {
              _mapController = c;
              if (_currentPosition != null) {
                c.animateCamera(CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    14));
              }
            },
            onTap: (_) {
              setState(() => _selectedTerritory = null);
            },
            onCameraIdle: () {
              // Could trigger viewport-based reload here
            },
          ),

          // ── Search bar ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search locations, users…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white38),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white38),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Layer selector
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _layerLabels.length,
                      itemBuilder: (_, i) {
                        final selected = _selectedLayer == i;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedLayer = i);
                            _applyLayerFilter();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryOrange
                                  : const Color(0xFF1A1A2E)
                                      .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryOrange
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              _layerLabels[i],
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Territory info card (on tap) ─────────────────────────────────
          if (_selectedTerritory != null)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: _buildTerritoryInfoCard(_selectedTerritory!),
            ),

          // ── FABs (right side) ────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _fab(Icons.my_location, _centerOnMe, tooltip: 'My Location'),
                const SizedBox(height: 10),
                _fab(Icons.center_focus_strong, _centerOnMyTerritories,
                    tooltip: 'My Territories'),
                const SizedBox(height: 10),
                _fab(Icons.refresh, _loadTerritories, tooltip: 'Refresh'),
              ],
            ),
          ),

          // ── Bottom slide-up panel ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                if (d.primaryVelocity! < 0) {
                  setState(() => _bottomPanelExpanded = true);
                } else if (d.primaryVelocity! > 0) {
                  setState(() => _bottomPanelExpanded = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _bottomPanelExpanded ? 320 : 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle + quick stats
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Column(
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_visibleTerritories.length} territories visible',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  Text(
                                    _layerLabels[_selectedLayer],
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _bottomPanelExpanded =
                                        !_bottomPanelExpanded),
                                child: Icon(
                                  _bottomPanelExpanded
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Expanded content
                    if (_bottomPanelExpanded)
                      Expanded(
                        child: _buildExpandedPanelContent(),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_loadingLocation)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryOrange),
                    SizedBox(height: 12),
                    Text('Locating you…',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Territory Info Card ───────────────────────────────────────────────────

  Widget _buildTerritoryInfoCard(Territory t) {
    final isMe = t.ownerId == _currentUserId;
    final color = _colorForUser(t.ownerId, _currentUserId ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    t.ownerName.isNotEmpty ? t.ownerName[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? 'Your Territory' : '${t.ownerName}\'s Territory',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      '${t.areaSqKm.toStringAsFixed(3)} km²',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedTerritory = null),
                child: const Icon(Icons.close, color: Colors.white38, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _selectedTerritory = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isMe
                            ? 'Run here to defend your territory!'
                            : 'Run here to challenge this territory!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isMe ? 'Defend' : 'Challenge',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to territory details – for MVP show snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Navigating to territory…'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Details',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Expanded Panel Content ────────────────────────────────────────────────

  Widget _buildExpandedPanelContent() {
    final uid = _currentUserId ?? '';
    final mine = _visibleTerritories.where((t) => t.ownerId == uid).toList();

    // Top players
    final Map<String, double> playerArea = {};
    for (final t in _visibleTerritories) {
      playerArea[t.ownerName] = (playerArea[t.ownerName] ?? 0) + t.areaSqKm;
    }
    final topPlayers = playerArea.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My territories in view
          if (mine.isNotEmpty) ...[
            const Text('Your Territories in View',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            ...mine
                .take(3)
                .map((t) => _miniTerritoryRow(t, AppTheme.secondaryBlue)),
            const SizedBox(height: 16),
          ],

          // Top players
          if (topPlayers.isNotEmpty) ...[
            const Text('Top Players in View',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            ...topPlayers.take(3).map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppTheme.accentPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(e.key,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    const Spacer(),
                    Text('${e.value.toStringAsFixed(2)} km²',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _miniTerritoryRow(Territory t, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.terrain, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            t.id.isNotEmpty ? 'Territory ${t.id.substring(0, 6)}' : 'territory',
            style: TextStyle(color: color, fontSize: 12),
          ),
          const Spacer(),
          Text('${t.areaSqKm.toStringAsFixed(3)} km²',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────

  Widget _fab(IconData icon, VoidCallback onPressed, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }

  // ─── Dark Explorer Map Style ───────────────────────────────────────────────

  static const String _explorerMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0c0c1a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b737a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0c0c1a"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1e1e2e"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#16213e"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#1a1a2e"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#060d16"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';
}
