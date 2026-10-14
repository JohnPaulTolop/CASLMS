import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnrollmentService {
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
    try {
      final student = await getCurrentStudentProfile();
      final studentId = (student['id'] ?? '').toString().trim();
      final studentName =
          (student['name'] ?? student['displayName'] ?? 'Student')
              .toString()
              .trim();
      final campusId = (student['universityId'] ?? '').toString().trim();

      final cleanCode = normalizeClassCode(classCode);

      if (cleanCode.isEmpty) {
        throw EnrollmentServiceException('Enter a class code.');
      }

      if (campusId.isEmpty) {
        throw EnrollmentServiceException(
          'Your student profile is missing its Campus ID.',
        );
      }

      // Resolve a section using its unique class code.
      final sectionDocument = await _firestore
          .collection('courseSections')
          .doc(cleanCode)
          .get();

      final section = sectionDocument.data();

      if (section == null) {
        // Preserve older courses and instructor invitations.
        final legacyCourse = await findCourseByClassCode(cleanCode);

        if (legacyCourse != null) {
          throw EnrollmentServiceException(
            'This original class uses instructor invitations. '
            'Ask your instructor to invite you.',
          );
        }

        throw EnrollmentServiceException(
          'No section was found with this class code.',
        );
      }

      if (section['legacy'] != false) {
        throw EnrollmentServiceException(
          'The original section uses instructor invitations.',
        );
      }

      if (section['status'] != 'active') {
        throw EnrollmentServiceException(
          'This section is not accepting students.',
        );
      }

      if (normalizeClassCode((section['classCode'] ?? '').toString()) !=
          cleanCode) {
        throw EnrollmentServiceException('Invalid section class code.');
      }

      final courseId = (section['courseId'] ?? '').toString().trim();

      if (courseId.isEmpty) {
        throw EnrollmentServiceException(
          'Section course information is missing.',
        );
      }

      final courseDocument = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      final course = courseDocument.data();

      if (course == null || course['status'] != 'active') {
        throw EnrollmentServiceException(
          'This course is currently unavailable.',
        );
      }

      if (course['instructorId'] != section['instructorId']) {
        throw EnrollmentServiceException(
          'Section instructor information does not match.',
        );
      }

      // Preserve existing enrollment document IDs.
      // One active section membership per student per course.
      final enrollmentId = '${courseId}_$studentId';

      final enrollmentReference = _firestore
          .collection('enrollments')
          .doc(enrollmentId);

      final existing = await enrollmentReference.get();

      if (existing.exists) {
        if (existing.data()?['status'] == 'active') {
          throw EnrollmentServiceException(
            'You are already enrolled in this course. '
            'Contact your instructor to transfer sections.',
          );
        }

        throw EnrollmentServiceException(
          'You have a previous enrollment in this course. '
          'Contact your instructor to reactivate or transfer it.',
        );
      }

      // Fields must match validSectionCodeEnrollment()
      // in Firestore security rules.
      await enrollmentReference.set({
        'courseId': courseId,
        'studentId': studentId,
        'studentName': studentName,
        'studentCampusId': campusId,
        'sectionId': cleanCode,
        'status': 'active',
        'enrollmentSource': 'section_code',
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      return {
        ...course,
        'id': courseId,
        'courseId': courseId,
        'sectionId': cleanCode,
        'sectionName': section['name'],
        'sectionIdentifier': section['identifier'],
        'enrollmentId': enrollmentId,
      };
    } on EnrollmentServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EnrollmentServiceException(
        error.code == 'permission-denied'
            ? 'This section cannot be accessed or joined. '
                  'Check the class code or contact your instructor.'
            : error.message ?? 'Unable to join this section.',
      );
    } catch (_) {
      throw EnrollmentServiceException('Unable to join this section.');
    }
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
          'sectionId': (enrollment['sectionId'] ?? course['classCode'] ?? '')
              .toString(),
        });
      }

      courses.sort((a, b) {
        final String codeA = (a['code'] ?? '').toString().toUpperCase();

        final String codeB = (b['code'] ?? '').toString().toUpperCase();

        return codeA.compareTo(codeB);
      });

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
