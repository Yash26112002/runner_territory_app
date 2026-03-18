import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';

class SettingsNotifier extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  String? _userId;

  UserSettings _settings = UserSettings();
  UserSettings get settings => _settings;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> initialize(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load from SharedPreferences for immediate sync UI
      final prefs = await SharedPreferences.getInstance();
      _settings = UserSettings(
        territoryVisibility: prefs.getString('territoryVisibility') ?? 'public',
        highAccuracyGps: prefs.getBool('highAccuracyGps') ?? true,
        audioCuesEnabled: prefs.getBool('audioCuesEnabled') ?? true,
      );
      
      // 2. Fetch from Firestore to ensure cloud sync
      final userProfile = await _db.getUser(userId);
      if (userProfile?.settings != null) {
        _settings = userProfile!.settings!;
        // Update local cache
        await _saveLocalSettings(_settings);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();

    if (_userId != null) {
      try {
        await _saveLocalSettings(newSettings);
        await _db.updateUserSettings(_userId!, newSettings);
      } catch (e) {
        debugPrint('Error updating settings: $e');
      }
    }
  }

  Future<void> _saveLocalSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('territoryVisibility', settings.territoryVisibility);
    await prefs.setBool('highAccuracyGps', settings.highAccuracyGps);
    await prefs.setBool('audioCuesEnabled', settings.audioCuesEnabled);
  }

  void clear() {
    _userId = null;
    _settings = UserSettings();
    notifyListeners();
  }
}
