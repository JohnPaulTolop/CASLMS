import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_order.dart';
import 'live_courses_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class EnrollmentService {
  Stream<List<Map<String, dynamic>>> watchMyActiveCourses() {
    final uid = _auth.currentUser?.uid;
    return uid == null
        ? Stream.value([])
        : LiveCoursesService.watch(_firestore, uid);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // REQUIRE CURRENT ACTIVE STUDENT
  // ============================================================

  Future<Map<String, dynamic>> getCurrentStudentProfile() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw EnrollmentServiceException('No student is currently logged in.');
      }

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!document.exists || document.data() == null) {
        throw EnrollmentServiceException('Student profile could not be found.');
      }

      final Map<String, dynamic> data = document.data()!;

      final String role = (data['role'] ?? '').toString().trim().toLowerCase();

      if (role != 'student') {
        throw EnrollmentServiceException('Only students can join classes.');
      }

      final String status = (data['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'active') {
        throw EnrollmentServiceException('This student account is not active.');
      }

      return {...data, 'id': document.id, 'uid': document.id};
    } on EnrollmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw EnrollmentServiceException(
        e.message ?? 'Unable to load student profile.',
      );
    } catch (_) {
      throw EnrollmentServiceException('Unable to load student profile.');
    }
  }

  // ============================================================
  // NORMALIZE CLASS CODE
  // ============================================================

  String normalizeClassCode(String value) {
    return value.trim().toUpperCase();
  }

  // ============================================================
  // FIND COURSE BY CLASS CODE
  // ============================================================

  Future<Map<String, dynamic>?> findCourseByClassCode(String classCode) async {
    try {
      final String cleanCode = normalizeClassCode(classCode);

      if (cleanCode.isEmpty) {
        return null;
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('courses')
          .where('classCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>> document =
          snapshot.docs.first;

      final Map<String, dynamic> data = document.data();

      return {...data, 'id': document.id, 'courseId': document.id};
    } on FirebaseException catch (e) {
      throw EnrollmentServiceException(
        e.message ?? 'Unable to search for class.',
      );
    } catch (_) {
      throw EnrollmentServiceException('Unable to search for class.');
    }
  }

  // ============================================================
  // JOIN CLASS
  // ============================================================

  Future<Map<String, dynamic>> joinClass({required String classCode}) async {
    throw EnrollmentServiceException(
      'Classes are invitation-only. Accept an invitation from your instructor.',
    );
  }

  // ============================================================
  // GET CURRENT STUDENT ACTIVE COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyActiveCourses() async {
    try {
      final Map<String, dynamic> student = await getCurrentStudentProfile();

      final String studentId = (student['id'] ?? '').toString().trim();

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('studentId', isEqualTo: studentId)
              .get();

      final List<Map<String, dynamic>> courses = [];

      final Set<String> addedCourseIds = {};

      for (final QueryDocumentSnapshot<Map<String, dynamic>> enrollmentDocument
          in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollment = enrollmentDocument.data();

        final String enrollmentStatus = (enrollment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String courseId = (enrollment['courseId'] ?? '')
            .toString()
            .trim();

        if (courseId.isEmpty || addedCourseIds.contains(courseId)) {
          continue;
        }

        final DocumentSnapshot<Map<String, dynamic>> courseDocument =
            await _firestore.collection('courses').doc(courseId).get();

        if (!courseDocument.exists || courseDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> course = courseDocument.data()!;

        final String courseStatus = (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        addedCourseIds.add(courseId);

        courses.add({
          ...course,

          'id': courseId,

          'courseId': courseId,

          'enrollmentId': enrollmentDocument.id,
          'joinedAt': enrollment['enrolledAt'] ?? enrollment['acceptedAt'],
          'sectionId': (enrollment['sectionId'] ?? course['classCode'] ?? '')
              .toString(),
        });
      }

      courses.sort(compareJoinedCourses);

      return courses;
    } on EnrollmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw EnrollmentServiceException(
        e.message ?? 'Unable to load enrolled classes.',
      );
    } catch (_) {
      throw EnrollmentServiceException('Unable to load enrolled classes.');
    }
  }

  // ============================================================
  // CHECK ENROLLMENT
  // ============================================================

  Future<bool> isEnrolled({required String courseId}) async {
    try {
      final User? user = _auth.currentUser;

      if (user == null || courseId.trim().isEmpty) {
        return false;
      }

      final String enrollmentId = '${courseId.trim()}_${user.uid}';

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('enrollments')
          .doc(enrollmentId)
          .get();

      if (!document.exists || document.data() == null) {
        return false;
      }

      return (document.data()!['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase() ==
          'active';
    } on FirebaseException {
      return false;
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class EnrollmentServiceException implements Exception {
  final String message;

  EnrollmentServiceException(this.message);

  @override
  String toString() => message;
}
