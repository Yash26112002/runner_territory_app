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

  Future<void> updateUserSettings(String uid, UserSettings settings) async {
    await _usersRef.doc(uid).update({
      'settings': settings.toMap(),
    });
  }

  Future<void> updateUserProfileName(String uid, String newName) async {
    await _usersRef.doc(uid).update({
      'displayName': newName,
    });
  }

  // --- Territories ---

  Future<void> claimTerritory(Territory territory) async {
    final docRef = _territoriesRef.doc(); // Auto ID
    final newTerritory = Territory(
      id: docRef.id,
      ownerId: territory.ownerId,
      ownerName: territory.ownerName,
      areaSqKm: territory.areaSqKm,
      polygonPoints: territory.polygonPoints,
      createdAt: territory.createdAt,
    );
    await docRef.set(newTerritory.toMap());

    // Also update user's territory count and total area
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

    // Adjust counts and area
    await updateUserTerritoryCount(oldOwnerId, -1);
    await updateUserTerritoryCount(newOwnerId, 1);
    if (areaSqKm > 0) {
      await updateUserTotalArea(oldOwnerId, -areaSqKm);
      await updateUserTotalArea(newOwnerId, areaSqKm);
    }

    // Record the challenge if we know both parties
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
    final snapshot = await _runsRef
        .where('userId', isEqualTo: uid)
        .limit(100)
        .get();
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
}
