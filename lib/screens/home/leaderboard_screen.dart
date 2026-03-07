import 'package:flutter/material.dart';
import '../../widgets/shimmer_loading.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_notifier.dart';

enum _SortField { distance, area, territories }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late final TabController _tabController;
  _SortField _sortField = _SortField.distance;
  UserProfile? _myProfile;
  String? _myUid;

  static const _tabs = [
    ('Global', Icons.public),
    ('National', Icons.flag_outlined),
    ('Regional', Icons.terrain),
    ('Local', Icons.location_on_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _myUid = Provider.of<AuthNotifier>(context, listen: false).userToken;
      if (_myUid != null) {
        _db.getUser(_myUid!).then((profile) {
          if (mounted) setState(() => _myProfile = profile);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Filtering & Sorting ───────────────────────────────────────────────────

  List<UserProfile> _applyGeoFilter(List<UserProfile> all, int tabIndex) {
    switch (tabIndex) {
      case 1: // National
        final country = _myProfile?.country ?? '';
        if (country.isEmpty) return [];
        return all.where((u) => u.country == country).toList();
      case 2: // Regional
        final state = _myProfile?.state ?? '';
        final country = _myProfile?.country ?? '';
        if (state.isEmpty) return [];
        return all
            .where((u) => u.state == state && u.country == country)
            .toList();
      case 3: // Local
        final city = _myProfile?.city ?? '';
        if (city.isEmpty) return [];
        return all.where((u) => u.city == city).toList();
      default:
        return List.from(all);
    }
  }

  List<UserProfile> _applySortField(List<UserProfile> runners) {
    final sorted = List<UserProfile>.from(runners);
    switch (_sortField) {
      case _SortField.area:
        sorted.sort((a, b) => b.totalAreaSqKm.compareTo(a.totalAreaSqKm));
      case _SortField.territories:
        sorted.sort((a, b) => b.territoriesOwned.compareTo(a.territoriesOwned));
      case _SortField.distance:
        sorted.sort((a, b) => b.totalDistance.compareTo(a.totalDistance));
    }
    return sorted;
  }

  bool _hasLocationForTab(int tabIndex) {
    if (_myProfile == null) return false;
    return switch (tabIndex) {
      1 => _myProfile!.country.isNotEmpty,
      2 => _myProfile!.state.isNotEmpty,
      3 => _myProfile!.city.isNotEmpty,
      _ => true,
    };
  }

  String _sortLabel() => switch (_sortField) {
        _SortField.area => 'Territory Area',
        _SortField.territories => 'Territory Count',
        _SortField.distance => 'Distance',
      };

  String _runnerValue(UserProfile runner) => switch (_sortField) {
        _SortField.area =>
          '${runner.totalAreaSqKm.toStringAsFixed(2)} km²',
        _SortField.territories => '${runner.territoriesOwned} zones',
        _SortField.distance =>
          '${runner.totalDistance.toStringAsFixed(1)} km',
      };

  // ─── Bottom Sheets ─────────────────────────────────────────────────────────

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              const SizedBox(height: 20),
              const Text(
                'Sort Rankings By',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...[
                (_SortField.distance, Icons.directions_run, 'Distance',
                  'Total kilometres run'),
                (_SortField.area, Icons.map_outlined, 'Territory Area',
                  'Total km² claimed'),
                (_SortField.territories, Icons.flag_outlined,
                  'Territory Count', 'Number of zones owned'),
              ].map((item) =>
                  _sortOptionTile(item.$1, item.$2, item.$3, item.$4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortOptionTile(
      _SortField field, IconData icon, String label, String subtitle) {
    final selected = _sortField == field;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryOrange.withValues(alpha: 0.12)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: selected ? AppTheme.primaryOrange : Colors.grey[500],
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppTheme.primaryOrange : Colors.black87,
        ),
      ),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.primaryOrange)
          : Icon(Icons.radio_button_unchecked, color: Colors.grey[300]),
      onTap: () {
        setState(() => _sortField = field);
        Navigator.pop(context);
      },
    );
  }

  void _showProfilePreview(UserProfile runner, int rank) {
    final isMe = runner.uid == _myUid;
    final avatarText = runner.displayName.isNotEmpty
        ? runner.displayName[0].toUpperCase()
        : '?';
    final location = [runner.city, runner.country]
        .where((s) => s.isNotEmpty)
        .join(', ');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Avatar with rank badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: isMe
                      ? AppTheme.primaryOrange
                      : Colors.grey[200],
                  child: Text(
                    avatarText,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _rankColor(rank),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name + "You" badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  runner.displayName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('You',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ],
            ),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(location,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Stats row
            Row(
              children: [
                _previewStatCard(
                  runner.totalDistance.toStringAsFixed(1),
                  'km run',
                  Icons.directions_run,
                  AppTheme.secondaryBlue,
                ),
                const SizedBox(width: 10),
                _previewStatCard(
                  '${runner.territoriesOwned}',
                  'zones',
                  Icons.flag_outlined,
                  AppTheme.primaryOrange,
                ),
                const SizedBox(width: 10),
                _previewStatCard(
                  runner.totalAreaSqKm.toStringAsFixed(1),
                  'km²',
                  Icons.map_outlined,
                  AppTheme.accentPurple,
                ),
                const SizedBox(width: 10),
                _previewStatCard(
                  '${runner.runningStreak}',
                  'day streak',
                  Icons.local_fire_department,
                  AppTheme.errorRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewStatCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppTheme.primaryOrange;
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.tune, size: 18),
            label: Text(_sortLabel()),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.primaryOrange),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.$2, size: 18), text: t.$1))
              .toList(),
        ),
      ),
      body: StreamBuilder<List<UserProfile>>(
        stream: _db.streamLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LeaderboardShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Error loading leaderboard',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          final allRunners = snapshot.data ?? [];
          return TabBarView(
            controller: _tabController,
            children: List.generate(
              _tabs.length,
              (tabIndex) => _buildTabBody(allRunners, tabIndex),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBody(List<UserProfile> allRunners, int tabIndex) {
    // Show spinner while profile loads for geo tabs
    if (tabIndex > 0 && _myProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show location prompt if user hasn't set location
    if (tabIndex > 0 && !_hasLocationForTab(tabIndex)) {
      final scopeLabel = ['', 'country', 'state/region', 'city'][tabIndex];
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 72, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'Location not set',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your $scopeLabel in your profile\nto see local rankings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Update Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _applyGeoFilter(allRunners, tabIndex);
    final runners = _applySortField(filtered);

    if (runners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No runners here yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            Text('Be the first to claim this territory!',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    final myRank = runners.indexWhere((r) => r.uid == _myUid) + 1;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Info bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.leaderboard, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${runners.length} runners · ${_sortLabel()}',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    if (myRank > 0) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primaryOrange
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Your rank: #$myRank',
                          style: const TextStyle(
                            color: AppTheme.primaryOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Podium (top 3)
            SliverToBoxAdapter(child: _buildPodium(runners)),

            const SliverToBoxAdapter(child: Divider(height: 1)),

            // Ranks 4+
            SliverPadding(
              padding: EdgeInsets.only(
                  top: 8, bottom: myRank > 3 ? 110 : 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final rank = index + 4;
                    final runner = runners[index + 3];
                    return _buildLeaderboardTile(runner, rank);
                  },
                  childCount:
                      runners.length > 3 ? runners.length - 3 : 0,
                ),
              ),
            ),
          ],
        ),

        // Sticky "Your Rank" card (only when user is rank 4+)
        if (myRank > 3)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyMyRankCard(runners[myRank - 1], myRank),
          ),
      ],
    );
  }

  // ─── Podium ────────────────────────────────────────────────────────────────

  Widget _buildPodium(List<UserProfile> runners) {
    if (runners.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (runners.length > 1)
            _podiumSpot(runners[1], 2, 88, Colors.grey.shade400),
          _podiumSpot(runners[0], 1, 120, const Color(0xFFFFD700)),
          if (runners.length > 2)
            _podiumSpot(runners[2], 3, 68, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _podiumSpot(
      UserProfile runner, int rank, double height, Color color) {
    final avatarText = runner.displayName.isNotEmpty
        ? runner.displayName[0].toUpperCase()
        : '?';
    final firstName = runner.displayName.split(' ').first;
    final isMe = runner.uid == _myUid;

    return GestureDetector(
      onTap: () => _showProfilePreview(runner, rank),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: rank == 1 ? 32 : 26,
                backgroundColor:
                    isMe ? AppTheme.primaryOrange : color.withValues(alpha: 0.15),
                child: Text(
                  avatarText,
                  style: TextStyle(
                    color: isMe ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: rank == 1 ? 22 : 18,
                  ),
                ),
              ),
              if (rank == 1)
                const Positioned(
                  top: -16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('👑', style: TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            firstName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: rank == 1 ? 14 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _runnerValue(runner),
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(height: 8),
          Container(
            width: rank == 1 ? 72 : 60,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Rank List Tile ────────────────────────────────────────────────────────

  Widget _buildLeaderboardTile(UserProfile runner, int rank) {
    final isMe = runner.uid == _myUid;
    final avatarText = runner.displayName.isNotEmpty
        ? runner.displayName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => _showProfilePreview(runner, rank),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryOrange.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isMe
              ? Border.all(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.4))
              : null,
          boxShadow: isMe
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isMe ? AppTheme.primaryOrange : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    isMe ? AppTheme.primaryOrange : Colors.grey[100],
                child: Text(
                  avatarText,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  runner.displayName,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                    color: isMe ? AppTheme.primaryOrange : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('You',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ],
          ),
          subtitle: runner.city.isNotEmpty
              ? Text(runner.city,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12))
              : null,
          trailing: Text(
            _runnerValue(runner),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isMe ? AppTheme.primaryOrange : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sticky My Rank Card ───────────────────────────────────────────────────

  Widget _buildStickyMyRankCard(UserProfile me, int rank) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              me.displayName.isNotEmpty
                  ? me.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  me.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _runnerValue(me),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Text(
                'Your rank',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
