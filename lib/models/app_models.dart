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
  final UserSettings? settings;

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
    this.settings,
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
      settings: data['settings'] != null
          ? UserSettings.fromMap(data['settings'])
          : null,
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
      'settings': settings?.toMap(),
    };
  }
}

class UserSettings {
  final String territoryVisibility; // 'public', 'private'
  final bool highAccuracyGps;
  final bool audioCuesEnabled;

  UserSettings({
    this.territoryVisibility = 'public',
    this.highAccuracyGps = true,
    this.audioCuesEnabled = true,
  });

  factory UserSettings.fromMap(Map<String, dynamic> data) {
    return UserSettings(
      territoryVisibility: data['territoryVisibility'] ?? 'public',
      highAccuracyGps: data['highAccuracyGps'] ?? true,
      audioCuesEnabled: data['audioCuesEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'territoryVisibility': territoryVisibility,
      'highAccuracyGps': highAccuracyGps,
      'audioCuesEnabled': audioCuesEnabled,
    };
  }

  UserSettings copyWith({
    String? territoryVisibility,
    bool? highAccuracyGps,
    bool? audioCuesEnabled,
  }) {
    return UserSettings(
      territoryVisibility: territoryVisibility ?? this.territoryVisibility,
      highAccuracyGps: highAccuracyGps ?? this.highAccuracyGps,
      audioCuesEnabled: audioCuesEnabled ?? this.audioCuesEnabled,
    );
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
  final List<String> participants; // [challengerId, defenderId] for arrayContains queries

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
  final double distanceKm; // Optional, 0 if just a status
  final DateTime timestamp;
  final int likes;
  final int comments;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarText,
    required this.actionText,
    this.distanceKm = 0.0,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
  });

  factory FeedPost.fromMap(Map<String, dynamic> data, String documentId) {
    return FeedPost(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Runner',
      avatarText: data['avatarText'] ?? 'R',
      actionText: data['actionText'] ?? 'did something.',
      distanceKm: (data['distanceKm'] ?? 0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'avatarText': avatarText,
      'actionText': actionText,
      'distanceKm': distanceKm,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments,
    };
  }
}
