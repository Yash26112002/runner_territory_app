import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

const _bgColor = Color(0xFF0F0F1A);
const _cardColor = Color(0xFF1A1A2E);

// ─── Badge definition ─────────────────────────────────────────────────────────

class _BadgeDef {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final String category;
  final int xp;
  final bool Function(UserProfile) isUnlocked;

  const _BadgeDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.category,
    required this.xp,
    required this.isUnlocked,
  });
}

// ─── Quest definition ─────────────────────────────────────────────────────────

class _QuestDef {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final int rewardXp;
  final double Function(UserProfile) progress; // 0.0–1.0
  final String Function(UserProfile) progressLabel;

  const _QuestDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.rewardXp,
    required this.progress,
    required this.progressLabel,
  });
}

// ─── Reward definition ────────────────────────────────────────────────────────

class _RewardDef {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final int xpCost;
  final Color color;

  const _RewardDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.xpCost,
    required this.color,
  });
}

// ─── Data ─────────────────────────────────────────────────────────────────────

const List<_BadgeDef> _badges = [
  // Running category
  _BadgeDef(
    id: 'first_steps',
    emoji: '👟',
    title: 'First Steps',
    subtitle: 'Complete your first run',
    color: AppTheme.successGreen,
    category: 'Running',
    xp: 50,
    isUnlocked: _unlockedFirstSteps,
  ),
  _BadgeDef(
    id: 'warming_up',
    emoji: '🔥',
    title: 'Warming Up',
    subtitle: 'Complete 5 runs',
    color: AppTheme.primaryOrange,
    category: 'Running',
    xp: 100,
    isUnlocked: _unlockedWarmingUp,
  ),
  _BadgeDef(
    id: 'regular_runner',
    emoji: '🏃',
    title: 'Regular Runner',
    subtitle: 'Complete 20 runs',
    color: AppTheme.secondaryBlue,
    category: 'Running',
    xp: 200,
    isUnlocked: _unlockedRegularRunner,
  ),
  _BadgeDef(
    id: 'run_veteran',
    emoji: '🎖️',
    title: 'Run Veteran',
    subtitle: 'Complete 50 runs',
    color: AppTheme.accentPurple,
    category: 'Running',
    xp: 400,
    isUnlocked: _unlockedRunVeteran,
  ),
  _BadgeDef(
    id: 'run_legend',
    emoji: '🏆',
    title: 'Run Legend',
    subtitle: 'Complete 100 runs',
    color: Color(0xFFFFD700),
    category: 'Running',
    xp: 800,
    isUnlocked: _unlockedRunLegend,
  ),
  // Distance category
  _BadgeDef(
    id: '5k_club',
    emoji: '🎽',
    title: '5K Club',
    subtitle: 'Run 5 km total',
    color: AppTheme.successGreen,
    category: 'Distance',
    xp: 75,
    isUnlocked: _unlocked5k,
  ),
  _BadgeDef(
    id: 'speedster',
    emoji: '⚡',
    title: 'Speedster',
    subtitle: 'Run 10 km total',
    color: AppTheme.warningYellow,
    category: 'Distance',
    xp: 150,
    isUnlocked: _unlockedSpeedster,
  ),
  _BadgeDef(
    id: 'half_marathoner',
    emoji: '🥈',
    title: 'Half Marathoner',
    subtitle: 'Run 21.1 km total',
    color: Color(0xFFC0C0C0),
    category: 'Distance',
    xp: 300,
    isUnlocked: _unlockedHalf,
  ),
  _BadgeDef(
    id: 'marathoner',
    emoji: '🥇',
    title: 'Marathoner',
    subtitle: 'Run 42.2 km total',
    color: Color(0xFFFFD700),
    category: 'Distance',
    xp: 600,
    isUnlocked: _unlockedMarathoner,
  ),
  _BadgeDef(
    id: 'ultra_rookie',
    emoji: '🦾',
    title: 'Ultra Rookie',
    subtitle: 'Run 100 km total',
    color: AppTheme.errorRed,
    category: 'Distance',
    xp: 1000,
    isUnlocked: _unlockedUltra,
  ),
  // Territory category
  _BadgeDef(
    id: 'territory_rookie',
    emoji: '🚩',
    title: 'Territory Rookie',
    subtitle: 'Claim your first zone',
    color: AppTheme.primaryOrange,
    category: 'Territory',
    xp: 75,
    isUnlocked: _unlockedTerritoryRookie,
  ),
  _BadgeDef(
    id: 'land_baron',
    emoji: '🗺️',
    title: 'Land Baron',
    subtitle: 'Own 5 territories',
    color: AppTheme.accentPurple,
    category: 'Territory',
    xp: 200,
    isUnlocked: _unlockedLandBaron,
  ),
  _BadgeDef(
    id: 'territory_overlord',
    emoji: '👑',
    title: 'Overlord',
    subtitle: 'Own 10 territories',
    color: Color(0xFFFFD700),
    category: 'Territory',
    xp: 400,
    isUnlocked: _unlockedOverlord,
  ),
  _BadgeDef(
    id: 'big_landowner',
    emoji: '🌍',
    title: 'Big Landowner',
    subtitle: 'Claim 1 km² total',
    color: AppTheme.secondaryBlue,
    category: 'Territory',
    xp: 300,
    isUnlocked: _unlockedBigLandowner,
  ),
  _BadgeDef(
    id: 'estate_owner',
    emoji: '🏰',
    title: 'Estate Owner',
    subtitle: 'Claim 5 km² total',
    color: AppTheme.accentPurple,
    category: 'Territory',
    xp: 600,
    isUnlocked: _unlockedEstate,
  ),
  // Streak category
  _BadgeDef(
    id: 'consistent',
    emoji: '📅',
    title: 'Consistent',
    subtitle: '3-day running streak',
    color: AppTheme.successGreen,
    category: 'Streak',
    xp: 50,
    isUnlocked: _unlockedConsistent,
  ),
  _BadgeDef(
    id: 'week_warrior',
    emoji: '🔥',
    title: 'Week Warrior',
    subtitle: '7-day running streak',
    color: AppTheme.errorRed,
    category: 'Streak',
    xp: 150,
    isUnlocked: _unlockedWeekWarrior,
  ),
  _BadgeDef(
    id: 'dedicated',
    emoji: '💪',
    title: 'Dedicated',
    subtitle: '14-day running streak',
    color: AppTheme.primaryOrange,
    category: 'Streak',
    xp: 300,
    isUnlocked: _unlockedDedicated,
  ),
  _BadgeDef(
    id: 'iron_runner',
    emoji: '🦾',
    title: 'Iron Runner',
    subtitle: '30-day running streak',
    color: Color(0xFFC0C0C0),
    category: 'Streak',
    xp: 750,
    isUnlocked: _unlockedIronRunner,
  ),
];

