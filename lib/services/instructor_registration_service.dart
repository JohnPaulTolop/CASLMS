import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User;

import 'campus_auth_service.dart';

class FacultyIdDocument {
  const FacultyIdDocument({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  int get size => bytes.length;

  double get sizeInMegabytes =>
      bytes.length / (1024 * 1024);
}

class InstructorRegistrationService {
  InstructorRegistrationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
    CampusAuthService? campusAuthService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore =
            firestore ?? FirebaseFirestore.instance,
        _supabase =
            supabase ?? Supabase.instance.client,
        _campusAuthService =
            campusAuthService ?? CampusAuthService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;
  final CampusAuthService _campusAuthService;

  static const int maximumFileBytes =
      5 * 1024 * 1024;

  Future<FacultyIdDocument?>
      pickFacultyIdDocument() async {
    final PlatformFile? file =
        await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
      ],
    );

    if (file == null) {
      return null;
    }

    final Uint8List bytes;

    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw CampusAuthException(
        'Unable to read the selected faculty ID file.',
      );
    }

    if (bytes.isEmpty) {
      throw CampusAuthException(
        'The selected faculty ID file is empty.',
      );
    }

    if (bytes.length >
        maximumFileBytes) {
      throw CampusAuthException(
        'Faculty ID must be 5 MB or smaller.',
      );
    }

    final String extension =
        (file.extension ?? '')
            .trim()
            .toLowerCase();

    final String? mimeType =
        _mimeTypeForExtension(extension);

    if (mimeType == null) {
      throw CampusAuthException(
        'Faculty ID must be a JPG, PNG, WEBP, or PDF file.',
      );
    }

    return FacultyIdDocument(
      name: file.name,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  Future<CampusAuthResult>
      registerInstructor({
    required String fullName,
    required String email,
    required String campusId,
    required String department,
    required String position,
    required String password,
    required FacultyIdDocument facultyId,
  }) async {
    final String cleanName =
        fullName.trim();

    final String cleanEmail =
        email.trim().toLowerCase();

    final String cleanCampusId =
        _campusAuthService
            .normalizeCampusId(campusId);

    final String cleanDepartment =
        department.trim();

    final String cleanPosition =
        position.trim();

    if (cleanName.length < 2) {
      throw CampusAuthException(
        'Enter your complete name.',
      );
    }

    if (!_campusAuthService
        .isValidEmail(cleanEmail)) {
      throw CampusAuthException(
        'Enter a valid email address.',
      );
    }

    if (!_campusAuthService
        .isValidCampusId(cleanCampusId)) {
      throw CampusAuthException(
        'Enter a valid faculty ID number.',
      );
    }

    if (cleanDepartment.isEmpty) {
      throw CampusAuthException(
        'Department is required.',
      );
    }

    if (cleanPosition.isEmpty) {
      throw CampusAuthException(
        'Position or program is required.',
      );
    }

    if (password.length < 6) {
      throw CampusAuthException(
        'Password must contain at least 6 characters.',
      );
    }

    if (facultyId.bytes.isEmpty ||
        facultyId.bytes.length >
            maximumFileBytes) {
      throw CampusAuthException(
        'Faculty ID must be 5 MB or smaller.',
      );
    }

    final String authEmail =
        _campusAuthService
            .firebaseEmailForCampusId(
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

    final User? user = credential.user;

    if (user == null) {
      throw CampusAuthException(
        'Unable to create the instructor account.',
      );
    }

    try {
      await user.updateDisplayName(
        cleanName,
      );

      final String? firebaseToken =
          await user.getIdToken(true);

      if (firebaseToken == null ||
          firebaseToken.isEmpty) {
        throw CampusAuthException(
          'Unable to verify the instructor account.',
        );
      }

      final functionResponse =
          await _supabase.functions.invoke(
        'instructor-approval',
        headers: {
          'Authorization':
              'Bearer $firebaseToken',
        },
        body: {
          'action': 'submit',
          'fullName': cleanName,
          'email': cleanEmail,
          'campusId': cleanCampusId,
          'department':
              cleanDepartment,

          // Stored as "course" for compatibility
          // with your existing user profiles.
          'course': cleanPosition,

          'facultyIdFileName':
              facultyId.name,
          'facultyIdMimeType':
              facultyId.mimeType,
          'facultyIdBase64':
              base64Encode(
            facultyId.bytes,
          ),
        },
      );

      final dynamic data =
          functionResponse.data;

      if (data is! Map) {
        throw CampusAuthException(
          'The registration server returned an invalid response.',
        );
      }

      if (data['success'] != true) {
        throw CampusAuthException(
          _messageFromResponse(
            data,
          ),
        );
      }

      final Map<String, dynamic>
          profile = {
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'universityId':
            cleanCampusId,
        'authEmail': authEmail,
        'department':
            cleanDepartment,
        'course': cleanPosition,
        'role': 'instructor',
        'status': 'pending',
        'approvalStatus':
            'pending',
      };

      return CampusAuthResult(
        user: user,
        profile: profile,
      );
    } catch (error) {
      // A network error could happen after the
      // server successfully saves the request.
      // Check Firestore before deleting the user.
      final Map<String, dynamic>?
          existingProfile =
          await _loadProfileSafely(
        user.uid,
      );

      final String existingStatus =
          (existingProfile?['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      final String existingRole =
          (existingProfile?['role'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (existingStatus == 'pending' &&
          existingRole == 'instructor') {
        return CampusAuthResult(
          user: user,
          profile: {
            ...existingProfile!,
            'uid': user.uid,
          },
        );
      }

      try {
        await user.delete();
      } catch (_) {
        // Keep the original registration error.
      }

      if (error
          is CampusAuthException) {
        rethrow;
      }

      if (error is FunctionException) {
        throw CampusAuthException(
          _messageFromResponse(
            error.details,
          ),
        );
      }

      throw CampusAuthException(
        'Unable to submit the instructor application: $error',
      );
    }
  }

  Future<Map<String, dynamic>?>
      _loadProfileSafely(
    String userId,
  ) async {
    try {
      final document =
          await _firestore
              .collection('users')
              .doc(userId)
              .get();

      return document.data();
    } catch (_) {
      return null;
    }
  }

  String? _mimeTypeForExtension(
    String extension,
  ) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'pdf':
        return 'application/pdf';

      default:
        return null;
    }
  }

  String _messageFromResponse(
    dynamic value,
  ) {
    if (value is Map) {
      final String message =
          (value['error'] ??
                  value['message'] ??
                  '')
              .toString()
              .trim();

      if (message.isNotEmpty) {
        return message;
      }
    }

    final String text =
        value?.toString().trim() ?? '';

    if (text.isNotEmpty &&
        text != 'null') {
      return text;
    }

    return 'Unable to submit the instructor application.';
  }

  String _firebaseMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This faculty ID is already registered.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'invalid-email':
        return 'The faculty ID could not be processed.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      default:
        return error.message ??
            'Unable to create the instructor account.';
    }
  }
}