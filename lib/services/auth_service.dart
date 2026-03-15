import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/network_log_entry.dart';
import '../services/network_log_store.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NetworkLogStore _logStore = NetworkLogStore();
  int _logCounter = 0;

  // ─── Logging helper ─────────────────────────────────────────────────────────

  Future<T> _log<T>({
    required String operation,
    Map<String, dynamic>? request,
    required Future<T> Function() action,
  }) async {
    final entry = NetworkLogEntry(
      id: 'auth_${DateTime.now().millisecondsSinceEpoch}_${_logCounter++}',
      method: 'AUTH',
      path: 'firebase_auth',
      operation: operation,
      requestData: request,
      timestamp: DateTime.now(),
    );
    _logStore.addLog(entry);

    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      Map<String, dynamic>? responseData;
      if (result is UserCredential) {
        responseData = {
          'uid': result.user?.uid,
          'email': result.user?.email,
        };
      } else {
        responseData = {'result': 'success'};
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

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword(
      String email, String password) async {
    return _log(
      operation: 'signUpWithEmailPassword',
      request: {'email': email},
      action: () async {
        try {
          final UserCredential userCredential =
              await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          return userCredential;
        } on FirebaseAuthException catch (e) {
          debugPrint('Firebase Auth Error (SignUp): ${e.message}');
          rethrow;
        }
      },
    );
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    return _log(
      operation: 'signInWithEmailPassword',
      request: {'email': email},
      action: () async {
        try {
          final UserCredential userCredential =
              await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          return userCredential;
        } on FirebaseAuthException catch (e) {
          debugPrint('Firebase Auth Error (SignIn): ${e.message}');
          rethrow;
        }
      },
    );
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    return _log(
      operation: 'sendPasswordResetEmail',
      request: {'email': email},
      action: () async {
        try {
          await _auth.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (e) {
          debugPrint('Firebase Auth Error (ResetPassword): ${e.message}');
          rethrow;
        }
      },
    );
  }

  // Log out
  Future<void> signOut() async {
    return _log(
      operation: 'signOut',
      action: () async {
        await _auth.signOut();
      },
    );
  }

  // Get current user streams
  Stream<User?> get userChanges => _auth.userChanges();

  // Get current user sync
  User? get currentUser => _auth.currentUser;
}