// Static functions for isUnlocked (required for const context)
bool _unlockedFirstSteps(UserProfile u) => u.totalRuns >= 1;
bool _unlockedWarmingUp(UserProfile u) => u.totalRuns >= 5;
bool _unlockedRegularRunner(UserProfile u) => u.totalRuns >= 20;
bool _unlockedRunVeteran(UserProfile u) => u.totalRuns >= 50;
bool _unlockedRunLegend(UserProfile u) => u.totalRuns >= 100;
bool _unlocked5k(UserProfile u) => u.totalDistance >= 5;
bool _unlockedSpeedster(UserProfile u) => u.totalDistance >= 10;
bool _unlockedHalf(UserProfile u) => u.totalDistance >= 21.1;
bool _unlockedMarathoner(UserProfile u) => u.totalDistance >= 42.2;
bool _unlockedUltra(UserProfile u) => u.totalDistance >= 100;
bool _unlockedTerritoryRookie(UserProfile u) => u.territoriesOwned >= 1;
bool _unlockedLandBaron(UserProfile u) => u.territoriesOwned >= 5;
bool _unlockedOverlord(UserProfile u) => u.territoriesOwned >= 10;
bool _unlockedBigLandowner(UserProfile u) => u.totalAreaSqKm >= 1;
bool _unlockedEstate(UserProfile u) => u.totalAreaSqKm >= 5;
bool _unlockedConsistent(UserProfile u) => u.runningStreak >= 3;
bool _unlockedWeekWarrior(UserProfile u) => u.runningStreak >= 7;
bool _unlockedDedicated(UserProfile u) => u.runningStreak >= 14;
bool _unlockedIronRunner(UserProfile u) => u.runningStreak >= 30;

