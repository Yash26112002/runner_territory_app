import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _territoriesRef => _db.collection('territories');
  CollectionReference get _runsRef => _db.collection('runs');
  CollectionReference get _feedRef => _db.collection('feed');
  CollectionReference get _challengesRef => _db.collection('challenges');
  CollectionReference get _friendRequestsRef =>
      _db.collection('friend_requests');
  CollectionReference get _clubsRef => _db.collection('clubs');

  // --- Users ---

  Future<void> createUserProfile(UserProfile user) async {
    await _usersRef.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Stream<UserProfile?> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(
          snapshot.data() as Map<String, dynamic>, snapshot.id);
    });
  }

  Future<UserProfile?> getUser(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return UserProfile.fromMap(
        snapshot.data() as Map<String, dynamic>, snapshot.id);
  }

  Stream<List<UserProfile>> streamLeaderboard() {
    return _usersRef
        .orderBy('totalDistance', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> updateUserDistance(String uid, double addedDistance) async {
    await _usersRef.doc(uid).update({
      'totalDistance': FieldValue.increment(addedDistance),
    });
  }

  Future<void> updateUserTerritoryCount(String uid, int delta) async {
    await _usersRef.doc(uid).update({
      'territoriesOwned': FieldValue.increment(delta),
    });
  }

  Future<void> updateUserTotalArea(String uid, double areaDelta) async {
    await _usersRef.doc(uid).update({
      'totalAreaSqKm': FieldValue.increment(areaDelta),
    });
  }

  // --- Territories ---

  Future<void> claimTerritory(Territory territory) async {
    final docRef = _territoriesRef.doc();
    final newTerritory = Territory(
      id: docRef.id,
      ownerId: territory.ownerId,
      ownerName: territory.ownerName,
      areaSqKm: territory.areaSqKm,
      polygonPoints: territory.polygonPoints,
      createdAt: territory.createdAt,
    );
    await docRef.set(newTerritory.toMap());
    await updateUserTerritoryCount(territory.ownerId, 1);
    await updateUserTotalArea(territory.ownerId, territory.areaSqKm);
  }

  Future<void> overWriteTerritoryOwner(
    String territoryId,
    String oldOwnerId,
    String newOwnerId,
    String newOwnerName, {
    double areaSqKm = 0,
    String oldOwnerName = '',
  }) async {
    await _territoriesRef.doc(territoryId).update({
      'ownerId': newOwnerId,
      'ownerName': newOwnerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await updateUserTerritoryCount(oldOwnerId, -1);
    await updateUserTerritoryCount(newOwnerId, 1);
    if (areaSqKm > 0) {
      await updateUserTotalArea(oldOwnerId, -areaSqKm);
      await updateUserTotalArea(newOwnerId, areaSqKm);
    }
    if (oldOwnerName.isNotEmpty) {
      final challenge = Challenge(
        id: '',
        territoryId: territoryId,
        challengerId: newOwnerId,
        challengerName: newOwnerName,
        defenderId: oldOwnerId,
        defenderName: oldOwnerName,
        status: 'active',
        outcome: 'pending',
        createdAt: DateTime.now(),
        areaSqKm: areaSqKm,
        participants: [newOwnerId, oldOwnerId],
      );
      await createChallenge(challenge);
    }
  }

  // --- Challenges ---

  Future<void> createChallenge(Challenge challenge) async {
    await _challengesRef.doc().set(challenge.toMap());
  }

  Stream<List<Challenge>> streamUserChallenges(String uid) {
    return _challengesRef
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final challenges = snapshot.docs
          .map((doc) =>
              Challenge.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      challenges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return challenges;
    });
  }

  Future<void> resolveChallenge(String challengeId, String outcome) async {
    await _challengesRef.doc(challengeId).update({
      'status': 'completed',
      'outcome': outcome,
    });
  }

  /// Send a direct challenge to another user and post to the feed.
  Future<void> sendChallenge({
    required String challengerId,
    required String challengerName,
    required String defenderId,
    required String defenderName,
  }) async {
    final challenge = Challenge(
      id: '',
      territoryId: '',
      challengerId: challengerId,
      challengerName: challengerName,
      defenderId: defenderId,
      defenderName: defenderName,
      status: 'active',
      outcome: 'pending',
      createdAt: DateTime.now(),
      areaSqKm: 0,
      participants: [challengerId, defenderId],
    );
    final docRef = await _challengesRef.add(challenge.toMap());

    final post = FeedPost(
      id: '',
      userId: challengerId,
      userName: challengerName,
      avatarText:
          challengerName.isNotEmpty ? challengerName[0].toUpperCase() : 'R',
      actionText: 'challenged $defenderName to a territory battle! ⚔️',
      type: 'challenge',
      timestamp: DateTime.now(),
      extraData: {
        'challengeId': docRef.id,
        'defenderId': defenderId,
        'defenderName': defenderName,
      },
    );
    await createFeedPost(post);
  }

  Stream<List<Territory>> streamGlobalTerritories() {
    return _territoriesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Territory.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Stream<List<Territory>> streamUserTerritories(String uid) {
    return _territoriesRef
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Territory.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<List<Territory>> getAllTerritories() async {
    final snapshot = await _territoriesRef.limit(200).get();
    return snapshot.docs
        .map((doc) =>
            Territory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // --- Feed & Runs ---

  Future<void> saveRun(RunHistory run) async {
    await _runsRef.doc().set(run.toMap());
    await _usersRef.doc(run.userId).update({
      'totalRuns': FieldValue.increment(1),
    });
  }

  Future<List<RunHistory>> getUserRuns(String uid) async {
    final snapshot =
        await _runsRef.where('userId', isEqualTo: uid).limit(100).get();
    return snapshot.docs
        .map((doc) =>
            RunHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> createFeedPost(FeedPost post) async {
    await _feedRef.doc().set(post.toMap());
  }

  Stream<List<FeedPost>> streamFeed() {
    return _feedRef
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FeedPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Stream feed filtered by type. Pass null for all types.
  Stream<List<FeedPost>> streamFeedByType(String? type) {
    Query query = _feedRef.orderBy('timestamp', descending: true).limit(50);
    if (type != null) {
      query = _feedRef
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .limit(50);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              FeedPost.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // --- Likes ---

  Future<void> toggleLike(String postId, String uid) async {
    final docRef = _feedRef.doc(postId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    if (likedBy.contains(uid)) {
      await docRef.update({
        'likedBy': FieldValue.arrayRemove([uid]),
        'likes': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'likedBy': FieldValue.arrayUnion([uid]),
        'likes': FieldValue.increment(1),
      });
    }
  }

  // --- Comments ---

  Future<void> addComment(String postId, Comment comment) async {
    await _feedRef.doc(postId).collection('comments').add(comment.toMap());
    await _feedRef.doc(postId).update({
      'comments': FieldValue.increment(1),
    });
  }

  Stream<List<Comment>> streamComments(String postId) {
    return _feedRef
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- Friends ---

  Future<void> claimReward(String uid, String rewardId) async {
    await _usersRef.doc(uid).update({
      'unlockedRewards': FieldValue.arrayUnion([rewardId]),
    });
  }

  Future<void> updateLastSeen(String uid) async {
    await _usersRef.doc(uid).update({'lastSeen': FieldValue.serverTimestamp()});
  }

  Future<void> sendFriendRequest({
    required String fromUserId,
    required String fromUserName,
    required String fromAvatarText,
    required String toUserId,
  }) async {
    // Check no existing pending request in either direction
    final existing = await _friendRequestsRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final request = FriendRequest(
      id: '',
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      fromAvatarText: fromAvatarText,
      toUserId: toUserId,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _friendRequestsRef.add(request.toMap());
  }

  Stream<List<FriendRequest>> streamIncomingFriendRequests(String uid) {
    return _friendRequestsRef
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUserId,
    required String fromUserName,
    required String fromAvatarText,
    required String toUserId,
    required String toUserName,
    required String toAvatarText,
  }) async {
    final batch = _db.batch();
    // Update request status
    batch.update(_friendRequestsRef.doc(requestId), {'status': 'accepted'});
    // Write friendship in both directions
    final now = Timestamp.now();
    batch.set(
      _db
          .collection('friendships')
          .doc(fromUserId)
          .collection('friends')
          .doc(toUserId),
      {
        'uid': toUserId,
        'displayName': toUserName,
        'avatarText': toAvatarText,
        'since': now,
      },
    );
    batch.set(
      _db
          .collection('friendships')
          .doc(toUserId)
          .collection('friends')
          .doc(fromUserId),
      {
        'uid': fromUserId,
        'displayName': fromUserName,
        'avatarText': fromAvatarText,
        'since': now,
      },
    );
    await batch.commit();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _friendRequestsRef.doc(requestId).update({'status': 'declined'});
  }

  Stream<List<Map<String, dynamic>>> streamFriends(String uid) {
    return _db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .doc(friendUid));
    batch.delete(_db
        .collection('friendships')
        .doc(friendUid)
        .collection('friends')
        .doc(uid));
    await batch.commit();
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final snapshot = await _usersRef
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
    return snapshot.docs
        .map((doc) =>
            UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // --- Clubs ---

  Future<String> createClub(RunningClub club, String creatorAvatarText) async {
    final docRef = _clubsRef.doc();
    final withCreator = RunningClub(
      id: docRef.id,
      name: club.name,
      description: club.description,
      ownerUserId: club.ownerUserId,
      iconEmoji: club.iconEmoji,
      members: [club.ownerUserId],
      memberNames: {club.ownerUserId: club.memberNames[club.ownerUserId] ?? ''},
      memberAvatarTexts: {club.ownerUserId: creatorAvatarText},
      totalAreaSqKm: 0,
      isPublic: club.isPublic,
      createdAt: club.createdAt,
    );
    await docRef.set(withCreator.toMap());
    return docRef.id;
  }

  Stream<List<RunningClub>> streamUserClubs(String uid) {
    return _clubsRef
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RunningClub.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<RunningClub>> streamPublicClubs() {
    return _clubsRef
        .where('isPublic', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RunningClub.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> joinClub({
    required String clubId,
    required String userId,
    required String userName,
    required String avatarText,
  }) async {
    await _clubsRef.doc(clubId).update({
      'members': FieldValue.arrayUnion([userId]),
      'memberNames.$userId': userName,
      'memberAvatarTexts.$userId': avatarText,
    });
  }

  Future<void> leaveClub({
    required String clubId,
    required String userId,
  }) async {
    final doc = await _clubsRef.doc(clubId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final memberNames = Map<String, dynamic>.from(data['memberNames'] ?? {});
    final memberAvatarTexts =
        Map<String, dynamic>.from(data['memberAvatarTexts'] ?? {});
    memberNames.remove(userId);
    memberAvatarTexts.remove(userId);
    await _clubsRef.doc(clubId).update({
      'members': FieldValue.arrayRemove([userId]),
      'memberNames': memberNames,
      'memberAvatarTexts': memberAvatarTexts,
    });
  }

  Future<void> sendClubMessage(String clubId, ClubMessage message) async {
    await _clubsRef.doc(clubId).collection('messages').add(message.toMap());
  }

  Stream<List<ClubMessage>> streamClubMessages(String clubId) {
    return _clubsRef
        .doc(clubId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClubMessage.fromMap(doc.data(), doc.id))
            .toList());
  }
}
