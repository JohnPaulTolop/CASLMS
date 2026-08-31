import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // GET ONE COURSE
  // ============================================================

  Future<Map<String, dynamic>?> getCourseById(
    String courseId,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _firestore
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

      return {
        'id': document.id,
        ...data,
      };
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ?? 'Unable to load course.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load course.',
      );
    }
  }

  // ============================================================
  // GET CURRENT STUDENT'S COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>> getStudentCourses() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw CourseServiceException(
          'No student is currently logged in.',
        );
      }

      // ----------------------------------------------------------
      // Find enrollment records for current student
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>>
          enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final List<Map<String, dynamic>> courses = [];

      // ----------------------------------------------------------
      // Process every enrollment
      // ----------------------------------------------------------

      for (final enrollmentDoc in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollment =
            enrollmentDoc.data();

        final String enrollmentStatus =
            (enrollment['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String courseId =
            (enrollment['courseId'] ?? '')
                .toString()
                .trim();

        if (courseId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // Get actual course
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>>
            courseDocument =
            await _firestore
                .collection('courses')
                .doc(courseId)
                .get();

        if (!courseDocument.exists) {
          continue;
        }

        final Map<String, dynamic>? courseData =
            courseDocument.data();

        if (courseData == null) {
          continue;
        }

        final String courseStatus =
            (courseData['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        courses.add({
          'id': courseDocument.id,
          ...courseData,
          'enrollmentId': enrollmentDoc.id,
          'enrolledAt': enrollment['enrolledAt'],
        });
      }

      // ----------------------------------------------------------
      // Sort by course code
      // ----------------------------------------------------------

      courses.sort((a, b) {
        final String codeA =
            (a['code'] ?? '').toString();

        final String codeB =
            (b['code'] ?? '').toString();

        return codeA.compareTo(codeB);
      });

      return courses;
    } on CourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ??
            'Unable to load student courses.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load student courses.',
      );
    }
  }

  // ============================================================
  // GET CURRENT INSTRUCTOR'S COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorCourses() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw CourseServiceException(
          'No instructor is currently logged in.',
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('courses')
              .where(
                'instructorId',
                isEqualTo: user.uid,
              )
              .get();

      final List<Map<String, dynamic>> courses =
          snapshot.docs
              .map((document) {
                return {
                  'id': document.id,
                  ...document.data(),
                };
              })
              .where((course) {
                return (course['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    'active';
              })
              .toList();

      courses.sort((a, b) {
        final String codeA =
            (a['code'] ?? '').toString();

        final String codeB =
            (b['code'] ?? '').toString();

        return codeA.compareTo(codeB);
      });

      return courses;
    } on CourseServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ??
            'Unable to load instructor courses.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load instructor courses.',
      );
    }
  }

  // ============================================================
  // GET PUBLISHED MODULES FOR STUDENT
  // ============================================================

  Future<List<Map<String, dynamic>>> getCourseModules(
    String courseId,
  ) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('modules')
              .where(
                'courseId',
                isEqualTo: courseId,
              )
              .get();

      final List<Map<String, dynamic>> modules =
          snapshot.docs
              .map((document) {
                return {
                  'id': document.id,
                  ...document.data(),
                };
              })
              .where((module) {
                return (module['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase() ==
                    'published';
              })
              .toList();

      modules.sort((a, b) {
        final num orderA =
            a['order'] is num
                ? a['order'] as num
                : 0;

        final num orderB =
            b['order'] is num
                ? b['order'] as num
                : 0;

        return orderA.compareTo(orderB);
      });

      return modules;
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ??
            'Unable to load course modules.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load course modules.',
      );
    }
  }

  // ============================================================
  // GET ALL MODULES FOR INSTRUCTOR
  // Published + Draft
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorCourseModules(
    String courseId,
  ) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('modules')
              .where(
                'courseId',
                isEqualTo: courseId,
              )
              .get();

      final List<Map<String, dynamic>> modules =
          snapshot.docs.map((document) {
        return {
          'id': document.id,
          ...document.data(),
        };
      }).toList();

      modules.sort((a, b) {
        final num orderA =
            a['order'] is num
                ? a['order'] as num
                : 0;

        final num orderB =
            b['order'] is num
                ? b['order'] as num
                : 0;

        return orderA.compareTo(orderB);
      });

      return modules;
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ??
            'Unable to load course modules.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load course modules.',
      );
    }
  }

  // ============================================================
  // COUNT PUBLISHED MODULES
  // ============================================================

  Future<int> getCourseModuleCount(
    String courseId,
  ) async {
    final List<Map<String, dynamic>> modules =
        await getCourseModules(
      courseId,
    );

    return modules.length;
  }

  // ============================================================
  // GET STUDENTS ENROLLED IN COURSE
  // ============================================================

  Future<List<Map<String, dynamic>>> getCourseStudents(
    String courseId,
  ) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('enrollments')
              .where(
                'courseId',
                isEqualTo: courseId,
              )
              .get();

      final List<Map<String, dynamic>> students = [];

      for (final document in snapshot.docs) {
        final Map<String, dynamic> enrollment =
            document.data();

        final String status =
            (enrollment['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status != 'active') {
          continue;
        }

        final String studentId =
            (enrollment['studentId'] ?? '')
                .toString()
                .trim();

        if (studentId.isEmpty) {
          continue;
        }

        final DocumentSnapshot<Map<String, dynamic>>
            studentDocument =
            await _firestore
                .collection('users')
                .doc(studentId)
                .get();

        if (!studentDocument.exists) {
          continue;
        }

        final Map<String, dynamic>? studentData =
            studentDocument.data();

        if (studentData == null) {
          continue;
        }

        students.add({
          'id': studentDocument.id,
          ...studentData,
          'enrollmentId': document.id,
        });
      }

      students.sort((a, b) {
        final String nameA =
            (a['name'] ?? '').toString();

        final String nameB =
            (b['name'] ?? '').toString();

        return nameA.compareTo(nameB);
      });

      return students;
    } on FirebaseException catch (e) {
      throw CourseServiceException(
        e.message ??
            'Unable to load enrolled students.',
      );
    } catch (e) {
      throw CourseServiceException(
        'Unable to load enrolled students.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class CourseServiceException implements Exception {
  final String message;

  CourseServiceException(this.message);

  @override
  String toString() => message;
}