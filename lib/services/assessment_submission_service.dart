import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssessmentSubmissionService {
  AssessmentSubmissionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String submissionsCollection = 'assessmentSubmissions';

  static const String assessmentsCollection = 'assessments';

  // ============================================================
  // CURRENT USER
  // ============================================================

  User _requireAuthenticatedUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw AssessmentSubmissionException('You must be logged in.');
    }

    return user;
  }

  // ============================================================
  // REQUIRE ACTIVE STUDENT
  // ============================================================

  Future<Map<String, dynamic>> _requireStudent() async {
    final User user = _requireAuthenticatedUser();

    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDocument.exists || userDocument.data() == null) {
      throw AssessmentSubmissionException(
        'Student profile could not be found.',
      );
    }

    final Map<String, dynamic> data = userDocument.data()!;

    final String role = (data['role'] ?? '').toString().trim().toLowerCase();

    if (role != 'student') {
      throw AssessmentSubmissionException(
        'Only students can submit assessments.',
      );
    }

    final String status = (data['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw AssessmentSubmissionException(
        'Your student account is not active.',
      );
    }

    return {...data, 'id': user.uid, 'uid': user.uid};
  }

  // ============================================================
  // REQUIRE ACTIVE INSTRUCTOR
  // ============================================================

  Future<Map<String, dynamic>> _requireInstructor() async {
    final User user = _requireAuthenticatedUser();

    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDocument.exists || userDocument.data() == null) {
      throw AssessmentSubmissionException(
        'Instructor profile could not be found.',
      );
    }

    final Map<String, dynamic> data = userDocument.data()!;

    final String role = (data['role'] ?? '').toString().trim().toLowerCase();

    if (role != 'instructor') {
      throw AssessmentSubmissionException(
        'Only instructors can grade assessments.',
      );
    }

    final String status = (data['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw AssessmentSubmissionException(
        'Your instructor account is not active.',
      );
    }

    return {...data, 'id': user.uid, 'uid': user.uid};
  }

  // ============================================================
  // GET ASSESSMENT
  // ============================================================

  Future<Map<String, dynamic>> _requireAssessment(String assessmentId) async {
    final String cleanId = assessmentId.trim();

    if (cleanId.isEmpty) {
      throw AssessmentSubmissionException('Assessment ID is required.');
    }

    final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
        await _firestore.collection(assessmentsCollection).doc(cleanId).get();

    if (!assessmentDocument.exists || assessmentDocument.data() == null) {
      throw AssessmentSubmissionException('Assessment could not be found.');
    }

    return {
      ...assessmentDocument.data()!,
      'id': assessmentDocument.id,
      'assessmentId': assessmentDocument.id,
    };
  }

  // ============================================================
  // CHECK STUDENT ENROLLMENT
  // ============================================================

  Future<void> _requireEnrollment({
    required String courseId,
    required String studentId,
  }) async {
    final String enrollmentId = '${courseId}_$studentId';

    final DocumentSnapshot<Map<String, dynamic>> enrollmentDocument =
        await _firestore.collection('enrollments').doc(enrollmentId).get();

    if (!enrollmentDocument.exists || enrollmentDocument.data() == null) {
      throw AssessmentSubmissionException(
        'You are not enrolled in this course.',
      );
    }

    final String status = (enrollmentDocument.data()!['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw AssessmentSubmissionException(
        'Your enrollment in this course is not active.',
      );
    }
  }

  // ============================================================
  // DETERMINISTIC SUBMISSION ID
  // ============================================================

  String buildSubmissionId({
    required String assessmentId,
    required String studentId,
  }) {
    return '${assessmentId.trim()}_${studentId.trim()}';
  }

  // ============================================================
  // GET CURRENT STUDENT SUBMISSION
  // ============================================================

  Future<Map<String, dynamic>?> getMySubmission({
    required String assessmentId,
  }) async {
    final Map<String, dynamic> student = await _requireStudent();

    final String studentId = student['id'].toString();

    final String submissionId = buildSubmissionId(
      assessmentId: assessmentId,
      studentId: studentId,
    );

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection(submissionsCollection)
        .doc(submissionId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return {
      ...document.data()!,
      'id': document.id,
      'submissionId': document.id,
    };
  }

  // ============================================================
  // MARK AS SUBMITTED
  // ============================================================

  Future<Map<String, dynamic>> markAsSubmitted({
    required String assessmentId,
  }) async {
    final Map<String, dynamic> student = await _requireStudent();

    final Map<String, dynamic> assessment = await _requireAssessment(
      assessmentId,
    );

    final String studentId = student['id'].toString();

    final String courseId = (assessment['courseId'] ?? '').toString().trim();

    final String moduleId = (assessment['moduleId'] ?? '').toString().trim();

    final String assessmentStatus = (assessment['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final String deliveryType = (assessment['deliveryType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (courseId.isEmpty || moduleId.isEmpty) {
      throw AssessmentSubmissionException(
        'Assessment course or module information is missing.',
      );
    }

    if (assessmentStatus != 'published') {
      throw AssessmentSubmissionException(
        'This assessment is not currently available.',
      );
    }

    if (deliveryType != 'external_link') {
      throw AssessmentSubmissionException(
        'This assessment is not an external-link assessment.',
      );
    }

    await _requireEnrollment(courseId: courseId, studentId: studentId);

    // ----------------------------------------------------------
    // Due date check
    // ----------------------------------------------------------

    final dynamic dueValue = assessment['dueAt'];

    if (dueValue is Timestamp) {
      final DateTime dueAt = dueValue.toDate();

      if (DateTime.now().isAfter(dueAt)) {
        throw AssessmentSubmissionException(
          'The deadline for this assessment has already passed.',
        );
      }
    }

    final String submissionId = buildSubmissionId(
      assessmentId: assessmentId,
      studentId: studentId,
    );

    final DocumentReference<Map<String, dynamic>> submissionDocument =
        _firestore.collection(submissionsCollection).doc(submissionId);

    final DocumentSnapshot<Map<String, dynamic>> existingDocument =
        await submissionDocument.get();

    // ----------------------------------------------------------
    // Prevent submitted / graded assessments from being
    // repeatedly recreated.
    // ----------------------------------------------------------

    if (existingDocument.exists && existingDocument.data() != null) {
      final String existingStatus = (existingDocument.data()!['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (existingStatus == 'submitted') {
        throw AssessmentSubmissionException(
          'You already marked this assessment as submitted.',
        );
      }

      if (existingStatus == 'graded') {
        throw AssessmentSubmissionException(
          'This assessment has already been graded.',
        );
      }
    }

    String studentName = (student['name'] ?? student['displayName'] ?? '')
        .toString()
        .trim();

    if (studentName.isEmpty) {
      studentName =
          (_auth.currentUser?.displayName ??
                  _auth.currentUser?.email ??
                  'Student')
              .toString()
              .trim();
    }

    final Map<String, dynamic> data = {
      'assessmentId': assessment['assessmentId'].toString(),

      'courseId': courseId,

      'moduleId': moduleId,

      'studentId': studentId,

      'studentName': studentName,

      'status': 'submitted',

      'submittedAt': FieldValue.serverTimestamp(),

      // Grading fields remain empty until instructor grades.
      'score': null,

      'feedback': null,

      'gradedAt': null,

      'gradedBy': null,

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    };

    await submissionDocument.set(data, SetOptions(merge: true));

    return {...data, 'id': submissionId, 'submissionId': submissionId};
  }

  // ============================================================
  // GET STUDENT SUBMISSIONS FOR MODULE
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyModuleSubmissions({
    required String courseId,
    required String moduleId,
  }) async {
    final Map<String, dynamic> student = await _requireStudent();

    final String studentId = student['id'].toString();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(submissionsCollection)
        .where('studentId', isEqualTo: studentId)
        .get();

    final List<Map<String, dynamic>> results = [];

    for (final document in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      if ((data['courseId'] ?? '').toString() != courseId) {
        continue;
      }

      if ((data['moduleId'] ?? '').toString() != moduleId) {
        continue;
      }

      results.add({...data, 'id': document.id, 'submissionId': document.id});
    }

    return results;
  }

  // ============================================================
  // GET ASSESSMENT SUBMISSIONS - INSTRUCTOR
  // ============================================================

  Future<List<Map<String, dynamic>>> getAssessmentSubmissions({
    required String assessmentId,
  }) async {
    final Map<String, dynamic> instructor = await _requireInstructor();

    final Map<String, dynamic> assessment = await _requireAssessment(
      assessmentId,
    );

    final String courseId = (assessment['courseId'] ?? '').toString();

    final DocumentSnapshot<Map<String, dynamic>> courseDocument =
        await _firestore.collection('courses').doc(courseId).get();

    if (!courseDocument.exists || courseDocument.data() == null) {
      throw AssessmentSubmissionException('Course could not be found.');
    }

    final String courseInstructorId =
        (courseDocument.data()!['instructorId'] ?? '').toString();

    if (courseInstructorId != instructor['id'].toString()) {
      throw AssessmentSubmissionException(
        'You can only view submissions from your own courses.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(submissionsCollection)
        .where('assessmentId', isEqualTo: assessmentId.trim())
        .get();

    final List<Map<String, dynamic>> submissions = snapshot.docs
        .map(
          (document) => {
            ...document.data(),
            'id': document.id,
            'submissionId': document.id,
          },
        )
        .toList();

    return submissions;
  }

  // ============================================================
  // INSTRUCTOR GRADE SUBMISSION
  // ============================================================

  Future<void> gradeSubmission({
    required String submissionId,
    required num score,
    String feedback = '',
  }) async {
    final Map<String, dynamic> instructor = await _requireInstructor();

    final String cleanSubmissionId = submissionId.trim();

    if (cleanSubmissionId.isEmpty) {
      throw AssessmentSubmissionException('Submission ID is required.');
    }

    final DocumentReference<Map<String, dynamic>> submissionReference =
        _firestore.collection(submissionsCollection).doc(cleanSubmissionId);

    final DocumentSnapshot<Map<String, dynamic>> submissionDocument =
        await submissionReference.get();

    if (!submissionDocument.exists || submissionDocument.data() == null) {
      throw AssessmentSubmissionException('Submission could not be found.');
    }

    final Map<String, dynamic> submission = submissionDocument.data()!;

    final String assessmentId = (submission['assessmentId'] ?? '').toString();

    final Map<String, dynamic> assessment = await _requireAssessment(
      assessmentId,
    );

    final String courseId = (assessment['courseId'] ?? '').toString();

    final DocumentSnapshot<Map<String, dynamic>> courseDocument =
        await _firestore.collection('courses').doc(courseId).get();

    if (!courseDocument.exists || courseDocument.data() == null) {
      throw AssessmentSubmissionException('Course could not be found.');
    }

    final String courseInstructorId =
        (courseDocument.data()!['instructorId'] ?? '').toString();

    if (courseInstructorId != instructor['id'].toString()) {
      throw AssessmentSubmissionException(
        'You can only grade submissions from your own courses.',
      );
    }

    final num totalPoints = (assessment['totalPoints'] as num?) ?? 0;

    if (score < 0) {
      throw AssessmentSubmissionException('Score cannot be negative.');
    }

    if (score > totalPoints) {
      throw AssessmentSubmissionException(
        'Score cannot be greater than $totalPoints.',
      );
    }

    await submissionReference.update({
      'score': score,
      'feedback': feedback.trim(),
      'status': 'graded',
      'gradedBy': instructor['id'].toString(),
      'gradedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class AssessmentSubmissionException implements Exception {
  AssessmentSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
