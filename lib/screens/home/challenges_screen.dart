import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../utils/constants.dart';

// ─── Dark theme constants ──────────────────────────────────────────────────────

const _bgColor = Color(0xFF0F0F1A);
const _cardColor = Color(0xFF1A1A2E);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late final TabController _tabController;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myUid = Provider.of<AuthNotifier>(context, listen: false).userToken;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  bool _isActive(Challenge c) =>
      c.status == 'active' &&
      DateTime.now().difference(c.createdAt).inDays <= 7;

  bool _isHistory(Challenge c) =>
      c.status == 'completed' ||
      DateTime.now().difference(c.createdAt).inDays > 7;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _shortId(String id) =>
      id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _myUid == null
          ? const Center(
              child: Text('Not logged in',
                  style: TextStyle(color: Colors.white54)))
          : StreamBuilder<List<Challenge>>(
              stream: _db.streamUserChallenges(_myUid!),
              builder: (context, snapshot) {
                final all = snapshot.data ?? [];
                final incoming = all
                    .where((c) =>
                        c.defenderId == _myUid && _isActive(c))
                    .toList();
                final myAttacks = all
                    .where((c) =>
                        c.challengerId == _myUid && _isActive(c))
                    .toList();
                final history =
                    all.where(_isHistory).toList();

                return NestedScrollView(
                  headerSliverBuilder: (ctx, innerScrolled) => [
                    _buildSliverAppBar(
                        innerScrolled, incoming.length, myAttacks.length),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIncomingTab(incoming),
                      _buildMyAttacksTab(myAttacks),
                      _buildHistoryTab(history),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(
      bool innerScrolled, int incomingCount, int attackCount) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _bgColor,
      elevation: innerScrolled ? 4 : 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Battles',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        if (incomingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$incomingCount under attack',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryOrange,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(
            child: _tabLabel(
                '⚔️ Under Attack',
                incomingCount,
                AppTheme.errorRed),
          ),
          Tab(
            child: _tabLabel(
                '🗡️ My Attacks',
                attackCount,
                AppTheme.primaryOrange),
          ),
          const Tab(text: '📜 History'),
        ],
      ),
    );
  }

  Widget _tabLabel(String label, int count, Color badgeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Under Attack Tab ─────────────────────────────────────────────────────────

  Widget _buildIncomingTab(List<Challenge> challenges) {
    if (challenges.isEmpty) {
      return _emptyState(
        icon: Icons.shield_outlined,
        title: 'Empire Secure',
        subtitle:
            'No territories under attack.\nKeep running to hold your ground!',
        color: AppTheme.successGreen,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _dramaticHeader(
          icon: Icons.whatshot,
          label:
              '${challenges.length} ${challenges.length == 1 ? 'territory' : 'territories'} under attack!',
          color: AppTheme.errorRed,
        ),
        const SizedBox(height: 12),
        ...challenges.map((c) => _challengeCard(
              challenge: c,
              perspective: 'defender',
              accentColor: AppTheme.errorRed,
            )),
      ],
    );
  }

  // ─── My Attacks Tab ──────────────────────────────────────────────────────────

  Widget _buildMyAttacksTab(List<Challenge> challenges) {
    if (challenges.isEmpty) {
      return _emptyState(
        icon: Icons.flag_outlined,
        title: 'No Active Raids',
        subtitle:
            'Run through other runners\' territories to start a battle!',
        color: AppTheme.primaryOrange,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _dramaticHeader(
          icon: Icons.terrain,
          label:
              'Conquering ${challenges.length} ${challenges.length == 1 ? 'territory' : 'territories'}',
          color: AppTheme.primaryOrange,
        ),
        const SizedBox(height: 12),
        ...challenges.map((c) => _challengeCard(
              challenge: c,
              perspective: 'challenger',
              accentColor: AppTheme.primaryOrange,
            )),
      ],
    );
  }

  // ─── History Tab ──────────────────────────────────────────────────────────────

  Widget _buildHistoryTab(List<Challenge> challenges) {
    if (challenges.isEmpty) {
      return _emptyState(
        icon: Icons.history_edu,
        title: 'No Battle History',
        subtitle: 'Your battles will be recorded here.',
        color: Colors.grey,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _dramaticHeader(
          icon: Icons.history,
          label: '${challenges.length} battles recorded',
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        ...challenges.map((c) => _historyCard(c)),
      ],
    );
  }

  // ─── Challenge Card ───────────────────────────────────────────────────────────

  Widget _challengeCard({
    required Challenge challenge,
    required String perspective, // 'defender' | 'challenger'
    required Color accentColor,
  }) {
    final isDefender = perspective == 'defender';
    final opponent =
        isDefender ? challenge.challengerName : challenge.defenderName;
    final opponentInitial = opponent.isNotEmpty ? opponent[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showBattleDetail(challenge, perspective),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Top: territory info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.terrain, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Territory #${_shortId(challenge.territoryId)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.crop_square,
                                size: 12, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text(
                              '${challenge.areaSqKm.toStringAsFixed(3)} km²',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time,
                                size: 12, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text(
                              _timeAgo(challenge.createdAt),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isDefender ? 'DEFEND' : 'ATTACKING',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // VS bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // My side
                  _vsAvatar(
                    initial: (isDefender
                            ? challenge.defenderName
                            : challenge.challengerName)
                        .isNotEmpty
                        ? (isDefender
                            ? challenge.defenderName[0]
                            : challenge.challengerName[0])
                            .toUpperCase()
                        : '?',
                    name: isDefender ? 'You (defending)' : 'You (attacking)',
                    color: AppTheme.primaryOrange,
                    isMe: true,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryOrange,
                                accentColor,
                              ],
                            ),
                          ),
                        ),
                        const Text(
                          '⚔️',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  _vsAvatar(
                    initial: opponentInitial,
                    name: opponent,
                    color: accentColor,
                    isMe: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Action bar
            Container(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        isDefender
                            ? Icons.directions_run
                            : Icons.info_outline,
                        size: 16,
                        color: accentColor,
                      ),
                      label: Text(
                        isDefender ? 'Defend Now' : 'View Details',
                        style:
                            TextStyle(color: accentColor, fontSize: 13),
                      ),
                      onPressed: () {
                        if (isDefender) {
                          _startDefenseRun(challenge);
                        } else {
                          _showBattleDetail(challenge, perspective);
                        }
                      },
                    ),
                  ),
                  Container(
                      width: 1, height: 24, color: Colors.white10),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.info_outline,
                          size: 16, color: Colors.white38),
                      label: const Text('Details',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      onPressed: () =>
                          _showBattleDetail(challenge, perspective),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── History Card ─────────────────────────────────────────────────────────────

  Widget _historyCard(Challenge challenge) {
    final isChallenger = challenge.challengerId == _myUid;
    final won = (isChallenger &&
            challenge.outcome == 'challenger_won') ||
        (!isChallenger && challenge.outcome == 'defender_won');
    final isDraw = challenge.outcome == 'pending';

    Color resultColor = isDraw
        ? Colors.grey.shade500
        : won
            ? AppTheme.successGreen
            : AppTheme.errorRed;
    String resultLabel = isDraw ? 'Expired' : won ? 'Victory' : 'Defeat';
    IconData resultIcon = isDraw
        ? Icons.hourglass_empty
        : won
            ? Icons.emoji_events
            : Icons.close;

    final opponent = isChallenger
        ? challenge.defenderName
        : challenge.challengerName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: resultColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Result icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, color: resultColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Territory #${_shortId(challenge.territoryId)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'vs $opponent',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _timeAgo(challenge.createdAt),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Result badge + area
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  resultLabel,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${challenge.areaSqKm.toStringAsFixed(3)} km²',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Battle Detail Bottom Sheet ───────────────────────────────────────────────

  void _showBattleDetail(Challenge challenge, String perspective) {
    final isDefender = perspective == 'defender';
    final accentColor =
        isDefender ? AppTheme.errorRed : AppTheme.primaryOrange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: _cardColor,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              const SizedBox(height: 20),

              // Territory header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.terrain,
                        color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Territory #${_shortId(challenge.territoryId)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Text(
                          '${challenge.areaSqKm.toStringAsFixed(3)} km² at stake',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isDefender ? 'UNDER ATTACK' : 'CAPTURING',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Big VS section
              _buildVsSection(challenge, isDefender),

              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  _detailStat('${challenge.areaSqKm.toStringAsFixed(3)} km²',
                      'Area at Stake', AppTheme.accentPurple),
                  const SizedBox(width: 10),
                  _detailStat(_timeAgo(challenge.createdAt),
                      'Battle Started', AppTheme.secondaryBlue),
                  const SizedBox(width: 10),
                  _detailStat(
                      challenge.status == 'active'
                          ? '${7 - DateTime.now().difference(challenge.createdAt).inDays}d'
                          : 'Ended',
                      'Time Left',
                      AppTheme.warningYellow),
                ],
              ),

              const SizedBox(height: 24),

              // Tips
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          AppTheme.primaryOrange.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates,
                        color: AppTheme.primaryOrange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDefender
                            ? 'Run through this territory to reclaim it and win the battle!'
                            : 'The defender has 7 days to reclaim this territory.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CTA button
              if (isDefender)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions_run,
                        color: Colors.white),
                    label: const Text(
                      'Defend Territory',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _startDefenseRun(challenge);
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

  Widget _buildVsSection(Challenge challenge, bool isDefender) {
    final challengerInitial = challenge.challengerName.isNotEmpty
        ? challenge.challengerName[0].toUpperCase()
        : '?';
    final defenderInitial = challenge.defenderName.isNotEmpty
        ? challenge.defenderName[0].toUpperCase()
        : '?';

    return Row(
      children: [
        Expanded(
          child: _bigAvatar(
            initial: challengerInitial,
            name: challenge.challengerName,
            label: 'ATTACKER',
            color: AppTheme.errorRed,
            isHighlighted: challenge.challengerId == _myUid,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _bigAvatar(
            initial: defenderInitial,
            name: challenge.defenderName,
            label: 'DEFENDER',
            color: AppTheme.successGreen,
            isHighlighted: challenge.defenderId == _myUid,
          ),
        ),
      ],
    );
  }

  Widget _bigAvatar({
    required String initial,
    required String name,
    required String label,
    required Color color,
    required bool isHighlighted,
  }) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(
              color: isHighlighted ? color : color.withValues(alpha: 0.4),
              width: isHighlighted ? 3 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name.length > 12 ? '${name.substring(0, 10)}…' : name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        Container(
          margin: const EdgeInsets.only(top: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────────

  Widget _vsAvatar({
    required String initial,
    required String name,
    required Color color,
    required bool isMe,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            isMe ? 'You' : name,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _dramaticHeader({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 52),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────────

  void _startDefenseRun(Challenge challenge) {
    Navigator.pushNamed(context, AppConstants.routeActiveRun);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Run through Territory #${_shortId(challenge.territoryId)} to defend it!'),
        backgroundColor: AppTheme.primaryOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
