import 'package:flutter/foundation.dart';
import '../models/network_log_entry.dart';

class NetworkLogStore extends ChangeNotifier {
  // Singleton
  static final NetworkLogStore _instance = NetworkLogStore._internal();
  factory NetworkLogStore() => _instance;
  NetworkLogStore._internal();

  final List<NetworkLogEntry> _logs = [];
  static const int _maxLogs = 200;

  List<NetworkLogEntry> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;
  int get errorCount => _logs.where((e) => e.status == 'error').length;

  void addLog(NetworkLogEntry entry) {
    _logs.insert(0, entry); // newest first
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  void updateLog(String id) {
    // Entry is mutated in place, just notify
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
