import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InstructorCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _classCodeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // CURRENT INSTRUCTOR PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getCurrentInstructorProfile() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw InstructorCourseServiceException(
          'No instructor is currently logged in.',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists || document.data() == null) {
        throw InstructorCourseServiceException(
          'Instructor profile could not be found.',
        );
      }

      final Map<String, dynamic> data = document.data()!;

      final String role = (data['role'] ?? '').toString().trim().toLowerCase();

      if (role != 'instructor') {
        throw InstructorCourseServiceException(
          'Only instructors can manage courses.',
        );
      }

      final String status = (data['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'active') {
        throw InstructorCourseServiceException(
          'This instructor account is not active.',
        );
      }

      return {...data, 'id': document.id, 'uid': document.id};
    } on InstructorCourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ?? 'Unable to load instructor profile.',
      );
    } catch (_) {
      throw InstructorCourseServiceException(
        'Unable to load instructor profile.',
      );
    }
  }

  // ============================================================
  // NORMALIZE COURSE CODE
  //
  // "it 301"  -> IT301
  // "IT-301"  -> IT301
  // ============================================================

  String _normalizeCourseCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  // ============================================================
  // RANDOM CLASS CODE PART
  // ============================================================

  String _generateRandomPart({int length = 5}) {
    final Random random = Random.secure();

    return List<String>.generate(length, (_) {
      return _classCodeCharacters[random.nextInt(_classCodeCharacters.length)];
    }).join();
  }

  // ============================================================
  // CHECK IF CLASS CODE EXISTS
  // ============================================================

  Future<bool> _classCodeExists(String classCode) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('courses')
        .where('classCode', isEqualTo: classCode)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ============================================================
  // GENERATE UNIQUE CLASS CODE
  //
  // Example:
  //
  // IT301-X7K9Q
  // IT302-P8M4R
  // CS101-W2N6K
  // ============================================================

  Future<String> generateUniqueClassCode({required String courseCode}) async {
    final String prefix = _normalizeCourseCode(courseCode);

    if (prefix.isEmpty) {
      throw InstructorCourseServiceException('Course code is required.');
    }

    for (int attempt = 0; attempt < 25; attempt++) {
      final String candidate = '$prefix-${_generateRandomPart()}';

      final bool exists = await _classCodeExists(candidate);

      if (!exists) {
        return candidate;
      }
    }

    throw InstructorCourseServiceException(
      'Unable to generate a unique class code. Please try again.',
    );
  }

  // ============================================================
  // CHECK DUPLICATE ACTIVE COURSE CODE
  // ============================================================

  Future<bool> _courseCodeAlreadyExists({
    required String instructorId,
    required String courseCode,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('courses')
        .where('instructorId', isEqualTo: instructorId)
        .get();

    final String normalizedCode = _normalizeCourseCode(courseCode);

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String existingCode = _normalizeCourseCode(
        (data['code'] ?? '').toString(),
      );

      final String status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (existingCode == normalizedCode && status == 'active') {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CREATE COURSE
  // ============================================================

  Future<Map<String, dynamic>> createCourse({
    required String code,
    required String title,
    required String description,
    required String semester,
    required String academicYear,
  }) async {
    try {
      final Map<String, dynamic> instructor =
          await getCurrentInstructorProfile();

      final String instructorId = (instructor['id'] ?? '').toString().trim();

      final String instructorName =
          (instructor['name'] ?? instructor['displayName'] ?? 'Instructor')
              .toString()
              .trim();

      final String cleanCode = _normalizeCourseCode(code);

      final String cleanTitle = title.trim();

      final String cleanDescription = description.trim();

      final String cleanSemester = semester.trim();

      final String cleanAcademicYear = academicYear.trim();

      if (instructorId.isEmpty) {
        throw InstructorCourseServiceException('Instructor ID is missing.');
      }

      if (cleanCode.isEmpty) {
        throw InstructorCourseServiceException('Course code is required.');
      }

      if (cleanTitle.isEmpty) {
        throw InstructorCourseServiceException('Course title is required.');
      }

      if (cleanDescription.isEmpty) {
        throw InstructorCourseServiceException(
          'Course description is required.',
        );
      }

      if (cleanSemester.isEmpty) {
        throw InstructorCourseServiceException('Semester is required.');
      }

      if (cleanAcademicYear.isEmpty) {
        throw InstructorCourseServiceException('Academic year is required.');
      }

      // ----------------------------------------------------------
      // Prevent duplicate active course code for same instructor
      // ----------------------------------------------------------

      final bool duplicate = await _courseCodeAlreadyExists(
        instructorId: instructorId,
        courseCode: cleanCode,
      );

      if (duplicate) {
        throw InstructorCourseServiceException(
          'You already have an active course with code $cleanCode.',
        );
      }

      // ----------------------------------------------------------
      // Generate dynamic unique class code
      // ----------------------------------------------------------

      final String classCode = await generateUniqueClassCode(
        courseCode: cleanCode,
      );

      // ----------------------------------------------------------
      // Create Firestore document
      // ----------------------------------------------------------

      final DocumentReference<Map<String, dynamic>> courseReference = _firestore
          .collection('courses')
          .doc();

      await courseReference.set({
        'academicYear': cleanAcademicYear,

        'classCode': classCode,

        'code': cleanCode,

        'createdAt': FieldValue.serverTimestamp(),

        'description': cleanDescription,

        'instructorId': instructorId,

        'instructorName': instructorName,

        'semester': cleanSemester,

        'status': 'active',

        'title': cleanTitle,

        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': courseReference.id,

        'courseId': courseReference.id,

        'academicYear': cleanAcademicYear,

        'classCode': classCode,

        'code': cleanCode,

        'description': cleanDescription,

        'instructorId': instructorId,

        'instructorName': instructorName,

        'semester': cleanSemester,

        'status': 'active',

        'title': cleanTitle,
      };
    } on InstructorCourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ?? 'Unable to create course.',
      );
    } catch (_) {
      throw InstructorCourseServiceException('Unable to create course.');
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR ACTIVE COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstructorCourses() async {
    try {
      final Map<String, dynamic> instructor =
          await getCurrentInstructorProfile();

      final String instructorId = (instructor['id'] ?? '').toString().trim();

      if (instructorId.isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> courseSnapshot =
          await _firestore
              .collection('courses')
              .where('instructorId', isEqualTo: instructorId)
              .get();

      final List<Map<String, dynamic>> courses = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> courseDocument
          in courseSnapshot.docs) {
        final Map<String, dynamic> course = courseDocument.data();

        final String status = (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status != 'active') {
          continue;
        }

        // --------------------------------------------------------
        // Count real active students
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
            await _firestore
                .collection('enrollments')
                .where('courseId', isEqualTo: courseDocument.id)
                .get();

        int studentCount = 0;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> enrollment
            in enrollmentSnapshot.docs) {
          final String enrollmentStatus = (enrollment.data()['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (enrollmentStatus == 'active') {
            studentCount++;
          }
        }

        courses.add({
          ...course,

          'id': courseDocument.id,

          'courseId': courseDocument.id,

          'studentCount': studentCount,
        });
      }

      // ----------------------------------------------------------
      // Sort by course code
      // ----------------------------------------------------------

      courses.sort((a, b) {
        final String codeA = (a['code'] ?? '').toString().toUpperCase();

        final String codeB = (b['code'] ?? '').toString().toUpperCase();

        return codeA.compareTo(codeB);
      });

      return courses;
    } on InstructorCourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ?? 'Unable to load instructor courses.',
      );
    } catch (_) {
      throw InstructorCourseServiceException(
        'Unable to load instructor courses.',
      );
    }
  }

  // ============================================================
  // GET COURSE BY ID
  // ============================================================

  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      final String cleanCourseId = courseId.trim();

      if (cleanCourseId.isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('courses')
          .doc(cleanCourseId)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      return {...document.data()!, 'id': document.id, 'courseId': document.id};
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ?? 'Unable to load course.',
      );
    } catch (_) {
      throw InstructorCourseServiceException('Unable to load course.');
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class InstructorCourseServiceException implements Exception {
  final String message;

  InstructorCourseServiceException(this.message);

  @override
  String toString() => message;
}
