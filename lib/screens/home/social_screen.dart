import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../widgets/custom_button.dart';
import 'friends_clubs_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  static final DatabaseService _db = DatabaseService();

  late TabController _tabController;
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'All', 'type': null, 'icon': Icons.feed_outlined},
    {'label': 'Runs', 'type': 'run', 'icon': Icons.directions_run},
    {'label': 'Territory', 'type': 'territory', 'icon': Icons.terrain},
    {'label': 'Battles', 'type': 'challenge', 'icon': Icons.whatshot},
    {'label': 'Milestones', 'type': 'milestone', 'icon': Icons.emoji_events},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverHeader(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabs
              .map((tab) => _buildFeedTab(tab['type'] as String?))
              .toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'createPost',
        onPressed: () => _showCreatePostSheet(context),
        backgroundColor: AppTheme.primaryOrange,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0F0F1A),
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 56,
      title: const Text(
        'Community',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_1_outlined,
              color: Colors.white70),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FriendsClubsScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications coming soon!')),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppTheme.primaryOrange,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppTheme.primaryOrange,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: _tabs
            .map((t) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t['icon'] as IconData, size: 14),
                      const SizedBox(width: 5),
                      Text(t['label'] as String,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFeedTab(String? type) {
    return StreamBuilder<List<FeedPost>>(
      stream: _db.streamFeedByType(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading feed',
                style: TextStyle(color: Colors.white54)),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return _buildEmptyState(type);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: posts.length,
          itemBuilder: (_, i) => _FeedCard(
            post: posts[i],
            db: _db,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String? type) {
    final label = type ?? 'activity';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rocket_launch_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            'No $label posts yet',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share something!',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePostSheet(),
    );
  }
}

// ─── Feed Card ────────────────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  final FeedPost post;
  final DatabaseService db;

  const _FeedCard({required this.post, required this.db});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _heartController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  static const Map<String, _TypeStyle> _styles = {
    'run': _TypeStyle(
      icon: Icons.directions_run,
      gradient: [Color(0xFFFF6B35), Color(0xFFFF9F68)],
      label: 'Run',
    ),
    'territory': _TypeStyle(
      icon: Icons.terrain,
      gradient: [Color(0xFF4A90E2), Color(0xFF7BB3F0)],
      label: 'Territory',
    ),
    'challenge': _TypeStyle(
      icon: Icons.whatshot,
      gradient: [Color(0xFFE74C3C), Color(0xFFFF7675)],
      label: 'Battle',
    ),
    'milestone': _TypeStyle(
      icon: Icons.emoji_events,
      gradient: [Color(0xFFF39C12), Color(0xFFFFD37C)],
      label: 'Milestone',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[widget.post.type] ?? _styles['run']!;
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';
    final isLiked = widget.post.likedBy.contains(uid);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: style.gradient.first.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: style.gradient.first.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: style.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.post.avatarText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(widget.post.timestamp),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: style.gradient
                          .map((c) => c.withValues(alpha: 0.2))
                          .toList(),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: style.gradient.first.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 11, color: style.gradient.first),
                      const SizedBox(width: 4),
                      Text(
                        style.label,
                        style: TextStyle(
                          color: style.gradient.first,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              widget.post.actionText,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),

          // Stats card (for runs)
          if (widget.post.type == 'run' && widget.post.distanceKm > 0)
            _buildRunStats(),

          // Challenge card
          if (widget.post.type == 'challenge') _buildChallengeCard(style),

          // Milestone card
          if (widget.post.type == 'milestone') _buildMilestoneCard(style),

          const SizedBox(height: 4),
          const Divider(color: Colors.white10, height: 1),

          // Actions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.post.likes}',
                  color: isLiked ? AppTheme.errorRed : Colors.white38,
                  onTap: () async {
                    _heartController.forward(from: 0);
                    await widget.db.toggleLike(widget.post.id, uid);
                  },
                  scaleAnimation: _heartScale,
                ),
                // Comment
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${widget.post.comments}',
                  color: Colors.white38,
                  onTap: () => _showCommentsSheet(context),
                ),
                const Spacer(),
                // Challenge Friend
                if (widget.post.userId != uid)
                  TextButton.icon(
                    onPressed: () => _sendChallenge(context, uid),
                    icon: const Icon(Icons.local_fire_department,
                        size: 14, color: AppTheme.primaryOrange),
                    label: const Text(
                      'Challenge',
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      backgroundColor:
                          AppTheme.primaryOrange.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCell('${widget.post.distanceKm.toStringAsFixed(2)} km',
              'Distance', AppTheme.primaryOrange),
          _divider(),
          _statCell(
            widget.post.extraData['pace'] as String? ?? '--:--',
            'Pace',
            AppTheme.secondaryBlue,
          ),
          _divider(),
          _statCell(
            widget.post.extraData['duration'] as String? ?? '--',
            'Time',
            AppTheme.successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(_TypeStyle style) {
    final defenderName =
        widget.post.extraData['defenderName'] as String? ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.errorRed.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.whatshot, color: AppTheme.errorRed, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.post.userName} vs $defenderName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Territory battle in progress',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.errorRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(_TypeStyle style) {
    final milestone = widget.post.extraData['milestone'] as String? ??
        '🏅 Achievement Unlocked!';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningYellow.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              milestone,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white10);

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: widget.post, db: widget.db),
    );
  }

  Future<void> _sendChallenge(BuildContext context, String uid) async {
    final currentUser = await widget.db.getUser(uid);
    if (currentUser == null) return;

    try {
      await widget.db.sendChallenge(
        challengerId: uid,
        challengerName: currentUser.displayName,
        defenderId: widget.post.userId,
        defenderName: widget.post.userName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚔️ Challenge sent to ${widget.post.userName}!'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send challenge')),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Animation<double>? scaleAnimation;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: color, size: 20);
    if (scaleAnimation != null) {
      iconWidget = ScaleTransition(scale: scaleAnimation!, child: iconWidget);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Comments Sheet ───────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final FeedPost post;
  final DatabaseService db;

  const _CommentsSheet({required this.post, required this.db});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';
    final user = await widget.db.getUser(uid);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final comment = Comment(
        id: '',
        userId: uid,
        userName: user.displayName,
        avatarText: user.displayName.isNotEmpty
            ? user.displayName[0].toUpperCase()
            : 'R',
        text: text,
        timestamp: DateTime.now(),
      );
      await widget.db.addComment(widget.post.id, comment);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Comments (${widget.post.comments})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // Comment list
            Expanded(
              child: StreamBuilder<List<Comment>>(
                stream: widget.db.streamComments(widget.post.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryOrange));
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: Colors.white12, size: 48),
                          SizedBox(height: 12),
                          Text('No comments yet. Be first!',
                              style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    itemBuilder: (_, i) => _buildCommentItem(comments[i]),
                  );
                },
              ),
            ),
            // Input row
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                  top: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _submitComment,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _sending
                              ? Colors.white12
                              : AppTheme.primaryOrange,
                        ),
                        child: _sending
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
            child: Text(
              c.avatarText,
              style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(c.timestamp),
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.text,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

// ─── Create Post Sheet ────────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  static final DatabaseService _db = DatabaseService();
  String _selectedType = 'run';
  final TextEditingController _controller = TextEditingController();
  bool _posting = false;

  final _typeOptions = [
    {'type': 'run', 'label': 'Run', 'icon': Icons.directions_run},
    {'type': 'territory', 'label': 'Territory', 'icon': Icons.terrain},
    {'type': 'milestone', 'label': 'Milestone', 'icon': Icons.emoji_events},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';
    final user = await _db.getUser(uid);
    if (user == null) return;

    setState(() => _posting = true);
    try {
      final post = FeedPost(
        id: '',
        userId: uid,
        userName: user.displayName,
        avatarText: user.displayName.isNotEmpty
            ? user.displayName[0].toUpperCase()
            : 'R',
        actionText: text,
        type: _selectedType,
        timestamp: DateTime.now(),
      );
      await _db.createFeedPost(post);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share with Community',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            // Type selector
            Row(
              children: _typeOptions.map((opt) {
                final selected = _selectedType == opt['type'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedType = opt['type'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppTheme.primaryOrange : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(opt['icon'] as IconData,
                              size: 14,
                              color: selected ? Colors.white : Colors.white54),
                          const SizedBox(width: 5),
                          Text(opt['label'] as String,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white54,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'What\'s happening? Share your run, territory, or achievement...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Post',
              onPressed: _post,
              isLoading: _posting,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _TypeStyle {
  final IconData icon;
  final List<Color> gradient;
  final String label;

  const _TypeStyle({
    required this.icon,
    required this.gradient,
    required this.label,
  });
}
