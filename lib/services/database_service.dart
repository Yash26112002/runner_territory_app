import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import '../models/network_log_entry.dart';
import '../services/network_log_store.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NetworkLogStore _logStore = NetworkLogStore();
  int _logCounter = 0;

  // Collection References
  CollectionReference get _usersRef => _db.collection('users');
  CollectionReference get _territoriesRef => _db.collection('territories');
  CollectionReference get _runsRef => _db.collection('runs');
  CollectionReference get _feedRef => _db.collection('feed');
  CollectionReference get _challengesRef => _db.collection('challenges');

  // ─── Logging helper ─────────────────────────────────────────────────────────

  Future<T> _log<T>({
    required String method,
    required String path,
    required String operation,
    Map<String, dynamic>? request,
    required Future<T> Function() action,
  }) async {
    final entry = NetworkLogEntry(
      id: 'db_${DateTime.now().millisecondsSinceEpoch}_${_logCounter++}',
      method: method,
      path: path,
      operation: operation,
      requestData: request,
      timestamp: DateTime.now(),
    );
    _logStore.addLog(entry);

    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      // Build response summary
      Map<String, dynamic>? responseData;
      if (result != null) {
        if (result is List) {
          responseData = {'count': result.length, 'type': 'List'};
        } else {
          responseData = {'type': result.runtimeType.toString()};
        }
      } else {
        responseData = {'result': 'null'};
      }
      entry.complete(
        durationMs: stopwatch.elapsedMilliseconds,
        responseData: responseData,
      );
      _logStore.updateLog(entry.id);
      return result;
    } catch (e) {
      stopwatch.stop();
      entry.fail(
        durationMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
      _logStore.updateLog(entry.id);
      rethrow;
    }
  }

  void _logStream({
    required String method,
    required String path,
    required String operation,
    Map<String, dynamic>? request,
  }) {
    final entry = NetworkLogEntry(
      id: 'db_${DateTime.now().millisecondsSinceEpoch}_${_logCounter++}',
      method: method,
      path: path,
      operation: operation,
      requestData: request,
      timestamp: DateTime.now(),
    );
    entry.complete(durationMs: 0, responseData: {'type': 'Stream (listening)'});
    _logStore.addLog(entry);
  }

  // --- Users ---

  Future<void> createUserProfile(UserProfile user) async {
    return _log(
      method: 'SET',
      path: 'users/${user.uid}',
      operation: 'createUserProfile',
      request: {'uid': user.uid, 'displayName': user.displayName},
      action: () async {
        await _usersRef.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      },
    );
  }

  Stream<UserProfile?> streamUser(String uid) {
    _logStream(
      method: 'STREAM',
      path: 'users/$uid',
      operation: 'streamUser',
      request: {'uid': uid},
    );
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(
          snapshot.data() as Map<String, dynamic>, snapshot.id);
    });
  }

  Future<UserProfile?> getUser(String uid) async {
    return _log(
      method: 'GET',
      path: 'users/$uid',
      operation: 'getUser',
      request: {'uid': uid},
      action: () async {
        final snapshot = await _usersRef.doc(uid).get();
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserProfile.fromMap(
            snapshot.data() as Map<String, dynamic>, snapshot.id);
      },
    );
  }

  Stream<List<UserProfile>> streamLeaderboard() {
    _logStream(
      method: 'STREAM',
      path: 'users',
      operation: 'streamLeaderboard',
      request: {'orderBy': 'totalDistance', 'descending': true},
    );
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
    return _log(
      method: 'UPDATE',
      path: 'users/$uid',
      operation: 'updateUserDistance',
      request: {'uid': uid, 'addedDistance': addedDistance},
      action: () async {
        await _usersRef.doc(uid).update({
          'totalDistance': FieldValue.increment(addedDistance),
        });
      },
    );
  }

  Future<void> updateUserTerritoryCount(String uid, int delta) async {
    return _log(
      method: 'UPDATE',
      path: 'users/$uid',
      operation: 'updateUserTerritoryCount',
      request: {'uid': uid, 'delta': delta},
      action: () async {
        await _usersRef.doc(uid).update({
          'territoriesOwned': FieldValue.increment(delta),
        });
      },
    );
  }

  Future<void> updateUserTotalArea(String uid, double areaDelta) async {
    return _log(
      method: 'UPDATE',
      path: 'users/$uid',
      operation: 'updateUserTotalArea',
      request: {'uid': uid, 'areaDelta': areaDelta},
      action: () async {
        await _usersRef.doc(uid).update({
          'totalAreaSqKm': FieldValue.increment(areaDelta),
        });
      },
    );
  }

  Future<void> updateUserSettings(String uid, UserSettings settings) async {
    return _log(
      method: 'UPDATE',
      path: 'users/$uid',
      operation: 'updateUserSettings',
      request: {'uid': uid, 'settings': settings.toMap()},
      action: () async {
        await _usersRef.doc(uid).update({
          'settings': settings.toMap(),
        });
      },
    );
  }

  Future<void> updateUserProfileName(String uid, String newName) async {
    return _log(
      method: 'UPDATE',
      path: 'users/$uid',
      operation: 'updateUserProfileName',
      request: {'uid': uid, 'newName': newName},
      action: () async {
        await _usersRef.doc(uid).update({
          'displayName': newName,
        });
      },
    );
  }

  // --- Territories ---

  Future<void> claimTerritory(Territory territory) async {
    return _log(
      method: 'SET',
      path: 'territories',
      operation: 'claimTerritory',
      request: {
        'ownerId': territory.ownerId,
        'ownerName': territory.ownerName,
        'areaSqKm': territory.areaSqKm,
        'points': territory.polygonPoints.length,
      },
      action: () async {
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
      },
    );
  }

  Future<void> overWriteTerritoryOwner(
    String territoryId,
    String oldOwnerId,
    String newOwnerId,
    String newOwnerName, {
    double areaSqKm = 0,
    String oldOwnerName = '',
  }) async {
    return _log(
      method: 'UPDATE',
      path: 'territories/$territoryId',
      operation: 'overWriteTerritoryOwner',
      request: {
        'territoryId': territoryId,
        'oldOwnerId': oldOwnerId,
        'newOwnerId': newOwnerId,
        'newOwnerName': newOwnerName,
        'areaSqKm': areaSqKm,
      },
      action: () async {
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
      },
    );
  }

  // --- Challenges ---

  Future<void> createChallenge(Challenge challenge) async {
    return _log(
      method: 'SET',
      path: 'challenges',
      operation: 'createChallenge',
      request: {
        'challengerId': challenge.challengerId,
        'defenderId': challenge.defenderId,
      },
      action: () async {
        await _challengesRef.doc().set(challenge.toMap());
      },
    );
  }

  Stream<List<Challenge>> streamUserChallenges(String uid) {
    _logStream(
      method: 'STREAM',
      path: 'challenges',
      operation: 'streamUserChallenges',
      request: {'uid': uid, 'filter': 'participants contains'},
    );
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
    return _log(
      method: 'UPDATE',
      path: 'challenges/$challengeId',
      operation: 'resolveChallenge',
      request: {'challengeId': challengeId, 'outcome': outcome},
      action: () async {
        await _challengesRef.doc(challengeId).update({
          'status': 'completed',
          'outcome': outcome,
        });
      },
    );
  }

  Stream<List<Territory>> streamGlobalTerritories() {
    _logStream(
      method: 'STREAM',
      path: 'territories',
      operation: 'streamGlobalTerritories',
    );
    return _territoriesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Territory.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Stream<List<Territory>> streamUserTerritories(String uid) {
    _logStream(
      method: 'STREAM',
      path: 'territories',
      operation: 'streamUserTerritories',
      request: {'uid': uid, 'filter': 'ownerId == uid'},
    );
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
    return _log(
      method: 'QUERY',
      path: 'territories',
      operation: 'getAllTerritories',
      request: {'limit': 200},
      action: () async {
        final snapshot = await _territoriesRef.limit(200).get();
        return snapshot.docs
            .map((doc) =>
                Territory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      },
    );
  }

  // --- Feed & Runs ---

  Future<void> saveRun(RunHistory run) async {
    return _log(
      method: 'SET',
      path: 'runs',
      operation: 'saveRun',
      request: {
        'userId': run.userId,
        'distanceKm': run.distanceKm,
        'timeSeconds': run.timeSeconds,
      },
      action: () async {
        await _runsRef.doc().set(run.toMap());
        await _usersRef.doc(run.userId).update({
          'totalRuns': FieldValue.increment(1),
        });
      },
    );
  }

  Future<List<RunHistory>> getUserRuns(String uid) async {
    return _log(
      method: 'QUERY',
      path: 'runs',
      operation: 'getUserRuns',
      request: {'uid': uid, 'limit': 100},
      action: () async {
        final snapshot = await _runsRef
            .where('userId', isEqualTo: uid)
            .limit(100)
            .get();
        return snapshot.docs
            .map((doc) =>
                RunHistory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      },
    );
  }

  Future<void> createFeedPost(FeedPost post) async {
    return _log(
      method: 'SET',
      path: 'feed',
      operation: 'createFeedPost',
      request: {
        'userId': post.userId,
        'userName': post.userName,
        'action': post.actionText,
      },
      action: () async {
        await _feedRef.doc().set(post.toMap());
      },
    );
  }

  Stream<List<FeedPost>> streamFeed() {
    _logStream(
      method: 'STREAM',
      path: 'feed',
      operation: 'streamFeed',
      request: {'orderBy': 'timestamp', 'limit': 50},
    );
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