final List<_QuestDef> _quests = [
  _QuestDef(
    id: 'q_5km',
    emoji: '🎯',
    title: 'Hit 5 km',
    description: 'Run a total of 5 km to prove your legs.',
    color: AppTheme.successGreen,
    rewardXp: 75,
    progress: (u) => (u.totalDistance / 5).clamp(0.0, 1.0),
    progressLabel: (u) =>
        '${u.totalDistance.toStringAsFixed(1)} / 5 km',
  ),
  _QuestDef(
    id: 'q_10runs',
    emoji: '🏃',
    title: 'Run 10 Times',
    description: 'Log 10 individual runs.',
    color: AppTheme.primaryOrange,
    rewardXp: 150,
    progress: (u) => (u.totalRuns / 10).clamp(0.0, 1.0),
    progressLabel: (u) => '${u.totalRuns} / 10 runs',
  ),
  _QuestDef(
    id: 'q_3zones',
    emoji: '🚩',
    title: 'Claim 3 Zones',
    description: 'Own at least 3 territories on the map.',
    color: AppTheme.accentPurple,
    rewardXp: 100,
    progress: (u) => (u.territoriesOwned / 3).clamp(0.0, 1.0),
    progressLabel: (u) =>
        '${u.territoriesOwned} / 3 territories',
  ),
  _QuestDef(
    id: 'q_7streak',
    emoji: '🔥',
    title: 'Week Warrior',
    description: 'Maintain a 7-day running streak.',
    color: AppTheme.errorRed,
    rewardXp: 200,
    progress: (u) => (u.runningStreak / 7).clamp(0.0, 1.0),
    progressLabel: (u) =>
        '${u.runningStreak} / 7 day streak',
  ),
  _QuestDef(
    id: 'q_halfmarathon',
    emoji: '🥈',
    title: 'Half-Marathon Total',
    description: 'Accumulate 21.1 km across all your runs.',
    color: const Color(0xFFC0C0C0),
    rewardXp: 350,
    progress: (u) => (u.totalDistance / 21.1).clamp(0.0, 1.0),
    progressLabel: (u) =>
        '${u.totalDistance.toStringAsFixed(1)} / 21.1 km',
  ),
  _QuestDef(
    id: 'q_1sqkm',
    emoji: '🗺️',
    title: 'Own 1 km²',
    description: 'Control a total area of at least 1 km².',
    color: AppTheme.secondaryBlue,
    rewardXp: 250,
    progress: (u) => (u.totalAreaSqKm / 1).clamp(0.0, 1.0),
    progressLabel: (u) =>
        '${u.totalAreaSqKm.toStringAsFixed(3)} / 1 km²',
  ),
];

const List<_RewardDef> _rewards = [
  _RewardDef(
    id: 'reward_orange_trail',
    emoji: '🔸',
    title: 'Orange Trail',
    description: 'Unlock the orange run-trail color on the map.',
    xpCost: 300,
    color: AppTheme.primaryOrange,
  ),
  _RewardDef(
    id: 'reward_purple_glow',
    emoji: '💜',
    title: 'Purple Glow',
    description: 'Territory glow effect — purple halo on your zones.',
    xpCost: 600,
    color: AppTheme.accentPurple,
  ),
  _RewardDef(
    id: 'reward_gold_border',
    emoji: '🥇',
    title: 'Gold Border',
    description: 'Gold ring avatar border shown on your profile & feed.',
    xpCost: 1000,
    color: Color(0xFFFFD700),
  ),
  _RewardDef(
    id: 'reward_territory_legend',
    emoji: '👑',
    title: 'Territory Legend',
    description: 'Exclusive "Legend" title badge displayed on your profile.',
    xpCost: 2500,
    color: AppTheme.warningYellow,
  ),
  _RewardDef(
    id: 'reward_night_runner',
    emoji: '🌙',
    title: 'Night Runner',
    description: 'Dark map theme unlocked for your running sessions.',
    xpCost: 800,
    color: AppTheme.secondaryBlue,
  ),
  _RewardDef(
    id: 'reward_iron_badge',
    emoji: '🦾',
    title: 'Iron Badge',
    description: 'Iron-tier frame for your public profile card.',
    xpCost: 1500,
    color: Color(0xFFC0C0C0),
  ),
];

int _computeXP(UserProfile user) {
  int xp = 0;
  for (final badge in _badges) {
    if (badge.isUnlocked(user)) xp += badge.xp;
  }
  return xp;
}

String _level(int xp) {
  if (xp >= 5000) return 'Legend';
  if (xp >= 2000) return 'Elite';
  if (xp >= 800) return 'Pro';
  if (xp >= 300) return 'Intermediate';
  return 'Rookie';
}

