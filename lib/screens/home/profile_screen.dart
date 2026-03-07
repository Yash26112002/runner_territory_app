import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_notifier.dart';
import '../../utils/constants.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';

// ─── Achievement model (private to this file) ─────────────────────────────────

class _Achievement {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _Achievement({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unlocked,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _db = DatabaseService();
  List<RunHistory>? _userRuns;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid =
          Provider.of<AuthNotifier>(context, listen: false).userToken;
      if (uid != null) {
        _db.getUserRuns(uid).then((runs) {
          if (mounted) setState(() => _userRuns = runs);
        });
      }
    });
  }

  // ─── Computed data ──────────────────────────────────────────────────────────

  List<_Achievement> _achievements(UserProfile user) => [
        _Achievement(
          title: 'First Steps',
          subtitle: 'Complete 1 run',
          icon: Icons.directions_run,
          color: AppTheme.successGreen,
          unlocked: user.totalRuns >= 1,
        ),
        _Achievement(
          title: 'Territory Rookie',
          subtitle: 'Claim 1 zone',
          icon: Icons.flag,
          color: AppTheme.primaryOrange,
          unlocked: user.territoriesOwned >= 1,
        ),
        _Achievement(
          title: 'Week Warrior',
          subtitle: '7-day streak',
          icon: Icons.local_fire_department,
          color: AppTheme.errorRed,
          unlocked: user.runningStreak >= 7,
        ),
        _Achievement(
          title: 'Speedster',
          subtitle: 'Run 10 km total',
          icon: Icons.flash_on,
          color: AppTheme.warningYellow,
          unlocked: user.totalDistance >= 10,
        ),
        _Achievement(
          title: 'Half Marathoner',
          subtitle: 'Run 21.1 km total',
          icon: Icons.emoji_events,
          color: Colors.grey.shade500,
          unlocked: user.totalDistance >= 21.1,
        ),
        _Achievement(
          title: 'Marathoner',
          subtitle: 'Run 42.2 km total',
          icon: Icons.military_tech,
          color: const Color(0xFFFFD700),
          unlocked: user.totalDistance >= 42.2,
        ),
        _Achievement(
          title: 'Land Baron',
          subtitle: 'Own 5 territories',
          icon: Icons.domain,
          color: AppTheme.accentPurple,
          unlocked: user.territoriesOwned >= 5,
        ),
        _Achievement(
          title: 'Big Landowner',
          subtitle: 'Claim 1 km² total',
          icon: Icons.map,
          color: AppTheme.secondaryBlue,
          unlocked: user.totalAreaSqKm >= 1,
        ),
      ];

  Map<String, String> _personalRecords() {
    final runs = _userRuns;
    if (runs == null || runs.isEmpty) {
      return {'longestRun': '--', 'bestPace': '--'};
    }

    final longest =
        runs.map((r) => r.distanceKm).reduce((a, b) => a > b ? a : b);

    double bestPaceSec = double.infinity;
    for (final r in runs) {
      if (r.distanceKm > 0.1 && r.timeSeconds > 0) {
        final pace = r.timeSeconds / r.distanceKm;
        if (pace < bestPaceSec) bestPaceSec = pace;
      }
    }

    String paceStr = '--';
    if (bestPaceSec != double.infinity) {
      final min = (bestPaceSec / 60).floor();
      final sec = (bestPaceSec % 60).round();
      paceStr = "$min:${sec.toString().padLeft(2, '0')}";
    }

    return {
      'longestRun': '${longest.toStringAsFixed(1)} km',
      'bestPace': paceStr,
    };
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon!')),
            ),
          ),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _db.streamUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          final displayName = user?.displayName ?? 'Runner';
          final location = [user?.city ?? '', user?.country ?? '']
              .where((s) => s.isNotEmpty)
              .join(', ');
          final badges = user != null ? _achievements(user) : <_Achievement>[];
          final unlockedCount = badges.where((b) => b.unlocked).length;
          final records = _personalRecords();

          return StreamBuilder<List<Territory>>(
            stream: _db.streamUserTerritories(uid),
            builder: (context, terrSnap) {
              final territories = terrSnap.data ?? [];

              return CustomScrollView(
                slivers: [
                  // ── Banner + Avatar ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildBanner(
                        displayName, location, unlockedCount, badges.length),
                  ),

                  // ── Stats Row ────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildStatsRow(user)),

                  // ── Achievements ─────────────────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildAchievements(badges, unlockedCount)),

                  // ── Territory Portfolio ──────────────────────────────────
                  if (territories.isNotEmpty)
                    SliverToBoxAdapter(
                        child: _buildTerritoryPortfolio(territories)),

                  // ── Personal Records ─────────────────────────────────────
                  SliverToBoxAdapter(
                      child: _buildPersonalRecords(records, user)),

                  // ── Settings Menu ─────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildSettingsMenu(context)),

                  // ── Logout ───────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildLogout(context)),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─── Banner ─────────────────────────────────────────────────────────────────

  Widget _buildBanner(
      String displayName, String location, int unlocked, int total) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Location
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white70),
                const SizedBox(width: 3),
                Text(
                  location,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Badge progress pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events,
                    color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                Text(
                  '$unlocked of $total badges unlocked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow(UserProfile? user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _statCell(
            '${user?.totalRuns ?? 0}',
            'Total Runs',
            Icons.directions_run,
            AppTheme.primaryOrange,
          ),
          _statDivider(),
          _statCell(
            (user?.totalDistance ?? 0).toStringAsFixed(1),
            'km run',
            Icons.route,
            AppTheme.secondaryBlue,
          ),
          _statDivider(),
          _statCell(
            '${user?.territoriesOwned ?? 0}',
            'Zones',
            Icons.flag_outlined,
            AppTheme.accentPurple,
          ),
          _statDivider(),
          _statCell(
            '${user?.runningStreak ?? 0}',
            'Day Streak',
            Icons.local_fire_department,
            AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _statCell(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 40,
        color: Colors.grey[200],
      );

  // ─── Achievements ────────────────────────────────────────────────────────────

  Widget _buildAchievements(
      List<_Achievement> badges, int unlockedCount) {
    return _section(
      title: 'Achievements',
      trailing: Text(
        '$unlockedCount/${badges.length}',
        style:
            const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
      ),
      child: SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: badges.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) =>
              _achievementCard(badges[index]),
        ),
      ),
    );
  }

  Widget _achievementCard(_Achievement badge) {
    return GestureDetector(
      onTap: () => _showAchievementDetail(badge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        decoration: BoxDecoration(
          color: badge.unlocked
              ? badge.color.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: badge.unlocked
                ? badge.color.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Icon(
                  badge.icon,
                  size: 34,
                  color: badge.unlocked ? badge.color : Colors.grey[350],
                ),
                if (!badge.unlocked)
                  const Icon(Icons.lock, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                badge.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badge.unlocked ? Colors.black87 : Colors.grey[400],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(_Achievement badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: badge.unlocked
                    ? badge.color.withValues(alpha: 0.12)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon,
                  size: 44,
                  color:
                      badge.unlocked ? badge.color : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(badge.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(badge.subtitle,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.unlocked
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.unlocked ? '✓ Unlocked' : '🔒 Keep running to unlock!',
                style: TextStyle(
                  color: badge.unlocked
                      ? AppTheme.successGreen
                      : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Territory Portfolio ──────────────────────────────────────────────────────

  Widget _buildTerritoryPortfolio(List<Territory> territories) {
    final sorted = [...territories]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final display = sorted.take(10).toList();

    return _section(
      title: 'My Territories',
      trailing: Text(
        '${territories.length} zones',
        style: const TextStyle(
            color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
      ),
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: display.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) =>
              _territoryCard(display[index], index + 1),
        ),
      ),
    );
  }

  Widget _territoryCard(Territory t, int zoneNumber) {
    final now = DateTime.now();
    final daysAgo = now.difference(t.createdAt).inDays;
    final isNew = daysAgo <= 7;
    final statusColor = isNew ? AppTheme.successGreen : AppTheme.secondaryBlue;
    final statusLabel = isNew ? 'New' : 'Safe';

    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
            left: BorderSide(color: statusColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: statusColor, size: 16),
              const SizedBox(width: 4),
              Text(
                'Zone #$zoneNumber',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${t.areaSqKm.toStringAsFixed(3)} km²',
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                daysAgo == 0 ? 'Today' : '${daysAgo}d ago',
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Personal Records ─────────────────────────────────────────────────────────

  Widget _buildPersonalRecords(
      Map<String, String> records, UserProfile? user) {
    return _section(
      title: 'Personal Records',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _recordCard(
              records['longestRun'] ?? '--',
              'Longest Run',
              Icons.straighten,
              AppTheme.primaryOrange,
            ),
            const SizedBox(width: 10),
            _recordCard(
              records['bestPace'] ?? '--',
              'Best Pace /km',
              Icons.speed,
              AppTheme.secondaryBlue,
            ),
            const SizedBox(width: 10),
            _recordCard(
              '${(user?.totalAreaSqKm ?? 0).toStringAsFixed(2)} km²',
              'Total Area',
              Icons.map_outlined,
              AppTheme.accentPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Settings Menu ────────────────────────────────────────────────────────────

  Widget _buildSettingsMenu(BuildContext context) {
    final options = [
      (Icons.person_outline, 'Edit Profile', Colors.blue),
      (Icons.notifications_none, 'Notifications', Colors.orange),
      (Icons.lock_outline, 'Privacy & Security', Colors.green),
      (Icons.help_outline, 'Help & Support', Colors.purple),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, color) = entry.value;
          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(icon, color: color, size: 20),
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 20),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title coming soon!')),
                ),
              ),
              if (i < options.length - 1)
                Divider(
                    height: 1,
                    indent: 70,
                    endIndent: 16,
                    color: Colors.grey[100]),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────────────────

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Log Out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: () async {
            final authNotifier =
                Provider.of<AuthNotifier>(context, listen: false);
            await authNotifier.logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(
                  context, AppConstants.routeLogin);
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorRed,
            side: const BorderSide(color: AppTheme.errorRed),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // ─── Section wrapper ──────────────────────────────────────────────────────────

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
          ),
          child,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
