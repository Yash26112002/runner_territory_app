import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/auth_notifier.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

const _bgColor = Color(0xFF0F0F1A);
const _cardColor = Color(0xFF1A1A2E);

// ─── Screen ───────────────────────────────────────────────────────────────────

class FriendsClubsScreen extends StatefulWidget {
  const FriendsClubsScreen({super.key});

  @override
  State<FriendsClubsScreen> createState() => _FriendsClubsScreenState();
}

class _FriendsClubsScreenState extends State<FriendsClubsScreen>
    with SingleTickerProviderStateMixin {
  static final _db = DatabaseService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Mark user as recently online
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';
    if (uid.isNotEmpty) _db.updateLastSeen(uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverHeader()],
        body: TabBarView(
          controller: _tabController,
          children: const [_FriendsTab(), _ClubsTab()],
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      backgroundColor: _bgColor,
      floating: true,
      snap: true,
      pinned: false,
      expandedHeight: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Friends & Clubs',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
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
                Icon(Icons.people_outline, size: 15),
                SizedBox(width: 6),
                Text('Friends', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_outlined, size: 15),
                SizedBox(width: 6),
                Text('Clubs', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friends Tab ──────────────────────────────────────────────────────────────

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  static final _db = DatabaseService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      final results = await _db.searchUsers(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';

    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search runners...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        // Search results
        if (_searching)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange, strokeWidth: 2)),
            ),
          )
        else if (_searchResults.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _UserSearchResultCard(
                profile: _searchResults[i],
                currentUid: uid,
                db: _db,
              ),
              childCount: _searchResults.length,
            ),
          )
        else ...[
          // Incoming requests
          SliverToBoxAdapter(
            child: StreamBuilder<List<FriendRequest>>(
              stream: _db.streamIncomingFriendRequests(uid),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                        'Friend Requests (${requests.length})',
                        AppTheme.warningYellow),
                    ...requests.map((r) => _FriendRequestCard(
                          request: r,
                          db: _db,
                          currentUid: uid,
                        )),
                  ],
                );
              },
            ),
          ),

          // Friends list
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _db.streamFriends(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _shimmerList();
                }
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return _emptyFriends();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Friends (${friends.length})', Colors.white70),
                    ...friends.map((f) => _FriendCard(
                          friendData: f,
                          currentUid: uid,
                          db: _db,
                        )),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyFriends() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text(
            'No friends yet',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Search for runners above to connect!',
            style: TextStyle(color: Colors.white24, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _shimmerList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

Widget _sectionHeader(String title, Color color) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// ─── User Search Result Card ──────────────────────────────────────────────────

class _UserSearchResultCard extends StatefulWidget {
  final UserProfile profile;
  final String currentUid;
  final DatabaseService db;

  const _UserSearchResultCard({
    required this.profile,
    required this.currentUid,
    required this.db,
  });

  @override
  State<_UserSearchResultCard> createState() => _UserSearchResultCardState();
}

class _UserSearchResultCardState extends State<_UserSearchResultCard> {
  bool _sent = false;
  bool _sending = false;

  Future<void> _addFriend() async {
    setState(() => _sending = true);
    final me = await widget.db.getUser(widget.currentUid);
    if (me == null) {
      setState(() => _sending = false);
      return;
    }
    await widget.db.sendFriendRequest(
      fromUserId: widget.currentUid,
      fromUserName: me.displayName,
      fromAvatarText:
          me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : 'R',
      toUserId: widget.profile.uid,
    );
    if (mounted) {
      setState(() {
        _sent = true;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = widget.profile.uid == widget.currentUid;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _avatarCircle(widget.profile.displayName,
              [const Color(0xFF4A90E2), const Color(0xFF7BB3F0)]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.profile.displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  '${widget.profile.totalDistance.toStringAsFixed(1)} km · ${widget.profile.territoriesOwned} territories',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isSelf)
            _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryOrange),
                  )
                : TextButton(
                    onPressed: _sent ? null : _addFriend,
                    style: TextButton.styleFrom(
                      backgroundColor: _sent
                          ? Colors.white10
                          : AppTheme.primaryOrange.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      _sent ? 'Sent' : 'Add',
                      style: TextStyle(
                        color: _sent ? Colors.white38 : AppTheme.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

// ─── Friend Request Card ──────────────────────────────────────────────────────

class _FriendRequestCard extends StatefulWidget {
  final FriendRequest request;
  final String currentUid;
  final DatabaseService db;

  const _FriendRequestCard({
    required this.request,
    required this.currentUid,
    required this.db,
  });

  @override
  State<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<_FriendRequestCard> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    final me = await widget.db.getUser(widget.currentUid);
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    await widget.db.acceptFriendRequest(
      requestId: widget.request.id,
      fromUserId: widget.request.fromUserId,
      fromUserName: widget.request.fromUserName,
      fromAvatarText: widget.request.fromAvatarText,
      toUserId: widget.currentUid,
      toUserName: me.displayName,
      toAvatarText:
          me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : 'R',
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    await widget.db.declineFriendRequest(widget.request.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.warningYellow.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _avatarCircle(widget.request.fromUserName,
              [AppTheme.warningYellow, const Color(0xFFFFD37C)]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.fromUserName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Text(
                  'Wants to be your running buddy',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primaryOrange),
            )
          else ...[
            GestureDetector(
              onTap: _accept,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    color: AppTheme.successGreen, size: 16),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _decline,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: AppTheme.errorRed, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Friend Card ──────────────────────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final Map<String, dynamic> friendData;
  final String currentUid;
  final DatabaseService db;

  const _FriendCard({
    required this.friendData,
    required this.currentUid,
    required this.db,
  });

  bool _isOnline(dynamic lastSeen) {
    if (lastSeen == null) return false;
    DateTime? dt;
    if (lastSeen is DateTime) {
      dt = lastSeen;
    } else {
      // Could be Timestamp from Firestore nested data — treat as offline
      return false;
    }
    return DateTime.now().difference(dt).inMinutes < 5;
  }

  @override
  Widget build(BuildContext context) {
    final name = friendData['displayName'] as String? ?? 'Runner';
    final avatarText = friendData['avatarText'] as String? ??
        (name.isNotEmpty ? name[0].toUpperCase() : 'R');
    final online = _isOnline(friendData['lastSeen']);
    final uid = friendData['uid'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _avatarCircle(
                  name, [AppTheme.primaryOrange, const Color(0xFFFF9F68)]),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: online ? AppTheme.successGreen : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: _cardColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: online ? AppTheme.successGreen : Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  avatarText,
                  style: const TextStyle(color: Colors.transparent, fontSize: 0),
                ),
              ],
            ),
          ),
          if (uid.isNotEmpty)
            TextButton.icon(
              onPressed: () => _challenge(context, uid, name),
              icon: const Icon(Icons.local_fire_department,
                  size: 13, color: AppTheme.primaryOrange),
              label: const Text(
                'Challenge',
                style: TextStyle(
                  color: AppTheme.primaryOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor:
                    AppTheme.primaryOrange.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _challenge(
      BuildContext context, String friendUid, String friendName) async {
    final me = await db.getUser(currentUid);
    if (me == null) return;
    try {
      await db.sendChallenge(
        challengerId: currentUid,
        challengerName: me.displayName,
        defenderId: friendUid,
        defenderName: friendName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚔️ Challenge sent to $friendName!'),
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
}

// ─── Clubs Tab ────────────────────────────────────────────────────────────────

class _ClubsTab extends StatelessWidget {
  const _ClubsTab();

  @override
  Widget build(BuildContext context) {
    final uid =
        Provider.of<AuthNotifier>(context, listen: false).userToken ?? '';
    final db = DatabaseService();

    return CustomScrollView(
      slivers: [
        // My Clubs header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'My Clubs',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showCreateClubSheet(context, uid, db),
                  icon: const Icon(Icons.add, size: 14,
                      color: AppTheme.primaryOrange),
                  label: const Text(
                    'Create',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        AppTheme.primaryOrange.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
        ),

        // My clubs stream
        SliverToBoxAdapter(
          child: StreamBuilder<List<RunningClub>>(
            stream: db.streamUserClubs(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _clubShimmer();
              }
              final clubs = snapshot.data ?? [];
              if (clubs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.groups_outlined,
                            color: Colors.white12, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'No clubs yet — create one!',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: clubs
                    .map((c) => _ClubCard(
                          club: c,
                          isMember: true,
                          currentUid: uid,
                          db: db,
                        ))
                    .toList(),
              );
            },
          ),
        ),

        // Discover clubs header
        SliverToBoxAdapter(
          child: _sectionHeader('Discover Clubs', Colors.white70),
        ),

        // Public clubs
        SliverToBoxAdapter(
          child: StreamBuilder<List<RunningClub>>(
            stream: db.streamPublicClubs(),
            builder: (context, snapshot) {
              final allPublic = snapshot.data ?? [];
              // Filter out clubs user already belongs to
              final discover = allPublic
                  .where((c) => !c.members.contains(uid))
                  .toList();
              if (discover.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No public clubs to discover yet.',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: [
                  ...discover.map((c) => _ClubCard(
                        club: c,
                        isMember: false,
                        currentUid: uid,
                        db: db,
                      )),
                  const SizedBox(height: 100),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateClubSheet(
      BuildContext context, String uid, DatabaseService db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateClubSheet(currentUid: uid, db: db),
    );
  }

  Widget _clubShimmer() {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Club Card ────────────────────────────────────────────────────────────────

class _ClubCard extends StatefulWidget {
  final RunningClub club;
  final bool isMember;
  final String currentUid;
  final DatabaseService db;

  const _ClubCard({
    required this.club,
    required this.isMember,
    required this.currentUid,
    required this.db,
  });

  @override
  State<_ClubCard> createState() => _ClubCardState();
}

class _ClubCardState extends State<_ClubCard> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    final me = await widget.db.getUser(widget.currentUid);
    if (me == null) {
      setState(() => _joining = false);
      return;
    }
    await widget.db.joinClub(
      clubId: widget.club.id,
      userId: widget.currentUid,
      userName: me.displayName,
      avatarText: me.displayName.isNotEmpty
          ? me.displayName[0].toUpperCase()
          : 'R',
    );
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isMember
          ? () => _showDetail(context)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.accentPurple.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPurple.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPurple.withValues(alpha: 0.3),
                    AppTheme.secondaryBlue.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(widget.club.iconEmoji,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.club.members.length} members',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.terrain, size: 12, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.club.totalAreaSqKm.toStringAsFixed(2)} km²',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  if (widget.club.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.club.description,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isMember)
              const Icon(Icons.chevron_right, color: Colors.white24)
            else if (_joining)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryOrange),
              )
            else
              TextButton(
                onPressed: _join,
                style: TextButton.styleFrom(
                  backgroundColor:
                      AppTheme.accentPurple.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    color: AppTheme.accentPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubDetailSheet(
        club: widget.club,
        currentUid: widget.currentUid,
        db: widget.db,
      ),
    );
  }
}

// ─── Club Detail Sheet ────────────────────────────────────────────────────────

class _ClubDetailSheet extends StatefulWidget {
  final RunningClub club;
  final String currentUid;
  final DatabaseService db;

  const _ClubDetailSheet({
    required this.club,
    required this.currentUid,
    required this.db,
  });

  @override
  State<_ClubDetailSheet> createState() => _ClubDetailSheetState();
}

class _ClubDetailSheetState extends State<_ClubDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _cardColor,
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
            // Club header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(widget.club.iconEmoji,
                      style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.club.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${widget.club.members.length} members · ${widget.club.totalAreaSqKm.toStringAsFixed(2)} km²',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (widget.club.ownerUserId != widget.currentUid)
                    TextButton(
                      onPressed: _leave,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Leave',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            // Tab bar
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primaryOrange,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppTheme.primaryOrange,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Members'),
                Tab(text: 'Chat'),
              ],
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildMembersTab(controller),
                  _buildChatTab(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab(ScrollController controller) {
    final members = widget.club.memberNames.entries.toList();
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final entry = members[i];
        final uid = entry.key;
        final name = entry.value;
        final avatarText = widget.club.memberAvatarTexts[uid] ??
            (name.isNotEmpty ? name[0].toUpperCase() : 'R');
        final isOwner = uid == widget.club.ownerUserId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppTheme.accentPurple.withValues(alpha: 0.2),
                child: Text(
                  avatarText,
                  style: const TextStyle(
                    color: AppTheme.accentPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        AppTheme.warningYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Captain',
                    style: TextStyle(
                      color: AppTheme.warningYellow,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatTab(ScrollController controller) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ClubMessage>>(
            stream: widget.db.streamClubMessages(widget.club.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange, strokeWidth: 2));
              }
              final msgs = snapshot.data ?? [];
              if (msgs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: Colors.white12, size: 48),
                      SizedBox(height: 12),
                      Text('No messages yet. Say hi! 👋',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _buildMsgItem(msgs[i]),
              );
            },
          ),
        ),
        // Input
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
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message the club...',
                      hintStyle:
                          const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
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
    );
  }

  Widget _buildMsgItem(ClubMessage msg) {
    final isMe = msg.userId == widget.currentUid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  AppTheme.accentPurple.withValues(alpha: 0.2),
              child: Text(
                msg.avatarText,
                style: const TextStyle(
                    color: AppTheme.accentPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryOrange.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight:
                      isMe ? const Radius.circular(4) : null,
                  bottomLeft:
                      !isMe ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      msg.userName,
                      style: const TextStyle(
                        color: AppTheme.accentPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    msg.text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final me = await widget.db.getUser(widget.currentUid);
    if (me == null) return;

    setState(() => _sending = true);
    try {
      final msg = ClubMessage(
        id: '',
        userId: widget.currentUid,
        userName: me.displayName,
        avatarText: me.displayName.isNotEmpty
            ? me.displayName[0].toUpperCase()
            : 'R',
        text: text,
        timestamp: DateTime.now(),
      );
      await widget.db.sendClubMessage(widget.club.id, msg);
      _msgCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    await widget.db.leaveClub(
        clubId: widget.club.id, userId: widget.currentUid);
    if (mounted) Navigator.pop(context);
  }
}

// ─── Create Club Sheet ────────────────────────────────────────────────────────

class _CreateClubSheet extends StatefulWidget {
  final String currentUid;
  final DatabaseService db;

  const _CreateClubSheet({required this.currentUid, required this.db});

  @override
  State<_CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends State<_CreateClubSheet> {
  static const _emojis = ['🏃', '⚡', '🔥', '🌟', '🦅', '🐆'];
  String _selectedEmoji = '🏃';
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _isPublic = true;
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final me = await widget.db.getUser(widget.currentUid);
    if (me == null) return;

    setState(() => _creating = true);
    try {
      final club = RunningClub(
        id: '',
        name: name,
        description: _descCtrl.text.trim(),
        ownerUserId: widget.currentUid,
        iconEmoji: _selectedEmoji,
        members: [widget.currentUid],
        memberNames: {widget.currentUid: me.displayName},
        memberAvatarTexts: {
          widget.currentUid: me.displayName.isNotEmpty
              ? me.displayName[0].toUpperCase()
              : 'R'
        },
        isPublic: _isPublic,
        createdAt: DateTime.now(),
      );
      await widget.db.createClub(
        club,
        me.displayName.isNotEmpty ? me.displayName[0].toUpperCase() : 'R',
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _creating = false);
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
          color: _cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Running Club',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            // Emoji selector
            const Text('Icon',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: _emojis.map((e) {
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryOrange.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryOrange
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child:
                          Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Name
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Club name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Description
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Short description (optional)',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Public toggle
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Public Club',
                          style: TextStyle(
                              color: Colors.white, fontSize: 14)),
                      Text('Anyone can discover & join',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: AppTheme.primaryOrange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creating ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Create Club',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

Widget _avatarCircle(String name, List<Color> gradient) {
  final initial =
      name.isNotEmpty ? name[0].toUpperCase() : 'R';
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ),
  );
}
