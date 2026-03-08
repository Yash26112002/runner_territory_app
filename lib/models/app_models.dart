import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String photoUrl;
  final double totalDistance;
  final int territoriesOwned;
  final int runningStreak;
  final String city;
  final String state;
  final String country;
  final double totalAreaSqKm;
  final int totalRuns;
  final List<String> unlockedRewards;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl = '',
    this.totalDistance = 0.0,
    this.territoriesOwned = 0,
    this.runningStreak = 0,
    this.city = '',
    this.state = '',
    this.country = '',
    this.totalAreaSqKm = 0.0,
    this.totalRuns = 0,
    this.unlockedRewards = const [],
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      displayName: data['displayName'] ?? 'Runner',
      photoUrl: data['photoUrl'] ?? '',
      totalDistance: (data['totalDistance'] ?? 0).toDouble(),
      territoriesOwned: data['territoriesOwned'] ?? 0,
      runningStreak: data['runningStreak'] ?? 0,
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      country: data['country'] ?? '',
      totalAreaSqKm: (data['totalAreaSqKm'] ?? 0).toDouble(),
      totalRuns: data['totalRuns'] ?? 0,
      unlockedRewards: List<String>.from(data['unlockedRewards'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'totalDistance': totalDistance,
      'territoriesOwned': territoriesOwned,
      'runningStreak': runningStreak,
      'city': city,
      'state': state,
      'country': country,
      'totalAreaSqKm': totalAreaSqKm,
      'totalRuns': totalRuns,
      'unlockedRewards': unlockedRewards,
    };
  }
}

class Territory {
  final String id;
  final String ownerId;
  final String ownerName;
  final double areaSqKm;
  final List<LatLng> polygonPoints;
  final DateTime createdAt;

  Territory({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.areaSqKm,
    required this.polygonPoints,
    required this.createdAt,
  });

