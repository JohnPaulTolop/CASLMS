import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InstructorCourseService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  static const String _classCodeCharacters =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String? get currentUserId =>
      _auth.currentUser?.uid;

  // ============================================================
  // CURRENT INSTRUCTOR PROFILE
  // ============================================================

  Future<Map<String, dynamic>>
      getCurrentInstructorProfile() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw InstructorCourseServiceException(
        'No instructor is currently logged in.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        document =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

    if (!document.exists ||
        document.data() == null) {
      throw InstructorCourseServiceException(
        'Instructor profile could not be found.',
      );
    }

    final Map<String, dynamic> data =
        document.data()!;

    final String role =
        (data['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (role != 'instructor') {
      throw InstructorCourseServiceException(
        'Only instructors can create courses.',
      );
    }

    final String status =
        (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

    if (status != 'active') {
      throw InstructorCourseServiceException(
        'This instructor account is not active.',
      );
    }

    return {
      ...data,
      'id': document.id,
      'uid': document.id,
    };
  }

  // ============================================================
  // NORMALIZE COURSE CODE
  // ============================================================

  String _normalizeCourseCode(
    String value,
  ) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(
          RegExp(
            r'[^A-Z0-9]',
          ),
          '',
        );
  }

  // ============================================================
  // GENERATE RANDOM CLASS CODE PART
  // ============================================================

  String _generateRandomPart({
    int length = 5,
  }) {
    final Random random =
        Random.secure();

    return List<String>.generate(
      length,
      (_) {
        return _classCodeCharacters[
            random.nextInt(
          _classCodeCharacters.length,
        )];
      },
    ).join();
  }

  // ============================================================
  // CHECK CLASS CODE
  // ============================================================

  Future<bool> _classCodeExists(
    String classCode,
  ) async {
    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _firestore
            .collection('courses')
            .where(
              'classCode',
              isEqualTo:
                  classCode,
            )
            .limit(1)
            .get();

    return snapshot.docs.isNotEmpty;
  }

  // ============================================================
  // GENERATE UNIQUE CLASS CODE
  //
  // Example:
  //
  // IT301-K7M4Q
  // CS101-P8X2N
  // ============================================================

  Future<String> generateUniqueClassCode({
    required String courseCode,
  }) async {
    final String prefix =
        _normalizeCourseCode(
      courseCode,
    );

    if (prefix.isEmpty) {
      throw InstructorCourseServiceException(
        'Course code is required before generating a class code.',
      );
    }

    for (int attempt = 0;
        attempt < 20;
        attempt++) {
      final String candidate =
          '$prefix-${_generateRandomPart()}';

      final bool exists =
          await _classCodeExists(
        candidate,
      );

      if (!exists) {
        return candidate;
      }
    }

    throw InstructorCourseServiceException(
      'Unable to generate a unique class code. Please try again.',
    );
  }

  // ============================================================
  // CHECK DUPLICATE COURSE CODE FOR SAME INSTRUCTOR
  // ============================================================

  Future<bool> _courseCodeAlreadyExists({
    required String instructorId,
    required String courseCode,
  }) async {
    final QuerySnapshot<Map<String, dynamic>>
        snapshot =
        await _firestore
            .collection('courses')
            .where(
              'instructorId',
              isEqualTo:
                  instructorId,
            )
            .get();

    final String normalized =
        _normalizeCourseCode(
      courseCode,
    );

    for (final document
        in snapshot.docs) {
      final String storedCode =
          _normalizeCourseCode(
        (document.data()['code'] ??
                '')
            .toString(),
      );

      final String status =
          (document.data()['status'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase();

      if (storedCode == normalized &&
          status == 'active') {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CREATE COURSE
  // ============================================================

  Future<Map<String, dynamic>>
      createCourse({
    required String code,
    required String title,
    required String description,
    required String semester,
    required String academicYear,
  }) async {
    try {
      final Map<String, dynamic>
          instructor =
          await getCurrentInstructorProfile();

      final String instructorId =
          (instructor['id'] ?? '')
              .toString();

      final String instructorName =
          (instructor['name'] ??
                  instructor['displayName'] ??
                  'Instructor')
              .toString()
              .trim();

      final String cleanCode =
          _normalizeCourseCode(
        code,
      );

      final String cleanTitle =
          title.trim();

      final String cleanDescription =
          description.trim();

      final String cleanSemester =
          semester.trim();

      final String cleanAcademicYear =
          academicYear.trim();

      if (cleanCode.isEmpty) {
        throw InstructorCourseServiceException(
          'Course code is required.',
        );
      }

      if (cleanTitle.isEmpty) {
        throw InstructorCourseServiceException(
          'Course title is required.',
        );
      }

      if (cleanDescription.isEmpty) {
        throw InstructorCourseServiceException(
          'Course description is required.',
        );
      }

      if (cleanSemester.isEmpty) {
        throw InstructorCourseServiceException(
          'Semester is required.',
        );
      }

      if (cleanAcademicYear.isEmpty) {
        throw InstructorCourseServiceException(
          'Academic year is required.',
        );
      }

      final bool duplicateCourse =
          await _courseCodeAlreadyExists(
        instructorId:
            instructorId,
        courseCode:
            cleanCode,
      );

      if (duplicateCourse) {
        throw InstructorCourseServiceException(
          'You already have an active course with code $cleanCode.',
        );
      }

      final String classCode =
          await generateUniqueClassCode(
        courseCode:
            cleanCode,
      );

      final DocumentReference<Map<String, dynamic>>
          document =
          _firestore
              .collection('courses')
              .doc();

      await document.set({
        'academicYear':
            cleanAcademicYear,

        'classCode':
            classCode,

        'code':
            cleanCode,

        'createdAt':
            FieldValue.serverTimestamp(),

        'description':
            cleanDescription,

        'instructorId':
            instructorId,

        'instructorName':
            instructorName,

        'semester':
            cleanSemester,

        'status':
            'active',

        'title':
            cleanTitle,

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      return {
        'id':
            document.id,

        'courseId':
            document.id,

        'academicYear':
            cleanAcademicYear,

        'classCode':
            classCode,

        'code':
            cleanCode,

        'description':
            cleanDescription,

        'instructorId':
            instructorId,

        'instructorName':
            instructorName,

        'semester':
            cleanSemester,

        'status':
            'active',

        'title':
            cleanTitle,
      };
    } on InstructorCourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ??
            'Unable to create course.',
      );
    } catch (_) {
      throw InstructorCourseServiceException(
        'Unable to create course.',
      );
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorCourses() async {
    try {
      final Map<String, dynamic>
          instructor =
          await getCurrentInstructorProfile();

      final String instructorId =
          (instructor['id'] ?? '')
              .toString();

      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection('courses')
              .where(
                'instructorId',
                isEqualTo:
                    instructorId,
              )
              .get();

      final List<Map<String, dynamic>>
          courses =
          [];

      for (final document
          in snapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status != 'active') {
          continue;
        }

        final QuerySnapshot<Map<String, dynamic>>
            enrollmentSnapshot =
            await _firestore
                .collection(
                  'enrollments',
                )
                .where(
                  'courseId',
                  isEqualTo:
                      document.id,
                )
                .get();

        int studentCount =
            0;

        for (final enrollment
            in enrollmentSnapshot.docs) {
          final String enrollmentStatus =
              (enrollment
                          .data()['status'] ??
                      '')
                  .toString()
                  .trim()
                  .toLowerCase();

          if (enrollmentStatus ==
              'active') {
            studentCount++;
          }
        }

        courses.add({
          ...data,

          'id':
              document.id,

          'courseId':
              document.id,

          'studentCount':
              studentCount,
        });
      }

      courses.sort(
        (a, b) {
          final String codeA =
              (a['code'] ?? '')
                  .toString();

          final String codeB =
              (b['code'] ?? '')
                  .toString();

          return codeA.compareTo(
            codeB,
          );
        },
      );

      return courses;
    } on InstructorCourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw InstructorCourseServiceException(
        e.message ??
            'Unable to load instructor courses.',
      );
    } catch (_) {
      throw InstructorCourseServiceException(
        'Unable to load instructor courses.',
      );
    }
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class InstructorCourseServiceException
    implements Exception {
  final String message;

  InstructorCourseServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}