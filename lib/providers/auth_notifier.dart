import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { idle, loading, success, error }

class AuthNotifier extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  String? get userToken => _authService.currentUser?.uid;

  // ── Login ──────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _setLoading();
    try {
      await _authService.signInWithEmailPassword(email, password);

      // Persist auth token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserToken,
          _authService.currentUser?.uid ?? 'logged_in');

      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Authentication failed');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Sign Up ────────────────────────────────────────────
  Future<bool> signup({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading();
    try {
      await _authService.signUpWithEmailPassword(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserToken,
          _authService.currentUser?.uid ?? 'logged_in');

      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Registration failed');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Forgot Password ────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    _setLoading();
    try {
      await _authService.sendPasswordResetEmail(email);
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Failed to send reset email');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserToken);
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = AuthStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  void resetStatus() {
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