  factory Territory.fromMap(Map<String, dynamic> data, String documentId) {
    List<LatLng> points = [];
    if (data['polygonPoints'] != null) {
      final List<dynamic> rawPoints = data['polygonPoints'];
      points = rawPoints.map((p) {
        final GeoPoint point = p as GeoPoint;
        return LatLng(point.latitude, point.longitude);
      }).toList();
    }

    return Territory(
      id: documentId,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? 'Unknown',
      areaSqKm: (data['areaSqKm'] ?? 0).toDouble(),
      polygonPoints: points,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'areaSqKm': areaSqKm,
      'polygonPoints':
          polygonPoints.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class RunHistory {
  final String id;
  final String userId;
  final double distanceKm;
  final int timeSeconds;
  final DateTime date;

  RunHistory({
    required this.id,
    required this.userId,
    required this.distanceKm,
    required this.timeSeconds,
    required this.date,
  });

  factory RunHistory.fromMap(Map<String, dynamic> data, String documentId) {
    return RunHistory(
      id: documentId,
      userId: data['userId'] ?? '',
      distanceKm: (data['distanceKm'] ?? 0).toDouble(),
      timeSeconds: data['timeSeconds'] ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'distanceKm': distanceKm,
      'timeSeconds': timeSeconds,
      'date': Timestamp.fromDate(date),
    };
  }
}

class Challenge {
  final String id;
  final String territoryId;
  final String challengerId;
  final String challengerName;
  final String defenderId;
  final String defenderName;
  final String status; // 'active' | 'completed'
  final String outcome; // 'pending' | 'challenger_won' | 'defender_won'
  final DateTime createdAt;
  final double areaSqKm;
  final List<String>
      participants; // [challengerId, defenderId] for arrayContains queries

  Challenge({
    required this.id,
    required this.territoryId,
    required this.challengerId,
    required this.challengerName,
    required this.defenderId,
    required this.defenderName,
    this.status = 'active',
    this.outcome = 'pending',
    required this.createdAt,
    this.areaSqKm = 0.0,
    required this.participants,
  });

  factory Challenge.fromMap(Map<String, dynamic> data, String documentId) {
    return Challenge(
      id: documentId,
      territoryId: data['territoryId'] ?? '',
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? 'Challenger',
      defenderId: data['defenderId'] ?? '',
      defenderName: data['defenderName'] ?? 'Defender',
      status: data['status'] ?? 'active',
      outcome: data['outcome'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      areaSqKm: (data['areaSqKm'] ?? 0).toDouble(),
      participants: List<String>.from(data['participants'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'territoryId': territoryId,
      'challengerId': challengerId,
      'challengerName': challengerName,
      'defenderId': defenderId,
      'defenderName': defenderName,
      'status': status,
      'outcome': outcome,
      'createdAt': Timestamp.fromDate(createdAt),
      'areaSqKm': areaSqKm,
      'participants': participants,
    };
  }
}

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String avatarText;
  final String actionText;
  // 'run' | 'territory' | 'challenge' | 'milestone'
  final String type;
  final double distanceKm;
  final DateTime timestamp;
  final int likes;
  final int comments;
  final List<String> likedBy; // UIDs who liked this post
  final String imageUrl; // optional badge/image url
  final Map<String, dynamic> extraData; // flexible payload per type

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarText,
    required this.actionText,
    this.type = 'run',
    this.distanceKm = 0.0,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.likedBy = const [],
    this.imageUrl = '',
    this.extraData = const {},
  });

  factory FeedPost.fromMap(Map<String, dynamic> data, String documentId) {
    return FeedPost(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Runner',
      avatarText: data['avatarText'] ?? 'R',
      actionText: data['actionText'] ?? 'did something.',
      type: data['type'] ?? 'run',
      distanceKm: (data['distanceKm'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      extraData: Map<String, dynamic>.from(data['extraData'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarText': avatarText,
      'actionText': actionText,
      'type': type,
      'distanceKm': distanceKm,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy,
      'imageUrl': imageUrl,
      'extraData': extraData,
    };
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String avatarText;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarText,
    required this.text,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String documentId) {
    return Comment(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Runner',
      avatarText: data['avatarText'] ?? 'R',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarText': avatarText,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String fromAvatarText;
  final String toUserId;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromAvatarText,
    required this.toUserId,
    this.status = 'pending',
    required this.createdAt,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> data, String documentId) {
    return FriendRequest(
      id: documentId,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? 'Runner',
      fromAvatarText: data['fromAvatarText'] ?? 'R',
      toUserId: data['toUserId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromAvatarText': fromAvatarText,
      'toUserId': toUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class RunningClub {
  final String id;
  final String name;
  final String description;
  final String ownerUserId;
  final String iconEmoji;
  final List<String> members; // UIDs
  final Map<String, String> memberNames; // uid → displayName
  final Map<String, String> memberAvatarTexts; // uid → avatarText
  final double totalAreaSqKm;
  final bool isPublic;
  final DateTime createdAt;

  RunningClub({
    required this.id,
    required this.name,
    this.description = '',
    required this.ownerUserId,
    this.iconEmoji = '🏃',
    this.members = const [],
    this.memberNames = const {},
    this.memberAvatarTexts = const {},
    this.totalAreaSqKm = 0.0,
    this.isPublic = true,
    required this.createdAt,
  });

  factory RunningClub.fromMap(Map<String, dynamic> data, String documentId) {
    return RunningClub(
      id: documentId,
      name: data['name'] ?? 'Unnamed Club',
      description: data['description'] ?? '',
      ownerUserId: data['ownerUserId'] ?? '',
      iconEmoji: data['iconEmoji'] ?? '🏃',
      members: List<String>.from(data['members'] ?? []),
      memberNames: Map<String, String>.from(data['memberNames'] ?? {}),
      memberAvatarTexts:
          Map<String, String>.from(data['memberAvatarTexts'] ?? {}),
      totalAreaSqKm: (data['totalAreaSqKm'] ?? 0).toDouble(),
      isPublic: data['isPublic'] ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerUserId': ownerUserId,
      'iconEmoji': iconEmoji,
      'members': members,
      'memberNames': memberNames,
      'memberAvatarTexts': memberAvatarTexts,
      'totalAreaSqKm': totalAreaSqKm,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ClubMessage {
  final String id;
  final String userId;
  final String userName;
  final String avatarText;
  final String text;
  final DateTime timestamp;

  ClubMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarText,
    required this.text,
    required this.timestamp,
  });

  factory ClubMessage.fromMap(Map<String, dynamic> data, String documentId) {
    return ClubMessage(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Runner',
      avatarText: data['avatarText'] ?? 'R',
      text: data['text'] ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarText': avatarText,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
