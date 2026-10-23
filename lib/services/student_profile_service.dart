import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentProfileService {
  StudentProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> save({
    required String displayName,
    required int yearLevel,
  }) async {
    final name = displayName.trim();
    if (name.length < 2 || name.length > 80 || yearLevel < 1 || yearLevel > 4) {
      throw const StudentProfileException(
        'Enter a display name and select your year level.',
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const StudentProfileException('Please sign in again.');
    }
    // Preserve school identity, course, department, role and verified email.
    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      'displayName': name,
      'yearLevel': yearLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await user.updateDisplayName(name);
    } on FirebaseAuthException {
      // The existing application reads names from Firestore.
    }
  }

  Future<void> requestEmailChange({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail) ||
        cleanEmail.endsWith('@caslms.app')) {
      throw const StudentProfileException(
        'Enter a valid personal email address.',
      );
    }
    if (password.isEmpty) {
      throw const StudentProfileException('Enter your current password.');
    }
    final user = _auth.currentUser;
    final currentEmail = user?.email;
    if (user == null || currentEmail == null) {
      throw const StudentProfileException('Please sign in again.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: currentEmail, password: password),
    );
    // Firebase applies the change only after ownership of the new email is
    // verified. The unverified address is never written to the profile.
    await user.verifyBeforeUpdateEmail(cleanEmail);
  }
}

class StudentProfileException implements Exception {
  const StudentProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}
