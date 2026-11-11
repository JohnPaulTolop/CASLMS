import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical course-scoped Firestore paths used by student-facing reads.
///
/// The legacy top-level collections remain available during migration for
/// instructor/admin workflows. New writes are mirrored into these paths until
/// every caller has moved to the course-scoped schema.
abstract final class CourseContentPaths {
  static DocumentReference<Map<String, dynamic>> course(
    FirebaseFirestore firestore,
    String courseId,
  ) => firestore.collection('courses').doc(courseId.trim());

  static CollectionReference<Map<String, dynamic>> modules(
    FirebaseFirestore firestore,
    String courseId,
  ) => course(firestore, courseId).collection('modules');

  static DocumentReference<Map<String, dynamic>> module(
    FirebaseFirestore firestore,
    String courseId,
    String moduleId,
  ) => modules(firestore, courseId).doc(moduleId.trim());

  static CollectionReference<Map<String, dynamic>> resources(
    FirebaseFirestore firestore,
    String courseId,
    String moduleId,
  ) => module(firestore, courseId, moduleId).collection('resources');

  static CollectionReference<Map<String, dynamic>> assessments(
    FirebaseFirestore firestore,
    String courseId,
    String moduleId,
  ) => module(firestore, courseId, moduleId).collection('assessments');

  static CollectionReference<Map<String, dynamic>> calendarEvents(
    FirebaseFirestore firestore,
    String courseId,
  ) => course(firestore, courseId).collection('calendarEvents');
}
