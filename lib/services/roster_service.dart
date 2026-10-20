import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'enrollment_membership.dart';

class RosterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // GET CURRENT INSTRUCTOR PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> getCurrentInstructorProfile() async {
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

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        return null;
      }

      return {...data, 'id': document.id};
    } on FirebaseException catch (e) {
      throw RosterServiceException(
        e.message ?? 'Unable to load instructor profile.',
      );
    } catch (_) {
      throw RosterServiceException('Unable to load instructor profile.');
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstructorCourses() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw RosterServiceException('No instructor is currently logged in.');
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('courses')
          .where('instructorId', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> courses = [];

      for (final courseDocument in snapshot.docs) {
        final Map<String, dynamic> course = courseDocument.data();

        final String status = (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status != 'active') {
          continue;
        }

        // --------------------------------------------------------
        // COUNT ACTIVE STUDENTS
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
            await _firestore
                .collection('enrollments')
                .where('courseId', isEqualTo: courseDocument.id)
                .get();

        final studentCount = EnrollmentMembership.uniqueActive(
          enrollmentSnapshot.docs.map(
            (doc) => <String, dynamic>{...doc.data(), 'id': doc.id},
          ),
        ).length;

        courses.add({
          ...course,

          'id': courseDocument.id,

          'studentCount': studentCount,
        });
      }

      // ----------------------------------------------------------
      // SORT BY COURSE CODE
      // ----------------------------------------------------------

      courses.sort((a, b) {
        final String codeA = (a['code'] ?? '').toString().toLowerCase();

        final String codeB = (b['code'] ?? '').toString().toLowerCase();

        return codeA.compareTo(codeB);
      });

      return courses;
    } on RosterServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw RosterServiceException(
        e.message ?? 'Unable to load instructor courses.',
      );
    } catch (_) {
      throw RosterServiceException('Unable to load instructor courses.');
    }
  }

  // ============================================================
  // GET ONE COURSE
  // ============================================================

  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      if (courseId.trim().isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      if (!document.exists) {
        return null;
      }

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        return null;
      }

      return {...data, 'id': document.id};
    } on FirebaseException catch (e) {
      throw RosterServiceException(e.message ?? 'Unable to load course.');
    } catch (_) {
      throw RosterServiceException('Unable to load course.');
    }
  }

  // ============================================================
  // FIND CURRENT INSTRUCTOR COURSE BY TITLE
  //
  // This is only a temporary compatibility helper for old
  // Dashboard buttons that still pass a title instead of courseId.
  // ============================================================

  Future<Map<String, dynamic>?> findInstructorCourseByTitle(
    String title,
  ) async {
    if (title.trim().isEmpty) {
      return null;
    }

    final List<Map<String, dynamic>> courses = await getInstructorCourses();

    final String target = title.trim().toLowerCase();

    for (final course in courses) {
      final String courseTitle = (course['title'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (courseTitle == target) {
        return course;
      }
    }

    return null;
  }

  // ============================================================
  // GET ACTIVE STUDENTS ENROLLED IN COURSE
  // ============================================================

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> students = [];

      for (final enrollment in EnrollmentMembership.uniqueActive(
        enrollmentSnapshot.docs.map(
          (doc) => <String, dynamic>{...doc.data(), 'id': doc.id},
        ),
      )) {
        // --------------------------------------------------------
        // ACTIVE ENROLLMENTS ONLY
        // --------------------------------------------------------

        final String enrollmentStatus = (enrollment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        // --------------------------------------------------------
        // STUDENT UID
        // --------------------------------------------------------

        final String studentId = (enrollment['studentId'] ?? '')
            .toString()
            .trim();

        if (studentId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // LOAD USER DOCUMENT
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>> studentDocument =
            await _firestore.collection('users').doc(studentId).get();

        if (!studentDocument.exists) {
          continue;
        }

        final Map<String, dynamic>? student = studentDocument.data();

        if (student == null) {
          continue;
        }

        // --------------------------------------------------------
        // VERIFY ROLE
        // --------------------------------------------------------

        final String role = (student['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (role != 'student') {
          continue;
        }

        // --------------------------------------------------------
        // VERIFY USER STATUS
        // --------------------------------------------------------

        final String userStatus = (student['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        if (userStatus != 'active') {
          continue;
        }

        students.add({
          // ------------------------------------------------------
          // CANONICAL UID
          // ------------------------------------------------------

          'id': studentDocument.id,

          'studentId': studentDocument.id,

          // ------------------------------------------------------
          // PROFILE
          // ------------------------------------------------------
          'name': (student['name'] ?? enrollment['studentName'] ?? 'Student')
              .toString(),

          'email': (student['email'] ?? '').toString(),

          'universityId': (student['universityId'] ?? '').toString(),

          'profileImageUrl': (student['profileImageUrl'] ?? '').toString(),

          // ------------------------------------------------------
          // ENROLLMENT
          // ------------------------------------------------------
          'enrollmentId': enrollment['id'],

          'sectionId': EnrollmentMembership.text(enrollment['sectionId']),
          'sectionName': EnrollmentMembership.text(enrollment['sectionName']),
          'sectionIdentifier': EnrollmentMembership.text(
            enrollment['sectionIdentifier'],
          ),

          'courseId': courseId,

          'enrollmentStatus': enrollmentStatus,

          'enrolledAt': enrollment['enrolledAt'],
        });
      }

      // ----------------------------------------------------------
      // SORT BY NAME
      // ----------------------------------------------------------

      students.sort((a, b) {
        final String nameA = (a['name'] ?? '').toString().toLowerCase();

        final String nameB = (b['name'] ?? '').toString().toLowerCase();

        return nameA.compareTo(nameB);
      });

      return students;
    } on FirebaseException catch (e) {
      throw RosterServiceException(
        e.message ?? 'Unable to load course students.',
      );
    } catch (_) {
      throw RosterServiceException('Unable to load course students.');
    }
  }

  // ============================================================
  // VERIFY INSTRUCTOR OWNS COURSE
  // ============================================================

  Future<bool> currentInstructorOwnsCourse(String courseId) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null || courseId.trim().isEmpty) {
        return false;
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      if (!document.exists) {
        return false;
      }

      final Map<String, dynamic>? data = document.data();

      if (data == null) {
        return false;
      }

      final String instructorId = (data['instructorId'] ?? '').toString();

      return instructorId == user.uid;
    } on FirebaseException catch (e) {
      throw RosterServiceException(
        e.message ?? 'Unable to verify course ownership.',
      );
    } catch (_) {
      throw RosterServiceException('Unable to verify course ownership.');
    }
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class RosterServiceException implements Exception {
  final String message;

  RosterServiceException(this.message);

  @override
  String toString() => message;
}
