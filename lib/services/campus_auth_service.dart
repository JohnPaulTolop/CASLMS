import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CampusAuthService {
  CampusAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore =
            firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _internalDomain =
      'caslms.app';

  User? get currentUser =>
      _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  String normalizeCampusId(
    String campusId,
  ) {
    return campusId.trim().replaceAll(
          RegExp(r'\s+'),
          '',
        );
  }

  bool isValidCampusId(
    String campusId,
  ) {
    final String id =
        normalizeCampusId(campusId);

    return RegExp(
      r'^\d{5,12}$',
    ).hasMatch(id);
  }

  bool isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(
      email.trim(),
    );
  }

  String firebaseEmailForCampusId(
    String campusId,
  ) {
    final String id =
        normalizeCampusId(campusId);

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
    final String cleanName =
        fullName.trim();

    final String cleanEmail =
        email.trim().toLowerCase();

    final String cleanCampusId =
        normalizeCampusId(campusId);

    final String cleanDepartment =
        department.trim();

    final String cleanCourse =
        course.trim();

    if (cleanName.length < 2) {
      throw CampusAuthException(
        'Enter your complete name.',
      );
    }

    if (!isValidEmail(cleanEmail)) {
      throw CampusAuthException(
        'Enter a valid email address.',
      );
    }

    if (!isValidCampusId(
      cleanCampusId,
    )) {
      throw CampusAuthException(
        'Enter a valid campus ID number.',
      );
    }

    if (cleanDepartment.isEmpty) {
      throw CampusAuthException(
        'Department is required.',
      );
    }

    if (cleanCourse.isEmpty) {
      throw CampusAuthException(
        'Course is required.',
      );
    }

    if (password.length < 6) {
      throw CampusAuthException(
        'Password must contain at least 6 characters.',
      );
    }

    final String authEmail =
        firebaseEmailForCampusId(
      cleanCampusId,
    );

    UserCredential credential;

    try {
      credential =
          await _auth
              .createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw CampusAuthException(
        _firebaseMessage(error),
      );
    }

    final User? user =
        credential.user;

    if (user == null) {
      throw CampusAuthException(
        'Unable to create your account.',
      );
    }

    try {
      await user.updateDisplayName(
        cleanName,
      );

      final Map<String, dynamic> profile = {
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'universityId':
            cleanCampusId,
        'authEmail': authEmail,
        'department':
            cleanDepartment,
        'course': cleanCourse,
        'role': 'student',
        'status': 'active',
        'approvalStatus':
            'not_required',
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
        'lastLoginAt':
            FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profile);

      return CampusAuthResult(
        user: user,
        profile: {
          ...profile,
          'createdAt':
              DateTime.now(),
          'updatedAt':
              DateTime.now(),
          'lastLoginAt':
              DateTime.now(),
        },
      );
    } catch (error) {
      try {
        await user.delete();
      } catch (_) {
        // Preserve the original profile error.
      }

      throw CampusAuthException(
        'Unable to create your CASLMS profile: $error',
      );
    }
  }

  Future<CampusAuthResult> signIn({
    required String campusId,
    required String password,
  }) async {
    final String cleanCampusId =
        normalizeCampusId(campusId);

    if (!isValidCampusId(
      cleanCampusId,
    )) {
      throw CampusAuthException(
        'Enter a valid campus ID number.',
      );
    }

    if (password.isEmpty) {
      throw CampusAuthException(
        'Enter your password.',
      );
    }

    final String authEmail =
        firebaseEmailForCampusId(
      cleanCampusId,
    );

    UserCredential credential;

    try {
      credential =
          await _auth
              .signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw CampusAuthException(
        _firebaseMessage(error),
      );
    }

    final User? user =
        credential.user;

    if (user == null) {
      throw CampusAuthException(
        'Unable to sign in.',
      );
    }

    try {
      final document =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>?
          profile = document.data();

      if (!document.exists ||
          profile == null) {
        await _auth.signOut();

        throw CampusAuthException(
          'Your CASLMS profile could not be found.',
        );
      }

      final String storedCampusId =
          (profile['universityId'] ?? '')
              .toString()
              .trim();

      if (storedCampusId !=
          cleanCampusId) {
        await _auth.signOut();

        throw CampusAuthException(
          'Campus ID does not match this account.',
        );
      }

      final String role =
          (profile['role'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      const Set<String> allowedRoles = {
        'student',
        'instructor',
        'admin',
      };

      if (!allowedRoles.contains(role)) {
        await _auth.signOut();

        throw CampusAuthException(
          'Your account has an invalid role.',
        );
      }

      final String status =
          (profile['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      // Pending instructors remain authenticated so
      // SessionGate can display the approval screen.
      if (role == 'instructor' &&
          status == 'pending') {
        return CampusAuthResult(
          user: user,
          profile: {
            ...profile,
            'uid': user.uid,
          },
        );
      }

      if (status == 'denied') {
        await _auth.signOut();

        final String reason =
            (profile['denialReason'] ?? '')
                .toString()
                .trim();

        throw CampusAuthException(
          reason.isEmpty
              ? 'Your instructor application was denied.'
              : 'Your instructor application was denied: $reason',
        );
      }

      if (status == 'suspended') {
        await _auth.signOut();

        throw CampusAuthException(
          'Your CASLMS account is suspended.',
        );
      }

      if (status != 'active') {
        await _auth.signOut();

        throw CampusAuthException(
          'Your CASLMS account is currently inactive.',
        );
      }

      // Updating login time should not prevent a valid
      // user from entering if this optional write fails.
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'lastLoginAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Login remains successful.
      }

      return CampusAuthResult(
        user: user,
        profile: {
          ...profile,
          'uid': user.uid,
        },
      );
    } on CampusAuthException {
      rethrow;
    } catch (error) {
      await _auth.signOut();

      throw CampusAuthException(
        'Unable to load your CASLMS account: $error',
      );
    }
  }

  Future<Map<String, dynamic>?>
      getCurrentProfile() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final document =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

    final Map<String, dynamic>?
        profile = document.data();

    if (!document.exists ||
        profile == null) {
      return null;
    }

    return {
      ...profile,
      'uid': user.uid,
    };
  }

  Stream<Map<String, dynamic>?>
      watchProfile(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map(
      (document) {
        final Map<String, dynamic>?
            profile = document.data();

        if (!document.exists ||
            profile == null) {
          return null;
        }

        return {
          ...profile,
          'uid': document.id,
        };
      },
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _firebaseMessage(
    FirebaseAuthException error,
  ) {
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
        return error.message ??
            'Authentication failed.';
    }
  }
}

class CampusAuthResult {
  CampusAuthResult({
    required this.user,
    required this.profile,
  });

  final User user;
  final Map<String, dynamic> profile;

  String get role =>
      (profile['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  String get status =>
      (profile['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  String get name =>
      (profile['name'] ?? '')
          .toString();

  String get campusId =>
      (profile['universityId'] ?? '')
          .toString();

  String get email =>
      (profile['email'] ?? '')
          .toString();

  String get department =>
      (profile['department'] ?? '')
          .toString();

  String get course =>
      (profile['course'] ?? '')
          .toString();
}

class CampusAuthException
    implements Exception {
  CampusAuthException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}