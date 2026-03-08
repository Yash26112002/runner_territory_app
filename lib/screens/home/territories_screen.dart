import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../utils/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TerritoriesScreen extends StatefulWidget {
  const TerritoriesScreen({super.key});

  @override
  State<TerritoriesScreen> createState() => _TerritoriesScreenState();
}

class _TerritoriesScreenState extends State<TerritoriesScreen>
    with SingleTickerProviderStateMixin {
  static final DatabaseService _db = DatabaseService();
  int _filterIndex = 0; // 0=All 1=Safe 2=Contested 3=At Risk 4=New
  String _sortBy = 'area'; // 'area' | 'date'
  bool _isGridView = false;
  late TabController _tabController;

  final List<String> _filters = ['All', 'Safe', 'Contested', 'At Risk', 'New'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filterIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Territory> _applyFilter(List<Territory> all) {
    final now = DateTime.now();
    switch (_filterIndex) {
      case 1: // Safe – held > 7 days and no contest marker (all without recent date = safe)
        return all
            .where((t) => now.difference(t.createdAt).inDays > 7)
            .toList();
      case 2: // Contested – mock: newly created < 1 day
        return all
            .where((t) => now.difference(t.createdAt).inHours < 24)
            .toList();
      case 3: // At Risk – mock: smallest territories
        final sorted = [...all]
          ..sort((a, b) => a.areaSqKm.compareTo(b.areaSqKm));
        return sorted.take((all.length / 3).ceil()).toList();
      case 4: // New – last 7 days
        return all
            .where((t) => now.difference(t.createdAt).inDays <= 7)
            .toList();
      default:
        return all;
    }
  }

  List<Territory> _applySort(List<Territory> list) {
    if (_sortBy == 'area') {
      return [...list]..sort((a, b) => b.areaSqKm.compareTo(a.areaSqKm));
    }
    return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _statusLabel(Territory t) {
    final ageDays = DateTime.now().difference(t.createdAt).inDays;
    if (ageDays <= 1) return 'Contested';
    if (ageDays <= 3) return 'At Risk';
    return 'Safe';
  }

  Color _statusColor(Territory t) {
    final label = _statusLabel(t);
    if (label == 'Safe') return AppTheme.successGreen;
    if (label == 'Contested') return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  double _healthScore(Territory t) {
    final ageDays = DateTime.now().difference(t.createdAt).inDays;
    final base = (ageDays / 30).clamp(0.0, 1.0);
    return 0.4 + base * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Provider.of<AuthNotifier>(context, listen: false).userToken;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: StreamBuilder<List<Territory>>(
        stream: _db.streamUserTerritories(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmer();
          }

          final allTerritories = snapshot.data ?? [];
          final filtered = _applySort(_applyFilter(allTerritories));
          final totalArea =
              allTerritories.fold<double>(0, (s, t) => s + t.areaSqKm);
          final activeCount =
              allTerritories.where((t) => _statusLabel(t) == 'Safe').length;
          final contestedCount = allTerritories
              .where((t) => _statusLabel(t) == 'Contested')
              .length;
          final atRiskCount =
              allTerritories.where((t) => _statusLabel(t) == 'At Risk').length;
          final newCount = allTerritories
              .where((t) => DateTime.now().difference(t.createdAt).inDays <= 7)
              .length;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(allTerritories.length, totalArea, activeCount),
              // Summary Cards Horizontal Row
              SliverToBoxAdapter(
                child: _buildSummaryCards(allTerritories, activeCount,
                    contestedCount, atRiskCount, newCount, totalArea),
              ),
              // Filter + Sort + View Toggle
              SliverToBoxAdapter(child: _buildFilterBar()),
              // Territory List / Grid
              if (filtered.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else if (_isGridView)
                _buildGridSliver(filtered)
              else
                _buildListSliver(filtered),
              // Analytics section (if data exists)
              if (allTerritories.length >= 2)
                SliverToBoxAdapter(child: _buildAnalyticsCard(allTerritories)),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  // ─── Sliver App Bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(int count, double totalArea, int activeCount) {
    final health = count == 0 ? 0.0 : (activeCount / count).clamp(0.0, 1.0);
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF0F0F1A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Empire',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          '${totalArea.toStringAsFixed(2)} km²',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text('$count territories owned',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  // Health Gauge
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: health,
                              strokeWidth: 6,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(
                                health > 0.6
                                    ? AppTheme.successGreen
                                    : health > 0.3
                                        ? AppTheme.warningYellow
                                        : AppTheme.errorRed,
                              ),
                            ),
                          ),
                          Text(
                            '${(health * 100).toInt()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Health',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: const Text('Territories',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  // ─── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards(List<Territory> all, int active, int contested,
      int atRisk, int newCount, double totalArea) {
    final cards = [
      {
        'label': 'Active',
        'value': '$active',
        'color': AppTheme.successGreen,
        'icon': Icons.shield
      },
      {
        'label': 'Contested',
        'value': '$contested',
        'color': AppTheme.warningYellow,
        'icon': Icons.whatshot
      },
      {
        'label': 'At Risk',
        'value': '$atRisk',
        'color': AppTheme.errorRed,
        'icon': Icons.warning
      },
      {
        'label': 'New (7d)',
        'value': '$newCount',
        'color': AppTheme.secondaryBlue,
        'icon': Icons.new_releases
      },
      {
        'label': 'km² Total',
        'value': totalArea.toStringAsFixed(1),
        'color': AppTheme.accentPurple,
        'icon': Icons.map
      },
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final c = cards[i];
          final color = c['color'] as Color;
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(c['icon'] as IconData, color: color, size: 20),
                const SizedBox(height: 4),
                Text(c['value'] as String,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(c['label'] as String,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Filter Bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.white38,
            indicatorColor: AppTheme.primaryOrange,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _filters.map((f) => Tab(text: f)).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Sort
                GestureDetector(
                  onTap: () {
                    setState(
                        () => _sortBy = _sortBy == 'area' ? 'date' : 'area');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, color: Colors.white54, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _sortBy == 'area' ? 'By Area' : 'By Date',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // View Toggle
                GestureDetector(
                  onTap: () => setState(() => _isGridView = !_isGridView),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isGridView ? Icons.list : Icons.grid_view,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── List Sliver ───────────────────────────────────────────────────────────

  Widget _buildListSliver(List<Territory> list) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _buildTerritoryListCard(context, list[i]),
        childCount: list.length,
      ),
    );
  }

  Widget _buildTerritoryListCard(BuildContext context, Territory t) {
    final status = _statusLabel(t);
    final color = _statusColor(t);
    final health = _healthScore(t);
    final ageDays = DateTime.now().difference(t.createdAt).inDays;

    return GestureDetector(
      onTap: () => _showTerritoryDetail(context, t),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.terrain, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Territory ${t.id.isNotEmpty ? t.id.substring(0, 6) : '??'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.crop_square,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text('${t.areaSqKm.toStringAsFixed(3)} km²',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(ageDays == 0 ? 'Today' : '${ageDays}d ago',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Health bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: health,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  // ─── Grid Sliver ───────────────────────────────────────────────────────────

  Widget _buildGridSliver(List<Territory> list) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _buildTerritoryGridCard(context, list[i]),
          childCount: list.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
      ),
    );
  }

  Widget _buildTerritoryGridCard(BuildContext context, Territory t) {
    final status = _statusLabel(t);
    final color = _statusColor(t);
    final health = _healthScore(t);

    return GestureDetector(
      onTap: () => _showTerritoryDetail(context, t),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.terrain, color: color, size: 28),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Spacer(),
            Text(
              t.areaSqKm.toStringAsFixed(3),
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text('km²',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: health,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Territory Detail Bottom Sheet ─────────────────────────────────────────

  void _showTerritoryDetail(BuildContext context, Territory t) {
    final status = _statusLabel(t);
    final color = _statusColor(t);
    final ageDays = DateTime.now().difference(t.createdAt).inDays;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.terrain, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Territory ${t.id.isNotEmpty ? t.id.substring(0, 6) : '??'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Text(status,
                            style: TextStyle(color: color, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Stats Grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  _detailStat('${t.areaSqKm.toStringAsFixed(3)} km²', 'Area',
                      AppTheme.secondaryBlue),
                  _detailStat(ageDays == 0 ? 'Today' : '${ageDays}d ago',
                      'Claimed', AppTheme.successGreen),
                  _detailStat('#1', 'Your Rank', AppTheme.primaryOrange),
                  _detailStat('0', 'Challengers', AppTheme.errorRed),
                  _detailStat(
                      _healthScore(t) >= 0.7
                          ? 'Strong'
                          : _healthScore(t) >= 0.4
                              ? 'OK'
                              : 'Weak',
                      'Defense',
                      color),
                  _detailStat(t.ownerName, 'Owner', AppTheme.accentPurple),
                ],
              ),
              const SizedBox(height: 20),
              // Mini map (if has polygon points)
              if (t.polygonPoints.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 150,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: t.polygonPoints[t.polygonPoints.length ~/ 2],
                        zoom: 15,
                      ),
                      polygons: {
                        Polygon(
                          polygonId: const PolygonId('detail'),
                          points: t.polygonPoints,
                          fillColor: color.withValues(alpha: 0.3),
                          strokeColor: color,
                          strokeWidth: 2,
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Strategic tip
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tips_and_updates,
                        color: AppTheme.primaryOrange, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Run through this territory to strengthen your defense!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Defend button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shield_outlined, color: Colors.white),
                  label: const Text('Battles & Defense',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppConstants.routeChallenges);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailStat(String value, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  // ─── Analytics Card ────────────────────────────────────────────────────────

  Widget _buildAnalyticsCard(List<Territory> territories) {
    // Build data: cumulative area over time
    final sorted = [...territories]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    double cumArea = 0;
    final spots = sorted.asMap().entries.map((e) {
      cumArea += e.value.areaSqKm;
      return FlSpot(e.key.toDouble(), cumArea);
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppTheme.primaryOrange, size: 20),
              SizedBox(width: 8),
              Text('Territory Growth',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style:
                            const TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryOrange,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${territories.length} territories • ${territories.fold(0.0, (s, t) => s + t.areaSqKm).toStringAsFixed(3)} km² total',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined,
                color: AppTheme.primaryOrange, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            _filterIndex == 0
                ? 'No territories yet'
                : 'No territories in this filter',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go for a run to start\nclaiming your territory!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── Shimmer Loading ───────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF2A2A3E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          height: 90,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
