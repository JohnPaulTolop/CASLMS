import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Authorized student assessment queries for legacy and section-based classes.
/// Legacy assessments must have an explicit sectionId: '' to be queryable.
class StudentAssessmentQueryService {
  StudentAssessmentQueryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getVisibleAssessments({
    required String courseId,
    String? moduleId,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    final String cleanCourseId = courseId.trim();
    if (uid.isEmpty || cleanCourseId.isEmpty) {
      throw StateError('Student and course are required.');
    }

    final enrollment = await _firestore
        .collection('enrollments')
        .doc('${cleanCourseId}_$uid')
        .get();
    final data = enrollment.data();
    if (data == null ||
        data['studentId'] != uid ||
        data['courseId'] != cleanCourseId ||
        data['status'] != 'active') {
      throw StateError('An active course enrollment is required.');
    }

    final String sectionId = (data['sectionId'] ?? '').toString().trim();
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> documents = {};

    // Always load course-wide legacy work, including for section students.
    // Then load only the student's own section, if assigned.
    final scopes = <String>['', if (sectionId.isNotEmpty) sectionId];
    for (final scope in scopes) {
      Query<Map<String, dynamic>> request = _firestore
          .collection('assessments')
          .where('courseId', isEqualTo: cleanCourseId)
          .where('status', whereIn: const ['published', 'closed'])
          .where('sectionId', isEqualTo: scope);
      if (moduleId != null && moduleId.trim().isNotEmpty) {
        request = request.where('moduleId', isEqualTo: moduleId.trim());
      }
      final snapshot = await request.get();
      for (final document in snapshot.docs) {
        documents[document.id] = document;
      }
    }

    return documents.values.toList();
  }
}
