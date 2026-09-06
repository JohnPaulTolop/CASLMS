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

  Future<Map<String, dynamic>> _requireRole(String requiredRole) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw AssessmentSubmissionException('You must be logged in.');
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final data = document.data();

    if (data == null) {
      throw AssessmentSubmissionException('Your profile could not be found.');
    }

    if (data['role'] != requiredRole || data['status'] != 'active') {
      throw AssessmentSubmissionException(
        'An active $requiredRole account is required.',
      );
    }

    return {...data, 'id': user.uid, 'uid': user.uid};
  }

  Future<Map<String, dynamic>> _requireAssessment(
    String assessmentId,
  ) async {
    final id = assessmentId.trim();

    if (id.isEmpty) {
      throw AssessmentSubmissionException('Assessment ID is required.');
    }

    final document = await _firestore
        .collection(assessmentsCollection)
        .doc(id)
        .get();

    final data = document.data();

    if (data == null) {
      throw AssessmentSubmissionException('Assessment could not be found.');
    }

    return {
      ...data,
      'id': document.id,
      'assessmentId': document.id,
    };
  }

  Future<void> _requireEnrollment({
    required String courseId,
    required String studentId,
  }) async {
    final document = await _firestore
        .collection('enrollments')
        .doc('${courseId}_$studentId')
        .get();

    final enrollment = document.data();

    if (enrollment == null ||
        enrollment['status'] != 'active' ||
        enrollment['courseId'] != courseId ||
        enrollment['studentId'] != studentId) {
      throw AssessmentSubmissionException(
        'You do not have an active enrollment in this course.',
      );
    }
  }

  String buildSubmissionId({
    required String assessmentId,
    required String studentId,
  }) {
    return '${assessmentId.trim()}_${studentId.trim()}';
  }

  Future<Map<String, dynamic>?> getMySubmission({
    required String assessmentId,
  }) async {
    final student = await _requireRole('student');

    final id = buildSubmissionId(
      assessmentId: assessmentId,
      studentId: student['id'].toString(),
    );

    final document = await _firestore
        .collection(submissionsCollection)
        .doc(id)
        .get();

    final data = document.data();
    if (data == null) return null;

    return {...data, 'id': document.id, 'submissionId': document.id};
  }

  Future<Map<String, dynamic>> markAsSubmitted({
    required String assessmentId,
  }) async {
    final student = await _requireRole('student');
    final assessment = await _requireAssessment(assessmentId);

    final studentId = student['id'].toString();
    final courseId = (assessment['courseId'] ?? '').toString().trim();
    final moduleId = (assessment['moduleId'] ?? '').toString().trim();

    if (courseId.isEmpty || moduleId.isEmpty) {
      throw AssessmentSubmissionException(
        'Assessment course or module information is missing.',
      );
    }

    if (assessment['status'] != 'published') {
      throw AssessmentSubmissionException(
        'This assessment is not currently available.',
      );
    }

    if (assessment['deliveryType'] != 'external_link') {
      throw AssessmentSubmissionException(
        'This assessment is not an external-link assessment.',
      );
    }

    await _requireEnrollment(
      courseId: courseId,
      studentId: studentId,
    );

    final dueValue = assessment['dueAt'];

    if (dueValue is Timestamp &&
        DateTime.now().isAfter(dueValue.toDate())) {
      throw AssessmentSubmissionException(
        'The deadline for this assessment has already passed.',
      );
    }

    final id = buildSubmissionId(
      assessmentId: assessmentId,
      studentId: studentId,
    );

    final reference = _firestore
        .collection(submissionsCollection)
        .doc(id);

    final existing = await reference.get();
    final existingStatus = existing.data()?['status'];

    if (existingStatus == 'submitted' || existingStatus == 'graded') {
      throw AssessmentSubmissionException(
        'This assessment has already been submitted.',
      );
    }

    var studentName =
        (student['name'] ?? student['displayName'] ?? '').toString().trim();

    if (studentName.isEmpty) {
      studentName =
          _auth.currentUser?.displayName ??
          _auth.currentUser?.email ??
          'Student';
    }

    final data = <String, dynamic>{
      'assessmentId': assessment['assessmentId'].toString(),
      'courseId': courseId,
      'moduleId': moduleId,
      'studentId': studentId,
      'studentName': studentName,
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      'score': null,
      'feedback': null,
      'gradedAt': null,
      'gradedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await reference.set(data, SetOptions(merge: true));

    return {...data, 'id': id, 'submissionId': id};
  }

  Future<List<Map<String, dynamic>>> getMyModuleSubmissions({
    required String courseId,
    required String moduleId,
  }) async {
    final student = await _requireRole('student');

    final snapshot = await _firestore
        .collection(submissionsCollection)
        .where('studentId', isEqualTo: student['id'])
        .get();

    return snapshot.docs
        .where((document) {
          final data = document.data();
          return data['courseId'] == courseId &&
              data['moduleId'] == moduleId;
        })
        .map((document) {
          return <String, dynamic>{
            ...document.data(),
            'id': document.id,
            'submissionId': document.id,
          };
        })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAssessmentSubmissions({
    required String assessmentId,
  }) async {
    final instructor = await _requireRole('instructor');
    final assessment = await _requireAssessment(assessmentId);

    final courseId = (assessment['courseId'] ?? '').toString();

    if (courseId.isEmpty) {
      throw AssessmentSubmissionException('Course information is missing.');
    }

    final course = await _firestore
        .collection('courses')
        .doc(courseId)
        .get();

    if (course.data()?['instructorId'] != instructor['id']) {
      throw AssessmentSubmissionException(
        'You can only view submissions from your own courses.',
      );
    }

    final snapshot = await _firestore
        .collection(submissionsCollection)
        .where('assessmentId', isEqualTo: assessmentId.trim())
        .get();

    return snapshot.docs.map((document) {
      return <String, dynamic>{
        ...document.data(),
        'id': document.id,
        'submissionId': document.id,
      };
    }).toList();
  }

  // Retain the old method signature, but reject manual score changes.
  Future<void> gradeSubmission({
    required String submissionId,
    required num score,
    String feedback = '',
  }) async {
    throw AssessmentSubmissionException(
      'Assessment scores are read-only. Use Save Feedback instead.',
    );
  }

  Future<void> saveFeedback({
    required String submissionId,
    required String feedback,
  }) async {
    final instructor = await _requireRole('instructor');

    final cleanId = submissionId.trim();
    final cleanFeedback = feedback.trim();
    final instructorId = instructor['id'].toString();

    if (cleanId.isEmpty) {
      throw AssessmentSubmissionException('Submission ID is required.');
    }

    if (cleanFeedback.isEmpty) {
      throw AssessmentSubmissionException('Please enter feedback.');
    }

    if (cleanFeedback.length > 5000) {
      throw AssessmentSubmissionException(
        'Feedback must not exceed 5,000 characters.',
      );
    }

    final submissionReference = _firestore
        .collection(submissionsCollection)
        .doc(cleanId);

    // Allocate once; retries of this transaction reuse this ID.
    final notificationReference = _firestore
        .collection('notifications')
        .doc();

    await _firestore.runTransaction((transaction) async {
      final submissionDocument = await transaction.get(
        submissionReference,
      );

      final submission = submissionDocument.data();

      if (submission == null) {
        throw AssessmentSubmissionException(
          'Submission could not be found.',
        );
      }

      final assessmentId =
          (submission['assessmentId'] ?? '').toString();

      if (assessmentId.isEmpty) {
        throw AssessmentSubmissionException(
          'Assessment information is missing.',
        );
      }

      final assessmentDocument = await transaction.get(
        _firestore.collection(assessmentsCollection).doc(assessmentId),
      );

      final assessment = assessmentDocument.data();

      if (assessment == null) {
        throw AssessmentSubmissionException(
          'Assessment could not be found.',
        );
      }

      final courseId = (assessment['courseId'] ?? '').toString();
      final studentId = (submission['studentId'] ?? '').toString();

      if (courseId.isEmpty ||
          studentId.isEmpty ||
          submission['courseId'] != courseId) {
        throw AssessmentSubmissionException(
          'Submission information is invalid.',
        );
      }

      final courseDocument = await transaction.get(
        _firestore.collection('courses').doc(courseId),
      );

      if (courseDocument.data()?['instructorId'] != instructorId) {
        throw AssessmentSubmissionException(
          'You can only give feedback in your own courses.',
        );
      }

      // An unchanged save does not create another notification.
      if (submission['feedback'] == cleanFeedback &&
          submission['feedbackBy'] == instructorId) {
        return;
      }

      transaction.update(submissionReference, {
        'feedback': cleanFeedback,
        'feedbackBy': instructorId,
        'feedbackAt': FieldValue.serverTimestamp(),
        'feedbackNotificationId': notificationReference.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationReference, {
        'userId': studentId,
        'type': 'feedback',
        'sourceType': 'assessmentFeedback',
        'sourceId': cleanId,
        'actorId': instructorId,
        'actorName':
            (instructor['name'] ?? 'Your instructor').toString(),
        'title': 'Feedback: ${assessment['title']}',
        'message': cleanFeedback,
        'courseId': courseId,
        'moduleId': (assessment['moduleId'] ?? '').toString(),
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class AssessmentSubmissionException implements Exception {
  AssessmentSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
