import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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

    final document = await _firestore.collection('users').doc(user.uid).get();

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

  Future<Map<String, dynamic>> _requireAssessment(String assessmentId) async {
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

    return {...data, 'id': document.id, 'assessmentId': document.id};
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

    await _requireEnrollment(courseId: courseId, studentId: studentId);

    final dueValue = assessment['dueAt'];

    if (dueValue is Timestamp && DateTime.now().isAfter(dueValue.toDate())) {
      throw AssessmentSubmissionException(
        'The deadline for this assessment has already passed.',
      );
    }

    final id = buildSubmissionId(
      assessmentId: assessmentId,
      studentId: studentId,
    );

    final reference = _firestore.collection(submissionsCollection).doc(id);

    final existing = await reference.get();
    final existingStatus = existing.data()?['status'];

    if (existingStatus == 'submitted' || existingStatus == 'graded') {
      throw AssessmentSubmissionException(
        'This assessment has already been submitted.',
      );
    }

    var studentName = (student['name'] ?? student['displayName'] ?? '')
        .toString()
        .trim();

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
          return data['courseId'] == courseId && data['moduleId'] == moduleId;
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

    final course = await _firestore.collection('courses').doc(courseId).get();

    if (course.data()?['instructorId'] != instructor['id']) {
      throw AssessmentSubmissionException(
        'You can only view submissions from your own courses.',
      );
    }

    final snapshot = await _firestore
        .collection(submissionsCollection)
        .where('assessmentId', isEqualTo: assessmentId.trim())
        .where('courseId', isEqualTo: courseId)
        .get();

    return snapshot.docs.map((document) {
      return <String, dynamic>{
        ...document.data(),
        'id': document.id,
        'submissionId': document.id,
      };
    }).toList();
  }

  bool _isGoogleFormAssessment(Map<String, dynamic> assessment) {
    final String submissionMethod = (assessment['submissionMethod'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (submissionMethod.isNotEmpty) {
      return submissionMethod == 'google_form';
    }

    final Uri? uri = Uri.tryParse(
      (assessment['externalUrl'] ?? '').toString().trim(),
    );

    if (uri == null) {
      return false;
    }

    final String host = uri.host.toLowerCase();

    return host == 'forms.gle' ||
        (host == 'docs.google.com' &&
            uri.path.toLowerCase().contains('/forms/'));
  }

  Future<void> setGoogleFormCompliance({
    required String assessmentId,
    required String studentId,
    required bool complied,
  }) async {
    final Map<String, dynamic> instructor = await _requireRole('instructor');
    final String cleanAssessmentId = assessmentId.trim();
    final String cleanStudentId = studentId.trim();
    final String instructorId = instructor['id'].toString();

    if (cleanAssessmentId.isEmpty || cleanStudentId.isEmpty) {
      throw AssessmentSubmissionException(
        'Assessment and student information are required.',
      );
    }

    final DocumentReference<Map<String, dynamic>> assessmentReference =
        _firestore.collection(assessmentsCollection).doc(cleanAssessmentId);

    final String submissionId = buildSubmissionId(
      assessmentId: cleanAssessmentId,
      studentId: cleanStudentId,
    );

    final DocumentReference<Map<String, dynamic>> submissionReference =
        _firestore.collection(submissionsCollection).doc(submissionId);

    // A new notification is created only when the decision changes.
    final DocumentReference<Map<String, dynamic>> notificationReference =
        _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
          await transaction.get(assessmentReference);

      final Map<String, dynamic>? assessment = assessmentDocument.data();

      if (assessment == null || !_isGoogleFormAssessment(assessment)) {
        throw AssessmentSubmissionException(
          'This assessment is not configured as a Google Form.',
        );
      }

      final String courseId = (assessment['courseId'] ?? '').toString().trim();
      final String moduleId = (assessment['moduleId'] ?? '').toString().trim();

      if (courseId.isEmpty || moduleId.isEmpty) {
        throw AssessmentSubmissionException(
          'Assessment course or module information is missing.',
        );
      }

      final DocumentReference<Map<String, dynamic>> courseReference = _firestore
          .collection('courses')
          .doc(courseId);
      final DocumentReference<Map<String, dynamic>> studentReference =
          _firestore.collection('users').doc(cleanStudentId);
      final DocumentReference<Map<String, dynamic>> enrollmentReference =
          _firestore
              .collection('enrollments')
              .doc('${courseId}_$cleanStudentId');

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await transaction.get(courseReference);
      final DocumentSnapshot<Map<String, dynamic>> studentDocument =
          await transaction.get(studentReference);
      final DocumentSnapshot<Map<String, dynamic>> enrollmentDocument =
          await transaction.get(enrollmentReference);
      final DocumentSnapshot<Map<String, dynamic>> existingDocument =
          await transaction.get(submissionReference);

      if (courseDocument.data()?['instructorId'] != instructorId) {
        throw AssessmentSubmissionException(
          'You can verify students only in your own courses.',
        );
      }

      final Map<String, dynamic>? student = studentDocument.data();
      final Map<String, dynamic>? enrollment = enrollmentDocument.data();

      if (student == null ||
          (student['role'] ?? '').toString().toLowerCase() != 'student' ||
          (student['status'] ?? '').toString().toLowerCase() != 'active') {
        throw AssessmentSubmissionException(
          'The selected student account is not active.',
        );
      }

      if (enrollment == null ||
          enrollment['courseId'] != courseId ||
          enrollment['studentId'] != cleanStudentId ||
          (enrollment['status'] ?? '').toString().toLowerCase() != 'active') {
        throw AssessmentSubmissionException(
          'The selected student is not actively enrolled in this course.',
        );
      }

      final String decision = complied ? 'complied' : 'not_complied';
      final Map<String, dynamic>? existing = existingDocument.data();
      if (existing?['status'] == 'graded') {
        throw AssessmentSubmissionException(
          'This response is graded. Use Manual Grade Input to correct its score.',
        );
      }

      if ((existing?['complianceStatus'] ?? '').toString().toLowerCase() ==
          decision) {
        return;
      }

      final String studentName =
          (student['name'] ??
                  student['displayName'] ??
                  enrollment['studentName'] ??
                  'Student')
              .toString()
              .trim();

      final Map<String, dynamic> submissionData = {
        'assessmentId': cleanAssessmentId,
        'courseId': courseId,
        'moduleId': moduleId,
        'studentId': cleanStudentId,
        'studentName': studentName,
        'studentEmail': (student['email'] ?? '').toString().trim(),
        'submissionType': 'google_form',
        'submissionSource': 'instructor_verification',
        'complianceStatus': decision,
        'status': complied ? 'submitted' : 'not_complied',
        'verifiedBy': instructorId,
        'verifiedAt': FieldValue.serverTimestamp(),
        'complianceNotificationId': notificationReference.id,
        'submittedAt': complied ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existingDocument.exists) ...{
          'score': null,
          'feedback': null,
          'gradedAt': null,
          'gradedBy': null,
          'createdAt': FieldValue.serverTimestamp(),
        },
      };

      transaction.set(
        submissionReference,
        submissionData,
        SetOptions(merge: true),
      );

      transaction.set(notificationReference, {
        'userId': cleanStudentId,
        'type': complied ? 'compliance_approved' : 'compliance_rejected',
        'sourceType': 'googleFormCompliance',
        'sourceId': submissionId,
        'actorId': instructorId,
        'actorName': (instructor['name'] ?? 'Your instructor').toString(),
        'title': complied
            ? 'Google Form response verified'
            : 'Google Form response not verified',
        'message': complied
            ? 'You were marked Complied for ${assessment['title']}.'
            : 'No valid response was verified for ${assessment['title']}. '
                  'Please contact your instructor if you already submitted.',
        'courseId': courseId,
        'moduleId': moduleId,
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveManualGrade({
    required String assessmentId,
    required String studentId,
    required num score,
    String feedback = '',
  }) async {
    if (!score.isFinite || score < 0) {
      throw AssessmentSubmissionException('Enter a valid non-negative score.');
    }
    await _requireRole('instructor');
    final idToken = await _auth.currentUser!.getIdToken(true);
    final appCheck = await FirebaseAppCheck.instance.getToken(true);
    if (idToken == null || appCheck == null || appCheck.isEmpty) {
      throw AssessmentSubmissionException('Please sign in again and retry.');
    }
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'manual-grade',
        headers: {
          'Authorization': 'Bearer $idToken',
          'X-Firebase-AppCheck': appCheck,
        },
        body: {
          'assessmentId': assessmentId,
          'studentId': studentId,
          'score': score,
          'feedback': feedback,
        },
      );
      if (result.data is! Map || result.data['success'] != true) {
        throw AssessmentSubmissionException('Unable to save the grade.');
      }
    } on FunctionException catch (error) {
      throw AssessmentSubmissionException(
        error.details is Map
            ? (error.details['error'] ?? 'Unable to save the grade.').toString()
            : 'Unable to save the grade. Please retry.',
      );
    }
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required num score,
    String feedback = '',
  }) async {
    final doc = await _firestore
        .collection(submissionsCollection)
        .doc(submissionId)
        .get();
    final data = doc.data();
    if (data == null) {
      throw AssessmentSubmissionException('Submission not found.');
    }
    await saveManualGrade(
      assessmentId: data['assessmentId'].toString(),
      studentId: data['studentId'].toString(),
      score: score,
      feedback: feedback,
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
    final notificationReference = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final submissionDocument = await transaction.get(submissionReference);

      final submission = submissionDocument.data();

      if (submission == null) {
        throw AssessmentSubmissionException('Submission could not be found.');
      }

      final assessmentId = (submission['assessmentId'] ?? '').toString();

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
        throw AssessmentSubmissionException('Assessment could not be found.');
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
        'actorName': (instructor['name'] ?? 'Your instructor').toString(),
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
