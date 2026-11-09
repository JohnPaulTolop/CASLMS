import 'dart:async';

import 'activity_log_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../config/academic_catalog.dart';

class CampusAuthService {
  CampusAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _internalDomain = 'caslms.app';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.idTokenChanges();

  String normalizeCampusId(String campusId) {
    return campusId.trim().replaceAll(RegExp(r'\s+'), '');
  }

  bool isValidCampusId(String campusId) {
    final String id = normalizeCampusId(campusId);

    return RegExp(r'^\d{5,12}$').hasMatch(id);
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  String firebaseEmailForCampusId(String campusId) {
    final String id = normalizeCampusId(campusId);

    return '$id@$_internalDomain';
  }

  Future<CampusAuthResult> signUpStudent({
    required String fullName,
    required String email,
    required String campusId,
    required String department,
    required String course,
    required String password,
  }) async {
    final String cleanName = fullName.trim();

    final String cleanEmail = email.trim().toLowerCase();

    final String cleanCampusId = normalizeCampusId(campusId);

    final String cleanDepartment = department.trim();

    final String cleanCourse = course.trim();

    if (cleanName.length < 2) {
      throw CampusAuthException('Enter your complete name.');
    }

    if (!isValidEmail(cleanEmail)) {
      throw CampusAuthException('Enter a valid email address.');
    }

    if (!isValidCampusId(cleanCampusId)) {
      throw CampusAuthException('Enter a valid campus ID number.');
    }

    if (cleanDepartment != AcademicCatalog.department) {
      throw CampusAuthException(
        'Registration is for College of Arts and Sciences (CAS).',
      );
    }

    if (cleanCourse.isEmpty) {
      throw CampusAuthException('Course is required.');
    }
    if (!AcademicCatalog.contains(cleanDepartment, cleanCourse)) {
      throw CampusAuthException(
        'Select a program belonging to the selected department.',
      );
    }

    if (password.length < 6) {
      throw CampusAuthException('Password must contain at least 6 characters.');
    }

    final String authEmail = cleanEmail;

    UserCredential credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') {
        throw CampusAuthException(_firebaseMessage(error));
      }
      // Recover an interrupted registration only after verifying its password.
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } on FirebaseAuthException catch (_) {
        throw CampusAuthException(
          'This email is already registered. Please sign in or reset your password.',
        );
      }
    }

    final User? user = credential.user;

    if (user == null) {
      throw CampusAuthException('Unable to create your account.');
    }

    try {
      await user.updateDisplayName(cleanName);

      final Map<String, dynamic> profile = {
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'universityId': cleanCampusId,
        'authEmail': authEmail,
        'department': cleanDepartment,
        'course': cleanCourse,
        'role': 'student',
        'status': 'pending_verification',
        'emailVerificationRequired': true,
        'emailVerifiedAt': null,
        'approvalStatus': 'not_required',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await _registrationRequest({
        'action': 'register',
        'fullName': cleanName,
        'campusId': cleanCampusId,
        'department': cleanDepartment,
        'course': cleanCourse,
      });
      // A delivery failure must not delete a successfully created profile.
      // The verification screen provides a resend action.
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (_) {}

      return CampusAuthResult(
        user: user,
        profile: {
          ...profile,
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
          'lastLoginAt': DateTime.now(),
        },
      );
    } catch (error) {
      // Never delete an existing or successfully committed account after a
      // network failure. A subsequent register retry is idempotent on the server.
      throw CampusAuthException('Unable to finish registration: $error');
    }
  }

  Future<CampusAuthResult> signIn({
    required String campusId,
    required String password,
  }) async {
    final String cleanCampusId = normalizeCampusId(campusId);

    if (!isValidCampusId(cleanCampusId)) {
      throw CampusAuthException('Enter a valid campus ID number.');
    }

    if (password.isEmpty) {
      throw CampusAuthException('Enter your password.');
    }

    final String authEmail = firebaseEmailForCampusId(cleanCampusId);

    UserCredential credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      const credentialErrors = {
        'invalid-credential',
        'wrong-password',
        'user-not-found',
      };
      if (!credentialErrors.contains(error.code)) {
        throw CampusAuthException(_firebaseMessage(error));
      }
      // After a native password reset, Auth uses the real contact email.
      // Resolve it privately on the server and verify the password there.
      credential = await _signInMigratedAccount(cleanCampusId, password);
    }

    final User? user = credential.user;

    if (user == null) {
      throw CampusAuthException('Unable to sign in.');
    }

    try {
      final document = await _firestore.collection('users').doc(user.uid).get();

      Map<String, dynamic>? profile = document.data();

      if (!document.exists || profile == null) {
        await _auth.signOut();

        throw CampusAuthException('Your CASLMS profile could not be found.');
      }

      final String storedCampusId = (profile['universityId'] ?? '')
          .toString()
          .trim();

      if (storedCampusId != cleanCampusId) {
        await _auth.signOut();

        throw CampusAuthException('Campus ID does not match this account.');
      }

      profile = await _synchronizeVerifiedEmail(profile);

      final String role = (profile['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      const Set<String> allowedRoles = {'student', 'instructor', 'admin'};

      if (!allowedRoles.contains(role)) {
        await _auth.signOut();

        throw CampusAuthException('Your account has an invalid role.');
      }

      final String status = (profile['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // Pending instructors remain authenticated so
      // SessionGate can display the approval screen.
      if (role == 'instructor' && status == 'pending') {
        return CampusAuthResult(
          user: user,
          profile: {...profile, 'uid': user.uid},
        );
      }

      if (role == 'student' &&
          profile['emailVerificationRequired'] == true &&
          (status == 'pending_verification' ||
              (status == 'active' && !user.emailVerified))) {
        return CampusAuthResult(
          user: user,
          profile: {...profile, 'uid': user.uid},
        );
      }

      if (status == 'denied') {
        await _auth.signOut();

        final String reason = (profile['denialReason'] ?? '').toString().trim();

        throw CampusAuthException(
          reason.isEmpty
              ? 'Your instructor application was denied.'
              : 'Your instructor application was denied: $reason',
        );
      }

      if (status == 'suspended') {
        await _auth.signOut();

        throw CampusAuthException('Your CASLMS account is suspended.');
      }

      if (status != 'active') {
        await _auth.signOut();

        throw CampusAuthException('Your CASLMS account is currently inactive.');
      }

      unawaited(
        ActivityLogService(
          auth: _auth,
          firestore: _firestore,
        ).session('login', profile: profile),
      );

      // Updating login time should not prevent a valid
      // user from entering if this optional write fails.
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Login remains successful.
      }

      return CampusAuthResult(
        user: user,
        profile: {...profile, 'uid': user.uid},
      );
    } on CampusAuthException {
      rethrow;
    } catch (error) {
      await _auth.signOut();

      throw CampusAuthException('Unable to load your CASLMS account: $error');
    }
  }

  Future<UserCredential> _signInMigratedAccount(
    String campusId,
    String password,
  ) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token == null || token.isEmpty) {
        throw CampusAuthException('CASLMS could not verify this application.');
      }
      final response = await Supabase.instance.client.functions.invoke(
        'campus-login',
        headers: {'X-Firebase-AppCheck': token},
        body: {'campusId': campusId, 'password': password},
      );
      final data = response.data;
      if (data is! Map ||
          data['customToken'] is! String ||
          (data['customToken'] as String).isEmpty) {
        throw CampusAuthException('Unable to sign in. Please try again.');
      }
      return await _auth.signInWithCustomToken(data['customToken'] as String);
    } on CampusAuthException {
      rethrow;
    } on FunctionException catch (error) {
      if (error.status == 400) {
        throw CampusAuthException('Incorrect ID number or password.');
      }
      if (error.status == 429) {
        throw CampusAuthException(
          'Too many login attempts. Please try again later.',
        );
      }
      throw CampusAuthException(
        'Unable to sign in right now. Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw CampusAuthException(_firebaseMessage(error));
    } catch (_) {
      throw CampusAuthException(
        'Unable to sign in right now. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final document = await _firestore.collection('users').doc(user.uid).get();

    final Map<String, dynamic>? profile = document.data();

    if (!document.exists || profile == null) {
      return null;
    }

    return {...profile, 'uid': user.uid};
  }

  Stream<Map<String, dynamic>?> watchProfile(String userId) {
    // A live read must not renew Auth tokens or perform profile writes.
    // Synchronization is explicit after verification and during sign-in.
    return _firestore.collection('users').doc(userId).snapshots().map((
      document,
    ) {
      final Map<String, dynamic>? profile = document.data();

      if (!document.exists || profile == null) {
        return null;
      }

      return {...profile, 'uid': document.id};
    });
  }

  Future<Map<String, dynamic>> _synchronizeVerifiedEmail(
    Map<String, dynamic> profile,
  ) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? '';
    if (user == null ||
        (profile['uid'] != null && profile['uid'] != user.uid) ||
        profile['role'] != 'student' ||
        profile['status'] != 'active' ||
        !user.emailVerified ||
        email.isEmpty ||
        email.endsWith('@caslms.app') ||
        (profile['email'] == email && profile['authEmail'] == email)) {
      return profile;
    }
    await _registrationRequest({'action': 'sync_verified_email'});
    return {
      ...profile,
      'email': email,
      'authEmail': email,
      'emailVerificationRequired': true,
    };
  }

  /// Called after a verification link, on profile reload or the next login.
  /// It recovers an interrupted email update without changing the campus ID.
  Future<void> checkVerifiedProfileEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw CampusAuthException('Please sign in again.');
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    final profile = await getCurrentProfile();
    if (profile == null) {
      throw CampusAuthException('Your profile is unavailable.');
    }
    await _synchronizeVerifiedEmail(profile);
  }

  Future<void> signOut() async {
    await ActivityLogService(auth: _auth, firestore: _firestore).signOut();
  }

  Future<void> _registrationRequest(Map<String, dynamic> body) async {
    final user = _auth.currentUser;
    if (user == null) throw CampusAuthException('Please sign in again.');
    final idToken = await user.getIdToken(true);
    final appCheck = await FirebaseAppCheck.instance.getToken(true);
    if (idToken == null || appCheck == null || appCheck.isEmpty) {
      throw CampusAuthException('CASLMS could not verify this application.');
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'student-registration',
        headers: {
          'Authorization': 'Bearer $idToken',
          'X-Firebase-AppCheck': appCheck,
        },
        body: body,
      );
      if (response.data is! Map || response.data['success'] != true) {
        throw CampusAuthException('Unable to complete registration.');
      }
    } on FunctionException catch (error) {
      throw CampusAuthException(
        error.details is Map
            ? (error.details['error'] ?? 'Unable to complete registration.')
                  .toString()
            : 'Unable to complete registration. Please retry.',
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw CampusAuthException('Please sign in again.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw CampusAuthException(_firebaseMessage(error));
    }
  }

  Future<bool> checkStudentEmailVerification() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return false;
    await user.getIdToken(true);
    await _registrationRequest({'action': 'activate'});
    return true;
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This campus or faculty ID is already registered.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'invalid-email':
        return 'The ID number could not be processed.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect ID number or password.';

      case 'user-disabled':
        return 'This account is disabled. If you registered as an instructor, your application may have been denied.';

      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}

class CampusAuthResult {
  CampusAuthResult({required this.user, required this.profile});

  final User user;
  final Map<String, dynamic> profile;

  String get role => (profile['role'] ?? '').toString().trim().toLowerCase();

  String get status =>
      (profile['status'] ?? '').toString().trim().toLowerCase();

  String get name => (profile['name'] ?? '').toString();

  String get campusId => (profile['universityId'] ?? '').toString();

  String get email => (profile['email'] ?? '').toString();

  String get department => (profile['department'] ?? '').toString();

  String get course => (profile['course'] ?? '').toString();
}

class CampusAuthException implements Exception {
  CampusAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
