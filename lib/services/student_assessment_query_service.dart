import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'course_content_paths.dart';
import 'section_audience_service.dart';

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
  getVisibleAssessments({required String courseId, String? moduleId}) async {
    final String uid = _auth.currentUser?.uid ?? '';
    final String cleanCourseId = courseId.trim();
    if (uid.isEmpty || cleanCourseId.isEmpty) {
      throw StateError('Student and course are required.');
    }

    final enrollment = await SectionAudienceService(firestore: _firestore)
        .requireActiveEnrollment(courseId: cleanCourseId, studentId: uid);
    final String sectionId = (enrollment['sectionId'] ?? '').toString().trim();
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> documents =
        {};

    final requestedModuleId = moduleId?.trim() ?? '';
    final List<String> moduleIds;
    if (requestedModuleId.isNotEmpty) {
      moduleIds = <String>[requestedModuleId];
    } else {
      final modules =
          await CourseContentPaths.modules(_firestore, cleanCourseId)
              .where('courseId', isEqualTo: cleanCourseId)
              .where('status', isEqualTo: 'published')
              .where(
                'sectionIds',
                arrayContainsAny: <String>[
                  SectionAudienceService.allSections,
                  sectionId,
                ],
              )
              .get();
      moduleIds = modules.docs.map((document) => document.id).toList();
    }

    // Always load course-wide legacy work, including for section students.
    // Then load only the student's own section, if assigned.
    final scopes = <String>['', if (sectionId.isNotEmpty) sectionId];
    for (final visibleModuleId in moduleIds) {
      for (final scope in scopes) {
        final request =
            CourseContentPaths.assessments(
                  _firestore,
                  cleanCourseId,
                  visibleModuleId,
                )
                .where('courseId', isEqualTo: cleanCourseId)
                .where('moduleId', isEqualTo: visibleModuleId)
                .where('status', whereIn: const ['published', 'closed'])
                .where(
                  'sectionIds',
                  arrayContainsAny: <String>[
                    SectionAudienceService.allSections,
                    sectionId,
                  ],
                )
                .where('sectionId', isEqualTo: scope);
        final snapshot = await request.get();
        for (final document in snapshot.docs) {
          documents[document.id] = document;
        }
      }
    }

    return documents.values.toList();
  }
}
