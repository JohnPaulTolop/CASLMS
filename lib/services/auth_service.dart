import 'dart:async';

import 'activity_log_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CURRENT FIREBASE USER
  // ============================================================

  User? get currentUser => _auth.currentUser;

  // ============================================================
  // AUTH STATE
  // ============================================================

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================
  // SIGN IN
  // ============================================================

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Firebase Authentication
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw AuthServiceException(
          'Unable to retrieve the authenticated user.',
        );
      }

      // Retrieve the user's Firestore profile
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await _firestore.collection('users').doc(user.uid).get();

      // Firestore profile does not exist
      if (!userDocument.exists) {
        await _auth.signOut();

        throw AuthServiceException('Your CASLMS user profile was not found.');
      }

      final Map<String, dynamic>? data = userDocument.data();

      if (data == null) {
        await _auth.signOut();

        throw AuthServiceException('Your CASLMS user profile is invalid.');
      }

      // ============================================================
      // CHECK ACCOUNT STATUS
      // ============================================================

      final String status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'active') {
        await _auth.signOut();

        throw AuthServiceException(
          'Your account is currently suspended or inactive.',
        );
      }

      // ============================================================
      // GET USER ROLE
      // ============================================================

      final String role = (data['role'] ?? '').toString().trim().toLowerCase();

      final List<String> allowedRoles = ['student', 'instructor', 'admin'];

      if (!allowedRoles.contains(role)) {
        await _auth.signOut();

        throw AuthServiceException(
          'Your account does not have a valid CASLMS role.',
        );
      }

      unawaited(
        ActivityLogService(
          auth: _auth,
          firestore: _firestore,
        ).session('login', profile: data),
      );

      // Return role to auth_page.dart
      return role;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getFirebaseAuthMessage(e));
    } on FirebaseException catch (e) {
      throw AuthServiceException(e.message ?? 'A Firebase error occurred.');
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException('Unable to log in. Please try again.');
    }
  }

  // ============================================================
  // GET CURRENT USER DATA
  // ============================================================

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists) {
        return null;
      }

      return document.data();
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET CURRENT USER ROLE
  // ============================================================

  Future<String?> getCurrentUserRole() async {
    final Map<String, dynamic>? data = await getCurrentUserData();

    if (data == null) {
      return null;
    }

    final String? role = data['role']?.toString();

    return role?.trim().toLowerCase();
  }

  // ============================================================
  // GET CURRENT USER STATUS
  // ============================================================

  Future<String?> getCurrentUserStatus() async {
    final Map<String, dynamic>? data = await getCurrentUserData();

    if (data == null) {
      return null;
    }

    final String? status = data['status']?.toString();

    return status?.trim().toLowerCase();
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_getFirebaseAuthMessage(e));
    } catch (e) {
      throw AuthServiceException('Unable to send password reset email.');
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    try {
      await ActivityLogService(auth: _auth, firestore: _firestore).signOut();
    } catch (e) {
      throw AuthServiceException('Unable to log out. Please try again.');
    }
  }

  // ============================================================
  // FIREBASE AUTH ERROR MESSAGES
  // ============================================================

  String _getFirebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'user-not-found':
        return 'No account was found with this email.';

      case 'wrong-password':
        return 'Incorrect email or password.';

      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'operation-not-allowed':
        return 'Email and password login is not enabled.';

      case 'missing-password':
        return 'Please enter your password.';

      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

// ============================================================
// CUSTOM AUTH EXCEPTION
// ============================================================

class AuthServiceException implements Exception {
  final String message;

  AuthServiceException(this.message);

  @override
  String toString() => message;
}
