import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssessmentService {
  AssessmentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ============================================================
  // COLLECTION NAMES
  // ============================================================

  static const String assessmentsCollection = 'assessments';

  static const List<String> allowedAssessmentTypes = [
    'quiz',
    'activity',
    'assignment',
    'exam',
  ];

  static const List<String> allowedStatuses = ['draft', 'published', 'closed'];

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get currentUserId {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw AssessmentServiceException('No user is currently logged in.');
    }

    return user.uid;
  }

  // ============================================================
  // REQUIRE ACTIVE INSTRUCTOR
  // ============================================================

  Future<Map<String, dynamic>> _requireInstructor() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw AssessmentServiceException(
        'You must be logged in to manage assessments.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDocument.exists || userDocument.data() == null) {
      throw AssessmentServiceException(
        'Instructor profile could not be found.',
      );
    }

    final Map<String, dynamic> data = userDocument.data()!;

    final String role = (data['role'] ?? '').toString().trim().toLowerCase();

    if (role != 'instructor') {
      throw AssessmentServiceException(
        'Only instructors can manage assessments.',
      );
    }

    final String status = (data['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    if (status != 'active') {
      throw AssessmentServiceException(
        'Your instructor account is not active.',
      );
    }

    return {...data, 'id': user.uid, 'uid': user.uid};
  }

  // ============================================================
  // REQUIRE OWNED COURSE
  // ============================================================

  Future<Map<String, dynamic>> _requireOwnedCourse(String courseId) async {
    final String cleanCourseId = courseId.trim();

    if (cleanCourseId.isEmpty) {
      throw AssessmentServiceException('Course ID is required.');
    }

    final Map<String, dynamic> instructor = await _requireInstructor();

    final String instructorId = instructor['id'].toString();

    final DocumentSnapshot<Map<String, dynamic>> courseDocument =
        await _firestore.collection('courses').doc(cleanCourseId).get();

    if (!courseDocument.exists || courseDocument.data() == null) {
      throw AssessmentServiceException('Course could not be found.');
    }

    final Map<String, dynamic> course = courseDocument.data()!;

    final String courseInstructorId = (course['instructorId'] ?? '')
        .toString()
        .trim();

    if (courseInstructorId != instructorId) {
      throw AssessmentServiceException(
        'You can only manage assessments in your own courses.',
      );
    }

    final String courseStatus = (course['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (courseStatus != 'active') {
      throw AssessmentServiceException('This course is not active.');
    }

    return {...course, 'id': courseDocument.id, 'courseId': courseDocument.id};
  }

  // ============================================================
  // REQUIRE MODULE BELONGS TO COURSE
  // ============================================================

  Future<Map<String, dynamic>> _requireModule({
    required String courseId,
    required String moduleId,
  }) async {
    final String cleanModuleId = moduleId.trim();

    if (cleanModuleId.isEmpty) {
      throw AssessmentServiceException('Module ID is required.');
    }

    await _requireOwnedCourse(courseId);

    final DocumentSnapshot<Map<String, dynamic>> moduleDocument =
        await _firestore.collection('modules').doc(cleanModuleId).get();

    if (!moduleDocument.exists || moduleDocument.data() == null) {
      throw AssessmentServiceException('Module could not be found.');
    }

    final Map<String, dynamic> module = moduleDocument.data()!;

    final String moduleCourseId = (module['courseId'] ?? '').toString().trim();

    if (moduleCourseId != courseId.trim()) {
      throw AssessmentServiceException(
        'This module does not belong to the selected course.',
      );
    }

    return {...module, 'id': moduleDocument.id, 'moduleId': moduleDocument.id};
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String _validateAssessmentType(String type) {
    final String cleanType = type.trim().toLowerCase();

    if (!allowedAssessmentTypes.contains(cleanType)) {
      throw AssessmentServiceException('Invalid assessment type.');
    }

    return cleanType;
  }

  String _validateStatus(String status) {
    final String cleanStatus = status.trim().toLowerCase();

    if (!allowedStatuses.contains(cleanStatus)) {
      throw AssessmentServiceException('Invalid assessment status.');
    }

    return cleanStatus;
  }

  String _validateExternalUrl(String value) {
    final String cleanUrl = value.trim();

    if (cleanUrl.isEmpty) {
      throw AssessmentServiceException('Assessment URL is required.');
    }

    final Uri? uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw AssessmentServiceException('Enter a valid assessment URL.');
    }

    return cleanUrl;
  }

  // ============================================================
  // CREATE EXTERNAL ASSESSMENT
  // ============================================================

  Future<Map<String, dynamic>> createExternalAssessment({
    required String courseId,
    required String moduleId,
    required String title,
    required String instructions,
    required String assessmentType,
    required String externalUrl,
    required num totalPoints,
    required DateTime dueAt,
    String status = 'published',
  }) async {
    final String cleanCourseId = courseId.trim();
    final String cleanModuleId = moduleId.trim();
    final String cleanTitle = title.trim();
    final String cleanInstructions = instructions.trim();

    if (cleanTitle.isEmpty) {
      throw AssessmentServiceException('Assessment title is required.');
    }

    if (cleanInstructions.isEmpty) {
      throw AssessmentServiceException('Assessment instructions are required.');
    }

    if (totalPoints <= 0) {
      throw AssessmentServiceException(
        'Total points must be greater than zero.',
      );
    }

    final String cleanAssessmentType = _validateAssessmentType(assessmentType);

    final String cleanStatus = _validateStatus(status);

    final String cleanExternalUrl = _validateExternalUrl(externalUrl);

    final Map<String, dynamic> instructor = await _requireInstructor();

    await _requireModule(courseId: cleanCourseId, moduleId: cleanModuleId);

    final String instructorId = instructor['id'].toString();

    final DocumentReference<Map<String, dynamic>> assessmentDocument =
        _firestore.collection(assessmentsCollection).doc();

    final Map<String, dynamic> data = {
      'courseId': cleanCourseId,
      'moduleId': cleanModuleId,

      // Creator
      'createdBy': instructorId,

      // Basic information
      'title': cleanTitle,
      'instructions': cleanInstructions,

      // quiz / activity / assignment / exam
      'assessmentType': cleanAssessmentType,

      // Current version uses external URLs.
      // Later AI-generated assessments can use "ai_generated".
      'deliveryType': 'external_link',

      'externalUrl': cleanExternalUrl,

      // Grading
      'totalPoints': totalPoints,

      // Schedule
      'dueAt': Timestamp.fromDate(dueAt),

      // draft / published / closed
      'status': cleanStatus,

      // Timestamps
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await assessmentDocument.set(data);

    return {
      ...data,
      'id': assessmentDocument.id,
      'assessmentId': assessmentDocument.id,
    };
  }

  // ============================================================
  // GET ONE ASSESSMENT
  // ============================================================

  Future<Map<String, dynamic>?> getAssessmentById(String assessmentId) async {
    final String cleanAssessmentId = assessmentId.trim();

    if (cleanAssessmentId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection(assessmentsCollection)
        .doc(cleanAssessmentId)
        .get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return {
      ...document.data()!,
      'id': document.id,
      'assessmentId': document.id,
    };
  }

  // ============================================================
  // GET MODULE ASSESSMENTS - INSTRUCTOR
  // ============================================================

  Future<List<Map<String, dynamic>>> getModuleAssessments({
    required String courseId,
    required String moduleId,
  }) async {
    await _requireModule(courseId: courseId, moduleId: moduleId);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(assessmentsCollection)
        .where('moduleId', isEqualTo: moduleId.trim())
        .get();

    final List<Map<String, dynamic>> assessments = [];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String assessmentCourseId = (data['courseId'] ?? '')
          .toString()
          .trim();

      if (assessmentCourseId != courseId.trim()) {
        continue;
      }

      assessments.add({
        ...data,
        'id': document.id,
        'assessmentId': document.id,
      });
    }

    assessments.sort((a, b) {
      final Timestamp? aCreated = a['createdAt'] is Timestamp
          ? a['createdAt'] as Timestamp
          : null;

      final Timestamp? bCreated = b['createdAt'] is Timestamp
          ? b['createdAt'] as Timestamp
          : null;

      if (aCreated == null && bCreated == null) {
        return 0;
      }

      if (aCreated == null) {
        return 1;
      }

      if (bCreated == null) {
        return -1;
      }

      return aCreated.compareTo(bCreated);
    });

    return assessments;
  }

  // ============================================================
  // UPDATE ASSESSMENT
  // ============================================================

  Future<void> updateExternalAssessment({
    required String assessmentId,
    required String title,
    required String instructions,
    required String assessmentType,
    required String externalUrl,
    required num totalPoints,
    required DateTime dueAt,
  }) async {
    final String cleanAssessmentId = assessmentId.trim();

    if (cleanAssessmentId.isEmpty) {
      throw AssessmentServiceException('Assessment ID is required.');
    }

    final Map<String, dynamic>? assessment = await getAssessmentById(
      cleanAssessmentId,
    );

    if (assessment == null) {
      throw AssessmentServiceException('Assessment could not be found.');
    }

    final String courseId = (assessment['courseId'] ?? '').toString();

    final String moduleId = (assessment['moduleId'] ?? '').toString();

    await _requireModule(courseId: courseId, moduleId: moduleId);

    final String cleanTitle = title.trim();
    final String cleanInstructions = instructions.trim();

    if (cleanTitle.isEmpty) {
      throw AssessmentServiceException('Assessment title is required.');
    }

    if (cleanInstructions.isEmpty) {
      throw AssessmentServiceException('Assessment instructions are required.');
    }

    if (totalPoints <= 0) {
      throw AssessmentServiceException(
        'Total points must be greater than zero.',
      );
    }

    await _firestore
        .collection(assessmentsCollection)
        .doc(cleanAssessmentId)
        .update({
          'title': cleanTitle,
          'instructions': cleanInstructions,
          'assessmentType': _validateAssessmentType(assessmentType),
          'externalUrl': _validateExternalUrl(externalUrl),
          'totalPoints': totalPoints,
          'dueAt': Timestamp.fromDate(dueAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ============================================================
  // CHANGE STATUS
  // ============================================================

  Future<void> updateAssessmentStatus({
    required String assessmentId,
    required String status,
  }) async {
    final String cleanAssessmentId = assessmentId.trim();

    final Map<String, dynamic>? assessment = await getAssessmentById(
      cleanAssessmentId,
    );

    if (assessment == null) {
      throw AssessmentServiceException('Assessment could not be found.');
    }

    await _requireModule(
      courseId: (assessment['courseId'] ?? '').toString(),
      moduleId: (assessment['moduleId'] ?? '').toString(),
    );

    await _firestore
        .collection(assessmentsCollection)
        .doc(cleanAssessmentId)
        .update({
          'status': _validateStatus(status),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ============================================================
  // DELETE ASSESSMENT
  // ============================================================

  Future<void> deleteAssessment(String assessmentId) async {
    final String cleanAssessmentId = assessmentId.trim();

    final Map<String, dynamic>? assessment = await getAssessmentById(
      cleanAssessmentId,
    );

    if (assessment == null) {
      throw AssessmentServiceException('Assessment could not be found.');
    }

    await _requireModule(
      courseId: (assessment['courseId'] ?? '').toString(),
      moduleId: (assessment['moduleId'] ?? '').toString(),
    );

    await _firestore
        .collection(assessmentsCollection)
        .doc(cleanAssessmentId)
        .delete();
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class AssessmentServiceException implements Exception {
  AssessmentServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
