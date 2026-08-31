import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CampusAuthService {
  CampusAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _internalDomain = 'caslms.app';

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ============================================================
  // NORMALIZE CAMPUS ID
  // ============================================================

  String normalizeCampusId(
    String campusId,
  ) {
    return campusId.trim().replaceAll(
          RegExp(r'\s+'),
          '',
        );
  }

  // ============================================================
  // VALIDATE CAMPUS ID
  // ============================================================

  bool isValidCampusId(
    String campusId,
  ) {
    final String id =
        normalizeCampusId(campusId);

    return RegExp(
      r'^\d{5,12}$',
    ).hasMatch(id);
  }

  // ============================================================
  // VALIDATE EMAIL
  // ============================================================

  bool isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(
      email.trim(),
    );
  }

  // ============================================================
  // INTERNAL FIREBASE AUTH EMAIL
  //
  // User enters:
  // 231577
  //
  // Firebase internally uses:
  // 231577@caslms.app
  // ============================================================

  String firebaseEmailForCampusId(
    String campusId,
  ) {
    final String id =
        normalizeCampusId(campusId);

    return '$id@$_internalDomain';
  }

  // ============================================================
  // STUDENT SIGN UP
  // ============================================================

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

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (cleanName.isEmpty) {
      throw CampusAuthException(
        'Full name is required.',
      );
    }

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

    if (!isValidCampusId(cleanCampusId)) {
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

    // ==========================================================
    // INTERNAL FIREBASE EMAIL
    // ==========================================================

    final String authEmail =
        firebaseEmailForCampusId(
      cleanCampusId,
    );

    UserCredential credential;

    try {
      credential =
          await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw CampusAuthException(
        _firebaseMessage(e),
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
      // ========================================================
      // FIREBASE DISPLAY NAME
      // ========================================================

      await user.updateDisplayName(
        cleanName,
      );

      // ========================================================
      // FIRESTORE USER PROFILE
      // ========================================================

      final Map<String, dynamic> profile = {
        'uid': user.uid,

        'name': cleanName,

        // Real email entered by student.
        'email': cleanEmail,

        // Campus / University ID.
        'universityId': cleanCampusId,

        // Hidden Firebase Authentication email.
        'authEmail': authEmail,

        'department': cleanDepartment,

        'course': cleanCourse,

        // Public registration creates students only.
        'role': 'student',

        'status': 'active',

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

      // IMPORTANT:
      //
      // createUserWithEmailAndPassword automatically
      // keeps the new Firebase user signed in.
      //
      // We intentionally DO NOT sign out here.

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
    } catch (e) {
      // If Firestore profile creation fails,
      // remove the Firebase Auth account too so
      // we don't leave an incomplete account.

      try {
        await user.delete();
      } catch (_) {}

      throw CampusAuthException(
        'Unable to create your CASLMS profile: $e',
      );
    }
  }

  // ============================================================
  // LOGIN USING CAMPUS ID + PASSWORD
  // ============================================================

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

    // ==========================================================
    // CONVERT CAMPUS ID → FIREBASE EMAIL
    // ==========================================================

    final String authEmail =
        firebaseEmailForCampusId(
      cleanCampusId,
    );

    UserCredential credential;

    try {
      credential =
          await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw CampusAuthException(
        _firebaseMessage(e),
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
      // ========================================================
      // LOAD FIRESTORE PROFILE
      // ========================================================

      final DocumentSnapshot<
          Map<String, dynamic>> profileDocument =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      if (!profileDocument.exists ||
          profileDocument.data() == null) {
        await _auth.signOut();

        throw CampusAuthException(
          'Your CASLMS profile could not be found.',
        );
      }

      final Map<String, dynamic> profile =
          profileDocument.data()!;

      // ========================================================
      // CHECK CAMPUS ID
      // ========================================================

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

      // ========================================================
      // CHECK ACCOUNT STATUS
      // ========================================================

      final String status =
          (profile['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (status != 'active') {
        await _auth.signOut();

        throw CampusAuthException(
          'Your CASLMS account is currently inactive.',
        );
      }

      // ========================================================
      // CHECK ROLE
      // ========================================================

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

      if (!allowedRoles.contains(
        role,
      )) {
        await _auth.signOut();

        throw CampusAuthException(
          'Your account has an invalid role.',
        );
      }

      // ========================================================
      // UPDATE LAST LOGIN
      // ========================================================

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'lastLoginAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      return CampusAuthResult(
        user: user,
        profile: {
          ...profile,
          'uid': user.uid,
        },
      );
    } on CampusAuthException {
      rethrow;
    } catch (e) {
      await _auth.signOut();

      throw CampusAuthException(
        'Unable to load your CASLMS account: $e',
      );
    }
  }

  // ============================================================
  // GET CURRENT PROFILE
  // ============================================================

  Future<Map<String, dynamic>?>
      getCurrentProfile() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final DocumentSnapshot<
        Map<String, dynamic>> document =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

    if (!document.exists ||
        document.data() == null) {
      return null;
    }

    return {
      ...document.data()!,
      'uid': user.uid,
    };
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ============================================================
  // FIREBASE AUTH ERROR MESSAGES
  // ============================================================

  String _firebaseMessage(
    FirebaseAuthException e,
  ) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This campus ID is already registered.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'invalid-email':
        return 'The campus ID could not be processed.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect ID number or password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      default:
        return e.message ??
            'Authentication failed.';
    }
  }
}

// ============================================================
// AUTH RESULT
// ============================================================

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

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class CampusAuthException
    implements Exception {
  CampusAuthException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}