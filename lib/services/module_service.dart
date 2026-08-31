import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModuleService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? get currentUserId =>
      _auth.currentUser?.uid;

  // ============================================================
  // REQUIRE ACTIVE INSTRUCTOR
  // ============================================================

  Future<User> _requireInstructor() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw ModuleServiceException(
        'No instructor is currently logged in.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        userDocument =
        await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

    if (!userDocument.exists ||
        userDocument.data() == null) {
      throw ModuleServiceException(
        'Instructor profile could not be found.',
      );
    }

    final Map<String, dynamic> userData =
        userDocument.data()!;

    final String role =
        (userData['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (role != 'instructor') {
      throw ModuleServiceException(
        'Only instructors can manage course modules.',
      );
    }

    final String status =
        (userData['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

    if (status != 'active') {
      throw ModuleServiceException(
        'This instructor account is not active.',
      );
    }

    return user;
  }

  // ============================================================
  // VERIFY COURSE OWNERSHIP
  // ============================================================

  Future<Map<String, dynamic>>
      _requireOwnedCourse({
    required String courseId,
    required String instructorId,
  }) async {
    final String cleanCourseId =
        courseId.trim();

    if (cleanCourseId.isEmpty) {
      throw ModuleServiceException(
        'Course ID is missing.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>
        courseDocument =
        await _firestore
            .collection('courses')
            .doc(cleanCourseId)
            .get();

    if (!courseDocument.exists ||
        courseDocument.data() == null) {
      throw ModuleServiceException(
        'Course could not be found.',
      );
    }

    final Map<String, dynamic> course =
        courseDocument.data()!;

    final String ownerId =
        (course['instructorId'] ?? '')
            .toString()
            .trim();

    if (ownerId != instructorId) {
      throw ModuleServiceException(
        'You do not have permission to manage this course.',
      );
    }

    final String courseStatus =
        (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (courseStatus != 'active') {
      throw ModuleServiceException(
        'Modules can only be created for active courses.',
      );
    }

    return {
      ...course,
      'id': courseDocument.id,
    };
  }

  // ============================================================
  // GET COURSE MODULES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getCourseModules({
    required String courseId,
  }) async {
    try {
      final User instructor =
          await _requireInstructor();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return [];
      }

      await _requireOwnedCourse(
        courseId: cleanCourseId,
        instructorId: instructor.uid,
      );

      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _firestore
              .collection('modules')
              .where(
                'courseId',
                isEqualTo: cleanCourseId,
              )
              .get();

      final List<Map<String, dynamic>> modules =
          snapshot.docs.map(
        (document) {
          return {
            ...document.data(),
            'id': document.id,
            'moduleId': document.id,
          };
        },
      ).toList();

      modules.sort(
        (a, b) {
          final int orderA =
              (a['order'] as num?)
                      ?.toInt() ??
                  0;

          final int orderB =
              (b['order'] as num?)
                      ?.toInt() ??
                  0;

          if (orderA != orderB) {
            return orderA.compareTo(
              orderB,
            );
          }

          return (a['title'] ?? '')
              .toString()
              .compareTo(
                (b['title'] ?? '')
                    .toString(),
              );
        },
      );

      return modules;
    } on ModuleServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ModuleServiceException(
        e.message ??
            'Unable to load course modules.',
      );
    } catch (_) {
      throw ModuleServiceException(
        'Unable to load course modules.',
      );
    }
  }

  // ============================================================
  // NEXT MODULE ORDER
  // ============================================================

  Future<int> getNextModuleOrder({
    required String courseId,
  }) async {
    try {
      final List<Map<String, dynamic>>
          modules =
          await getCourseModules(
        courseId: courseId,
      );

      if (modules.isEmpty) {
        return 1;
      }

      int highestOrder = 0;

      for (final module in modules) {
        final int order =
            (module['order'] as num?)
                    ?.toInt() ??
                0;

        if (order > highestOrder) {
          highestOrder = order;
        }
      }

      return highestOrder + 1;
    } on ModuleServiceException {
      rethrow;
    } catch (_) {
      return 1;
    }
  }

  // ============================================================
  // CREATE MODULE
  // ============================================================

  Future<String> createModule({
    required String courseId,
    required String title,
    required String description,
    required int order,
    String status = 'published',
  }) async {
    try {
      final User instructor =
          await _requireInstructor();

      final String cleanCourseId =
          courseId.trim();

      final String cleanTitle =
          title.trim();

      final String cleanDescription =
          description.trim();

      final String cleanStatus =
          status
              .trim()
              .toLowerCase();

      if (cleanCourseId.isEmpty) {
        throw ModuleServiceException(
          'Course ID is missing.',
        );
      }

      if (cleanTitle.isEmpty) {
        throw ModuleServiceException(
          'Module title is required.',
        );
      }

      if (cleanDescription.isEmpty) {
        throw ModuleServiceException(
          'Module description is required.',
        );
      }

      if (order <= 0) {
        throw ModuleServiceException(
          'Module order must be greater than zero.',
        );
      }

      if (cleanStatus != 'draft' &&
          cleanStatus != 'published') {
        throw ModuleServiceException(
          'Invalid module status.',
        );
      }

      await _requireOwnedCourse(
        courseId: cleanCourseId,
        instructorId: instructor.uid,
      );

      final DocumentReference<Map<String, dynamic>>
          document =
          await _firestore
              .collection('modules')
              .add({
        'courseId':
            cleanCourseId,

        'title':
            cleanTitle,

        'description':
            cleanDescription,

        'order':
            order,

        'status':
            cleanStatus,

        'createdBy':
            instructor.uid,

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      return document.id;
    } on ModuleServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ModuleServiceException(
        e.message ??
            'Unable to create module.',
      );
    } catch (_) {
      throw ModuleServiceException(
        'Unable to create module.',
      );
    }
  }

  // ============================================================
  // UPDATE MODULE STATUS
  // ============================================================

  Future<void> updateModuleStatus({
    required String moduleId,
    required String status,
  }) async {
    try {
      final User instructor =
          await _requireInstructor();

      final String cleanModuleId =
          moduleId.trim();

      final String cleanStatus =
          status
              .trim()
              .toLowerCase();

      if (cleanModuleId.isEmpty) {
        throw ModuleServiceException(
          'Module ID is missing.',
        );
      }

      if (cleanStatus != 'draft' &&
          cleanStatus != 'published') {
        throw ModuleServiceException(
          'Invalid module status.',
        );
      }

      final DocumentSnapshot<Map<String, dynamic>>
          moduleDocument =
          await _firestore
              .collection('modules')
              .doc(cleanModuleId)
              .get();

      if (!moduleDocument.exists ||
          moduleDocument.data() == null) {
        throw ModuleServiceException(
          'Module could not be found.',
        );
      }

      final Map<String, dynamic> module =
          moduleDocument.data()!;

      final String courseId =
          (module['courseId'] ?? '')
              .toString()
              .trim();

      await _requireOwnedCourse(
        courseId: courseId,
        instructorId: instructor.uid,
      );

      await _firestore
          .collection('modules')
          .doc(cleanModuleId)
          .update({
        'status':
            cleanStatus,

        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on ModuleServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ModuleServiceException(
        e.message ??
            'Unable to update module.',
      );
    } catch (_) {
      throw ModuleServiceException(
        'Unable to update module.',
      );
    }
  }

  // ============================================================
  // DELETE MODULE
  // ============================================================

  Future<void> deleteModule({
    required String moduleId,
  }) async {
    try {
      final User instructor =
          await _requireInstructor();

      final String cleanModuleId =
          moduleId.trim();

      if (cleanModuleId.isEmpty) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          moduleDocument =
          await _firestore
              .collection('modules')
              .doc(cleanModuleId)
              .get();

      if (!moduleDocument.exists ||
          moduleDocument.data() == null) {
        return;
      }

      final String courseId =
          (moduleDocument
                      .data()?['courseId'] ??
                  '')
              .toString()
              .trim();

      await _requireOwnedCourse(
        courseId: courseId,
        instructorId: instructor.uid,
      );

      await _firestore
          .collection('modules')
          .doc(cleanModuleId)
          .delete();
    } on ModuleServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ModuleServiceException(
        e.message ??
            'Unable to delete module.',
      );
    } catch (_) {
      throw ModuleServiceException(
        'Unable to delete module.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class ModuleServiceException implements Exception {
  final String message;

  ModuleServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}