Color _levelColor(int xp) {
  if (xp >= 5000) return const Color(0xFFFFD700);
  if (xp >= 2000) return AppTheme.errorRed;
  if (xp >= 800) return AppTheme.accentPurple;
  if (xp >= 300) return AppTheme.secondaryBlue;
  return AppTheme.successGreen;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  static final _db = DatabaseService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';

    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<UserProfile?>(
        stream: _db.streamUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange));
          }
          final user = snapshot.data;
          final xp = user != null ? _computeXP(user) : 0;
          final level = _level(xp);
          final levelColor = _levelColor(xp);

          return NestedScrollView(
            headerSliverBuilder: (_, __) => [
              _buildSliverHeader(xp, level, levelColor, user),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                if (user != null)
                  _BadgesTab(user: user)
                else
                  const _LoadingTab(),
                if (user != null)
                  _QuestsTab(user: user, uid: uid)
                else
                  const _LoadingTab(),
                if (user != null)
                  _RewardsTab(user: user, uid: uid, xp: xp)
                else
                  const _LoadingTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverHeader(
      int xp, String level, Color levelColor, UserProfile? user) {
    final unlocked =
        user != null ? _badges.where((b) => b.isUnlocked(user)).length : 0;

    return SliverAppBar(
      backgroundColor: _bgColor,
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 130,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Achievements',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.none,
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  // XP pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: levelColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '$xp XP',
                          style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Level pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🏅 $level',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$unlocked/${_badges.length} badges',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryOrange,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppTheme.primaryOrange,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏅', style: TextStyle(fontSize: 13)),
                SizedBox(width: 5),
                Text('Badges', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎯', style: TextStyle(fontSize: 13)),
                SizedBox(width: 5),
                Text('Quests', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎁', style: TextStyle(fontSize: 13)),
                SizedBox(width: 5),
                Text('Rewards', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingTab extends StatelessWidget {
  const _LoadingTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange));
  }
}

// ─── Badges Tab ───────────────────────────────────────────────────────────────

class _BadgesTab extends StatelessWidget {
  final UserProfile user;

  const _BadgesTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final categories = ['Running', 'Distance', 'Territory', 'Streak'];

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: categories.map((cat) {
        final catBadges = _badges.where((b) => b.category == cat).toList();
        final unlocked = catBadges.where((b) => b.isUnlocked(user)).length;
        return _CategorySection(
          category: cat,
          badges: catBadges,
          unlockedCount: unlocked,
          user: user,
        );
      }).toList(),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<_BadgeDef> badges;
  final int unlockedCount;
  final UserProfile user;

  const _CategorySection({
    required this.category,
    required this.badges,
    required this.unlockedCount,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Text(
                _categoryEmoji(category),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount/${badges.length}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        // Grid
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemCount: badges.length,
          itemBuilder: (context, i) => _BadgeCard(
            badge: badges[i],
            unlocked: badges[i].isUnlocked(user),
          ),
        ),
        const SizedBox(height: 4),
        const Divider(color: Colors.white10, height: 1,
            indent: 16, endIndent: 16),
      ],
    );
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Running':
        return '🏃';
      case 'Distance':
        return '📏';
      case 'Territory':
        return '🗺️';
      case 'Streak':
        return '🔥';
      default:
        return '🏅';
    }
  }
}

class _BadgeCard extends StatelessWidget {
  final _BadgeDef badge;
  final bool unlocked;

  const _BadgeCard({required this.badge, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: unlocked
              ? badge.color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked
                ? badge.color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: badge.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ColorFiltered(
                  colorFilter: unlocked
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.multiply)
                      : const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.5, 0,
                        ]),
                  child: Text(
                    badge.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    bottom: -2,
                    right: -2,
                    child: Icon(Icons.lock, size: 13, color: Colors.white24),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                badge.title,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? Colors.white : Colors.white24,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${badge.xp} XP',
              style: TextStyle(
                fontSize: 9,
                color: unlocked
                    ? badge.color
                    : Colors.white12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: unlocked
                    ? badge.color.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                    color: unlocked
                        ? badge.color.withValues(alpha: 0.4)
                        : Colors.white12),
              ),
              child: Center(
                child: Text(badge.emoji,
                    style: const TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.subtitle,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppTheme.successGreen.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unlocked ? '✓ Unlocked' : '🔒 Locked',
                    style: TextStyle(
                      color: unlocked
                          ? AppTheme.successGreen
                          : Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: badge.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⚡ ${badge.xp} XP',
                    style: TextStyle(
                      color: badge.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quests Tab ───────────────────────────────────────────────────────────────

class _QuestsTab extends StatelessWidget {
  final UserProfile user;
  final String uid;

  const _QuestsTab({required this.user, required this.uid});

  @override
  Widget build(BuildContext context) {
    final active = _quests.where((q) => q.progress(user) < 1.0).toList();
    final completed = _quests.where((q) => q.progress(user) >= 1.0).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (active.isNotEmpty) ...[
          _sectionLabel('Active Quests (${active.length})',
              AppTheme.primaryOrange),
          ...active.map((q) => _QuestCard(quest: q, user: user)),
        ],
        if (completed.isNotEmpty) ...[
          _sectionLabel('Completed (${completed.length})',
              AppTheme.successGreen),
          ...completed.map((q) => _QuestCard(quest: q, user: user)),
        ],
        if (active.isEmpty && completed.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Text('🎯', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text(
                  'No quests available',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final _QuestDef quest;
  final UserProfile user;

  const _QuestCard({required this.quest, required this.user});

  @override
  Widget build(BuildContext context) {
    final prog = quest.progress(user);
    final done = prog >= 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? AppTheme.successGreen.withValues(alpha: 0.4)
              : quest.color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(quest.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      quest.description,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Reward XP badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.successGreen.withValues(alpha: 0.15)
                      : quest.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  done ? '✓ Done' : '⚡ +${quest.rewardXp}',
                  style: TextStyle(
                    color:
                        done ? AppTheme.successGreen : quest.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                  done ? AppTheme.successGreen : quest.color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quest.progressLabel(user),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
              Text(
                '${(prog * 100).toInt()}%',
                style: TextStyle(
                  color: done ? AppTheme.successGreen : quest.color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Rewards Tab ─────────────────────────────────────────────────────────────

class _RewardsTab extends StatelessWidget {
  final UserProfile user;
  final String uid;
  final int xp;

  const _RewardsTab(
      {required this.user, required this.uid, required this.xp});

  @override
  Widget build(BuildContext context) {
    final claimed =
        _rewards.where((r) => user.unlockedRewards.contains(r.id)).toList();
    final available =
        _rewards.where((r) => !user.unlockedRewards.contains(r.id)).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // XP summary banner
        _XpBanner(xp: xp),
        // Available rewards
        if (available.isNotEmpty) ...[
          _sectionLabel('Available Rewards', Colors.white70),
          ...available.map((r) => _RewardCard(
                reward: r,
                uid: uid,
                currentXp: xp,
                claimed: false,
              )),
        ],
        // Claimed rewards
        if (claimed.isNotEmpty) ...[
          _sectionLabel('Your Collection', AppTheme.successGreen),
          ...claimed.map((r) => _RewardCard(
                reward: r,
                uid: uid,
                currentXp: xp,
                claimed: true,
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _XpBanner extends StatelessWidget {
  final int xp;

  const _XpBanner({required this.xp});

  @override
  Widget build(BuildContext context) {
    final level = _level(xp);
    final color = _levelColor(xp);

    // Next tier threshold
    final int nextXp = xp >= 5000
        ? 5000
        : xp >= 2000
            ? 5000
            : xp >= 800
                ? 2000
                : xp >= 300
                    ? 800
                    : 300;
    final double prog = (xp / nextXp).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🏅 $level',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '$xp XP',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            xp >= 5000
                ? 'Maximum level reached!'
                : '$xp / $nextXp XP to next tier',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatefulWidget {
  final _RewardDef reward;
  final String uid;
  final int currentXp;
  final bool claimed;

  const _RewardCard({
    required this.reward,
    required this.uid,
    required this.currentXp,
    required this.claimed,
  });

  @override
  State<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<_RewardCard> {
  static final _db = DatabaseService();
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    await _db.claimReward(widget.uid, widget.reward.id);
    if (mounted) {
      setState(() => _claiming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎁 ${widget.reward.title} unlocked!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.currentXp >= widget.reward.xpCost;
    final color = widget.reward.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.claimed
              ? AppTheme.successGreen.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Emoji container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.claimed
                  ? AppTheme.successGreen.withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.claimed
                      ? AppTheme.successGreen.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(widget.reward.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reward.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.reward.description,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⚡ ${widget.reward.xpCost} XP',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action button
          if (widget.claimed)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✓ Owned',
                style: TextStyle(
                  color: AppTheme.successGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (_claiming)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primaryOrange),
            )
          else
            GestureDetector(
              onTap: canAfford ? _claim : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: canAfford
                      ? color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canAfford
                        ? color.withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Text(
                  canAfford ? 'Claim' : 'Locked',
                  style: TextStyle(
                    color: canAfford ? color : Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
