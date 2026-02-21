import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String photoUrl;
  final double totalDistance;
  final int territoriesOwned;
  final int runningStreak;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl = '',
    this.totalDistance = 0.0,
    this.territoriesOwned = 0,
    this.runningStreak = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data, String documentId) {
    return UserProfile(
      uid: documentId,
      displayName: data['displayName'] ?? 'Runner',
      photoUrl: data['photoUrl'] ?? '',
      totalDistance: (data['totalDistance'] ?? 0).toDouble(),
      territoriesOwned: data['territoriesOwned'] ?? 0,
      runningStreak: data['runningStreak'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'totalDistance': totalDistance,
      'territoriesOwned': territoriesOwned,
      'runningStreak': runningStreak,
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
