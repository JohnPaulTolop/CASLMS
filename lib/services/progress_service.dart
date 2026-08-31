import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId =>
      _auth.currentUser?.uid;

  // ============================================================
  // MODULE PROGRESS DOCUMENT ID
  // ============================================================

  String buildModuleProgressId({
    required String moduleId,
    required String studentId,
  }) {
    final String cleanModuleId =
        moduleId.trim();

    final String cleanStudentId =
        studentId.trim();

    if (cleanModuleId.isEmpty ||
        cleanStudentId.isEmpty) {
      return '';
    }

    return '${cleanModuleId}_$cleanStudentId';
  }

  // ============================================================
  // REQUIRE CURRENT STUDENT
  // ============================================================

  Future<User> _requireCurrentStudent() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw ProgressServiceException(
        'No student is currently logged in.',
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
      throw ProgressServiceException(
        'Student profile could not be found.',
      );
    }

    final Map<String, dynamic> data =
        userDocument.data()!;

    final String role =
        (data['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (role != 'student') {
      throw ProgressServiceException(
        'This feature is available to students only.',
      );
    }

    final String status =
        (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

    if (status != 'active') {
      throw ProgressServiceException(
        'This student account is not active.',
      );
    }

    return user;
  }

  // ============================================================
  // VERIFY ACTIVE ENROLLMENT
  // ============================================================

  Future<void> _verifyActiveEnrollment({
    required String courseId,
    required String studentId,
  }) async {
    final String cleanCourseId =
        courseId.trim();

    if (cleanCourseId.isEmpty) {
      throw ProgressServiceException(
        'Course ID is missing.',
      );
    }

    final String enrollmentId =
        '${cleanCourseId}_$studentId';

    final DocumentSnapshot<Map<String, dynamic>>
        enrollmentDocument =
        await _firestore
            .collection('enrollments')
            .doc(enrollmentId)
            .get();

    if (!enrollmentDocument.exists ||
        enrollmentDocument.data() == null) {
      throw ProgressServiceException(
        'You are not enrolled in this course.',
      );
    }

    final String status =
        (enrollmentDocument
                    .data()?['status'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (status != 'active') {
      throw ProgressServiceException(
        'Your enrollment in this course is not active.',
      );
    }
  }

  // ============================================================
  // MARK MODULE COMPLETE
  // ============================================================

  Future<void> markModuleComplete({
    required String moduleId,
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanModuleId =
          moduleId.trim();

      final String cleanCourseId =
          courseId.trim();

      if (cleanModuleId.isEmpty ||
          cleanCourseId.isEmpty) {
        throw ProgressServiceException(
          'Module information is incomplete.',
        );
      }

      await _verifyActiveEnrollment(
        courseId: cleanCourseId,
        studentId: user.uid,
      );

      final DocumentSnapshot<Map<String, dynamic>>
          moduleDocument =
          await _firestore
              .collection('modules')
              .doc(cleanModuleId)
              .get();

      if (!moduleDocument.exists ||
          moduleDocument.data() == null) {
        throw ProgressServiceException(
          'Module could not be found.',
        );
      }

      final Map<String, dynamic> module =
          moduleDocument.data()!;

      final String moduleCourseId =
          (module['courseId'] ?? '')
              .toString()
              .trim();

      if (moduleCourseId !=
          cleanCourseId) {
        throw ProgressServiceException(
          'This module does not belong to the selected course.',
        );
      }

      final String moduleStatus =
          (module['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (moduleStatus != 'published') {
        throw ProgressServiceException(
          'This module is not currently available.',
        );
      }

      final String progressId =
          buildModuleProgressId(
        moduleId: cleanModuleId,
        studentId: user.uid,
      );

      if (progressId.isEmpty) {
        throw ProgressServiceException(
          'Unable to create module progress record.',
        );
      }

      final DocumentReference<Map<String, dynamic>>
          reference =
          _firestore
              .collection('moduleProgress')
              .doc(progressId);

      final DocumentSnapshot<Map<String, dynamic>>
          existing =
          await reference.get();

      if (existing.exists) {
        await reference.set(
          {
            'moduleId':
                cleanModuleId,
            'courseId':
                cleanCourseId,
            'studentId':
                user.uid,
            'isCompleted':
                true,
            'completedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );

        return;
      }

      await reference.set({
        'moduleId':
            cleanModuleId,
        'courseId':
            cleanCourseId,
        'studentId':
            user.uid,
        'isCompleted':
            true,
        'completedAt':
            FieldValue.serverTimestamp(),
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to update module progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to update module progress.',
      );
    }
  }

  // ============================================================
  // MARK MODULE INCOMPLETE
  // ============================================================

  Future<void> markModuleIncomplete({
    required String moduleId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanModuleId =
          moduleId.trim();

      if (cleanModuleId.isEmpty) {
        return;
      }

      final String progressId =
          buildModuleProgressId(
        moduleId: cleanModuleId,
        studentId: user.uid,
      );

      if (progressId.isEmpty) {
        return;
      }

      final DocumentReference<Map<String, dynamic>>
          reference =
          _firestore
              .collection('moduleProgress')
              .doc(progressId);

      final DocumentSnapshot<Map<String, dynamic>>
          existing =
          await reference.get();

      if (!existing.exists) {
        return;
      }

      await reference.set(
        {
          'isCompleted':
              false,
          'completedAt':
              null,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to update module progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to update module progress.',
      );
    }
  }

  // ============================================================
  // WATCH MODULE COMPLETION
  // ============================================================

  Stream<bool> watchModuleCompleted({
    required String moduleId,
  }) {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return Stream.value(false);
    }

    final String cleanModuleId =
        moduleId.trim();

    if (cleanModuleId.isEmpty) {
      return Stream.value(false);
    }

    final String progressId =
        buildModuleProgressId(
      moduleId: cleanModuleId,
      studentId: user.uid,
    );

    if (progressId.isEmpty) {
      return Stream.value(false);
    }

    return _firestore
        .collection('moduleProgress')
        .doc(progressId)
        .snapshots()
        .map(
      (document) {
        if (!document.exists ||
            document.data() == null) {
          return false;
        }

        return document.data()![
                'isCompleted'] ==
            true;
      },
    );
  }

  // ============================================================
  // WATCH COMPLETED COURSE MODULES
  // ============================================================

  Stream<List<Map<String, dynamic>>>
      watchCompletedModulesForCourse({
    required String courseId,
  }) {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        courseId.trim().isEmpty) {
      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection('moduleProgress')
        .where(
          'studentId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .where(
          (document) {
            final data =
                document.data();

            return (data['courseId'] ?? '')
                        .toString() ==
                    courseId.trim() &&
                data['isCompleted'] ==
                    true;
          },
        )
            .map(
          (document) {
            return {
              ...document.data(),
              'id': document.id,
            };
          },
        ).toList();
      },
    );
  }

  // ============================================================
  // GET PUBLISHED MODULES FOR COURSE
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getPublishedModulesForCourse({
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return [];
      }

      await _verifyActiveEnrollment(
        courseId: cleanCourseId,
        studentId: user.uid,
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
          snapshot.docs
              .where(
        (document) {
          final String status =
              (document.data()['status'] ??
                      '')
                  .toString()
                  .trim()
                  .toLowerCase();

          return status ==
              'published';
        },
      )
              .map(
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

          return orderA.compareTo(
            orderB,
          );
        },
      );

      return modules;
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to load modules.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to load modules.',
      );
    }
  }

  // ============================================================
  // COURSE MODULE PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseModuleProgress({
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return _emptyModuleProgress();
      }

      final QuerySnapshot<Map<String, dynamic>>
          moduleSnapshot =
          await _firestore
              .collection('modules')
              .where(
                'courseId',
                isEqualTo: cleanCourseId,
              )
              .get();

      final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          publishedModules =
          moduleSnapshot.docs.where(
        (document) {
          return (document
                      .data()['status'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase() ==
              'published';
        },
      ).toList();

      final int totalModules =
          publishedModules.length;

      if (totalModules == 0) {
        return _emptyModuleProgress();
      }

      final Set<String> moduleIds =
          publishedModules
              .map(
                (document) =>
                    document.id,
              )
              .toSet();

      final QuerySnapshot<Map<String, dynamic>>
          progressSnapshot =
          await _firestore
              .collection(
                'moduleProgress',
              )
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final Set<String>
          completedIds =
          {};

      for (final document
          in progressSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String progressCourseId =
            (data['courseId'] ?? '')
                .toString();

        final String moduleId =
            (data['moduleId'] ?? '')
                .toString();

        if (progressCourseId ==
                cleanCourseId &&
            data['isCompleted'] ==
                true &&
            moduleIds.contains(
              moduleId,
            )) {
          completedIds.add(
            moduleId,
          );
        }
      }

      final int completedModules =
          completedIds.length;

      final int remainingModules =
          totalModules -
              completedModules;

      final double progress =
          (completedModules /
                  totalModules)
              .clamp(
                0.0,
                1.0,
              )
              .toDouble();

      return {
        'totalModules':
            totalModules,
        'completedModules':
            completedModules,
        'remainingModules':
            remainingModules,
        'progress':
            progress,
      };
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to calculate module progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate module progress.',
      );
    }
  }

  Map<String, dynamic>
      _emptyModuleProgress() {
    return {
      'totalModules': 0,
      'completedModules': 0,
      'remainingModules': 0,
      'progress': 0.0,
    };
  }

  // ============================================================
  // COURSE ASSIGNMENT PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseAssignmentProgress({
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return _emptyAssignmentProgress();
      }

      final QuerySnapshot<Map<String, dynamic>>
          assignmentSnapshot =
          await _firestore
              .collection('assignments')
              .where(
                'courseId',
                isEqualTo: cleanCourseId,
              )
              .get();

      final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          publishedAssignments =
          assignmentSnapshot.docs.where(
        (document) {
          return (document
                      .data()['status'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase() ==
              'published';
        },
      ).toList();

      final int totalAssignments =
          publishedAssignments.length;

      if (totalAssignments == 0) {
        return _emptyAssignmentProgress();
      }

      final Set<String> assignmentIds =
          publishedAssignments
              .map(
                (document) =>
                    document.id,
              )
              .toSet();

      final QuerySnapshot<Map<String, dynamic>>
          submissionSnapshot =
          await _firestore
              .collection('submissions')
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final Set<String>
          submittedIds =
          {};

      final Set<String>
          gradedIds =
          {};

      for (final document
          in submissionSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String submissionCourseId =
            (data['courseId'] ?? '')
                .toString()
                .trim();

        final String assignmentId =
            (data['assignmentId'] ?? '')
                .toString()
                .trim();

        if (submissionCourseId !=
                cleanCourseId ||
            !assignmentIds.contains(
              assignmentId,
            )) {
          continue;
        }

        final String status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        final bool completed =
            status == 'submitted' ||
                status ==
                    'under_review' ||
                status == 'late' ||
                status == 'graded';

        if (completed) {
          submittedIds.add(
            assignmentId,
          );
        }

        if (status == 'graded') {
          gradedIds.add(
            assignmentId,
          );
        }
      }

      final int submittedAssignments =
          submittedIds.length;

      final int gradedAssignments =
          gradedIds.length;

      final int remainingAssignments =
          totalAssignments -
              submittedAssignments;

      final double progress =
          (submittedAssignments /
                  totalAssignments)
              .clamp(
                0.0,
                1.0,
              )
              .toDouble();

      return {
        'totalAssignments':
            totalAssignments,
        'submittedAssignments':
            submittedAssignments,
        'gradedAssignments':
            gradedAssignments,
        'remainingAssignments':
            remainingAssignments,
        'progress':
            progress,
      };
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to calculate assignment progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate assignment progress.',
      );
    }
  }

  Map<String, dynamic>
      _emptyAssignmentProgress() {
    return {
      'totalAssignments': 0,
      'submittedAssignments': 0,
      'gradedAssignments': 0,
      'remainingAssignments': 0,
      'progress': 0.0,
    };
  }

  // ============================================================
  // COURSE QUIZ PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseQuizProgress({
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return _emptyQuizProgress();
      }

      final QuerySnapshot<Map<String, dynamic>>
          quizSnapshot =
          await _firestore
              .collection('quizzes')
              .where(
                'courseId',
                isEqualTo: cleanCourseId,
              )
              .get();

      final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          publishedQuizzes =
          quizSnapshot.docs.where(
        (document) {
          return (document
                      .data()['status'] ??
                  '')
              .toString()
              .trim()
              .toLowerCase() ==
              'published';
        },
      ).toList();

      final int totalQuizzes =
          publishedQuizzes.length;

      if (totalQuizzes == 0) {
        return _emptyQuizProgress();
      }

      final Map<String, Map<String, dynamic>>
          quizById = {
        for (final document
            in publishedQuizzes)
          document.id:
              document.data(),
      };

      final QuerySnapshot<Map<String, dynamic>>
          attemptSnapshot =
          await _firestore
              .collection('quiz_attempts')
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final Set<String>
          completedQuizIds =
          {};

      final Set<String>
          inProgressQuizIds =
          {};

      final Set<String>
          passedQuizIds =
          {};

      int earnedPoints = 0;
      int availablePoints = 0;

      for (final document
          in attemptSnapshot.docs) {
        final Map<String, dynamic> attempt =
            document.data();

        final String attemptCourseId =
            (attempt['courseId'] ?? '')
                .toString()
                .trim();

        final String quizId =
            (attempt['quizId'] ?? '')
                .toString()
                .trim();

        if (attemptCourseId !=
                cleanCourseId ||
            !quizById.containsKey(
              quizId,
            )) {
          continue;
        }

        final String status =
            (attempt['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status == 'in_progress') {
          if (!completedQuizIds.contains(
            quizId,
          )) {
            inProgressQuizIds.add(
              quizId,
            );
          }

          continue;
        }

        if (status != 'submitted') {
          continue;
        }

        if (completedQuizIds.contains(
          quizId,
        )) {
          continue;
        }

        completedQuizIds.add(
          quizId,
        );

        inProgressQuizIds.remove(
          quizId,
        );

        final Map<String, dynamic> quiz =
            quizById[quizId] ??
                {};

        final int score =
            attempt['score'] is num
                ? (attempt['score'] as num)
                    .toInt()
                : 0;

        final int totalPoints =
            attempt['totalPoints']
                    is num
                ? (attempt['totalPoints']
                        as num)
                    .toInt()
                : quiz['totalPoints']
                        is num
                    ? (quiz['totalPoints']
                            as num)
                        .toInt()
                    : 0;

        final int passingScore =
            quiz['passingScore'] is num
                ? (quiz['passingScore']
                        as num)
                    .toInt()
                : 0;

        earnedPoints +=
            score;

        if (totalPoints > 0) {
          availablePoints +=
              totalPoints;
        }

        if (score >= passingScore) {
          passedQuizIds.add(
            quizId,
          );
        }
      }

      final int completedQuizzes =
          completedQuizIds.length;

      final int inProgressQuizzes =
          inProgressQuizIds.length;

      final int passedQuizzes =
          passedQuizIds.length;

      final int remainingQuizzes =
          totalQuizzes -
              completedQuizzes;

      final double progress =
          (completedQuizzes /
                  totalQuizzes)
              .clamp(
                0.0,
                1.0,
              )
              .toDouble();

      final double scorePercentage =
          availablePoints == 0
              ? 0.0
              : (earnedPoints /
                      availablePoints)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

      return {
        'totalQuizzes':
            totalQuizzes,
        'completedQuizzes':
            completedQuizzes,
        'inProgressQuizzes':
            inProgressQuizzes,
        'passedQuizzes':
            passedQuizzes,
        'remainingQuizzes':
            remainingQuizzes,
        'earnedPoints':
            earnedPoints,
        'availablePoints':
            availablePoints,
        'scorePercentage':
            scorePercentage,
        'progress':
            progress,
      };
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to calculate quiz progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate quiz progress.',
      );
    }
  }

  Map<String, dynamic>
      _emptyQuizProgress() {
    return {
      'totalQuizzes': 0,
      'completedQuizzes': 0,
      'inProgressQuizzes': 0,
      'passedQuizzes': 0,
      'remainingQuizzes': 0,
      'earnedPoints': 0,
      'availablePoints': 0,
      'scorePercentage': 0.0,
      'progress': 0.0,
    };
  }

  // ============================================================
  // COURSE LEARNING PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseLearningProgress({
    required String courseId,
  }) async {
    try {
      final List<Map<String, dynamic>>
          results =
          await Future.wait([
        getCourseModuleProgress(
          courseId: courseId,
        ),
        getCourseAssignmentProgress(
          courseId: courseId,
        ),
        getCourseQuizProgress(
          courseId: courseId,
        ),
      ]);

      final Map<String, dynamic>
          modules =
          results[0];

      final Map<String, dynamic>
          assignments =
          results[1];

      final Map<String, dynamic>
          quizzes =
          results[2];

      final int totalModules =
          (modules['totalModules']
                      as num?)
                  ?.toInt() ??
              0;

      final int completedModules =
          (modules['completedModules']
                      as num?)
                  ?.toInt() ??
              0;

      final int totalAssignments =
          (assignments[
                      'totalAssignments']
                  as num?)
              ?.toInt() ??
          0;

      final int submittedAssignments =
          (assignments[
                      'submittedAssignments']
                  as num?)
              ?.toInt() ??
          0;

      final int totalQuizzes =
          (quizzes['totalQuizzes']
                      as num?)
                  ?.toInt() ??
              0;

      final int completedQuizzes =
          (quizzes[
                      'completedQuizzes']
                  as num?)
              ?.toInt() ??
          0;

      final int totalItems =
          totalModules +
              totalAssignments +
              totalQuizzes;

      final int completedItems =
          completedModules +
              submittedAssignments +
              completedQuizzes;

      final int remainingItems =
          totalItems -
              completedItems;

      final double learningProgress =
          totalItems == 0
              ? 0.0
              : (completedItems /
                      totalItems)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

      return {
        'moduleProgress':
            modules['progress'],
        'totalModules':
            totalModules,
        'completedModules':
            completedModules,
        'remainingModules':
            modules[
                'remainingModules'],

        'assignmentProgress':
            assignments[
                'progress'],
        'totalAssignments':
            totalAssignments,
        'submittedAssignments':
            submittedAssignments,
        'gradedAssignments':
            assignments[
                'gradedAssignments'],
        'remainingAssignments':
            assignments[
                'remainingAssignments'],

        'quizProgress':
            quizzes['progress'],
        'totalQuizzes':
            totalQuizzes,
        'completedQuizzes':
            completedQuizzes,
        'inProgressQuizzes':
            quizzes[
                'inProgressQuizzes'],
        'passedQuizzes':
            quizzes[
                'passedQuizzes'],
        'remainingQuizzes':
            quizzes[
                'remainingQuizzes'],
        'quizEarnedPoints':
            quizzes[
                'earnedPoints'],
        'quizAvailablePoints':
            quizzes[
                'availablePoints'],
        'quizScorePercentage':
            quizzes[
                'scorePercentage'],

        'totalItems':
            totalItems,
        'completedItems':
            completedItems,
        'remainingItems':
            remainingItems,
        'learningProgress':
            learningProgress,
      };
    } on ProgressServiceException {
      rethrow;
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate course learning progress.',
      );
    }
  }

  // ============================================================
  // ASSIGNMENT ACADEMIC PERFORMANCE
  //
  // ONLY graded assignments contribute.
  // Ungraded submissions are not counted as zero.
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseAssignmentPerformance({
    required String courseId,
  }) async {
    try {
      final User user =
          await _requireCurrentStudent();

      final String cleanCourseId =
          courseId.trim();

      if (cleanCourseId.isEmpty) {
        return _emptyPerformance();
      }

      final QuerySnapshot<Map<String, dynamic>>
          assignmentSnapshot =
          await _firestore
              .collection('assignments')
              .where(
                'courseId',
                isEqualTo: cleanCourseId,
              )
              .get();

      final Map<String, Map<String, dynamic>>
          publishedAssignments =
          {};

      for (final document
          in assignmentSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status == 'published') {
          publishedAssignments[
              document.id] = data;
        }
      }

      if (publishedAssignments.isEmpty) {
        return _emptyPerformance();
      }

      final QuerySnapshot<Map<String, dynamic>>
          submissionSnapshot =
          await _firestore
              .collection('submissions')
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final Set<String>
          countedAssignments =
          {};

      int gradedAssignments = 0;
      int earnedPoints = 0;
      int availablePoints = 0;

      for (final document
          in submissionSnapshot.docs) {
        final Map<String, dynamic> submission =
            document.data();

        final String submissionCourseId =
            (submission['courseId'] ?? '')
                .toString()
                .trim();

        final String assignmentId =
            (submission['assignmentId'] ?? '')
                .toString()
                .trim();

        if (submissionCourseId !=
                cleanCourseId ||
            !publishedAssignments.containsKey(
              assignmentId,
            )) {
          continue;
        }

        final String status =
            (submission['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status != 'graded') {
          continue;
        }

        if (countedAssignments.contains(
          assignmentId,
        )) {
          continue;
        }

        final Map<String, dynamic>
            assignment =
            publishedAssignments[
                    assignmentId] ??
                {};

        final int maximumPoints =
            assignment['points'] is num
                ? (assignment['points']
                        as num)
                    .toInt()
                : 0;

        final int score =
            submission['score'] is num
                ? (submission['score']
                        as num)
                    .toInt()
                : 0;

        countedAssignments.add(
          assignmentId,
        );

        gradedAssignments++;

        earnedPoints +=
            score;

        if (maximumPoints > 0) {
          availablePoints +=
              maximumPoints;
        }
      }

      final double percentage =
          availablePoints == 0
              ? 0.0
              : (earnedPoints /
                      availablePoints)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

      return {
        'gradedAssignments':
            gradedAssignments,
        'earnedPoints':
            earnedPoints,
        'availablePoints':
            availablePoints,
        'percentage':
            percentage,
        'hasGrades':
            availablePoints > 0,
      };
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to calculate assignment performance.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate assignment performance.',
      );
    }
  }

  Map<String, dynamic>
      _emptyPerformance() {
    return {
      'gradedAssignments': 0,
      'earnedPoints': 0,
      'availablePoints': 0,
      'percentage': 0.0,
      'hasGrades': false,
    };
  }

  // ============================================================
  // QUIZ ACADEMIC PERFORMANCE
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseQuizPerformance({
    required String courseId,
  }) async {
    try {
      final Map<String, dynamic> quiz =
          await getCourseQuizProgress(
        courseId: courseId,
      );

      final int earned =
          (quiz['earnedPoints']
                      as num?)
                  ?.toInt() ??
              0;

      final int available =
          (quiz['availablePoints']
                      as num?)
                  ?.toInt() ??
              0;

      return {
        'completedQuizzes':
            quiz[
                'completedQuizzes'],
        'passedQuizzes':
            quiz[
                'passedQuizzes'],
        'earnedPoints':
            earned,
        'availablePoints':
            available,
        'percentage':
            quiz[
                'scorePercentage'],
        'hasGrades':
            available > 0,
      };
    } on ProgressServiceException {
      rethrow;
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate quiz performance.',
      );
    }
  }

  // ============================================================
  // COMBINED COURSE ACADEMIC PERFORMANCE
  // ============================================================

  Future<Map<String, dynamic>>
      getCourseAcademicPerformance({
    required String courseId,
  }) async {
    try {
      final List<Map<String, dynamic>>
          results =
          await Future.wait([
        getCourseAssignmentPerformance(
          courseId: courseId,
        ),
        getCourseQuizPerformance(
          courseId: courseId,
        ),
      ]);

      final Map<String, dynamic>
          assignment =
          results[0];

      final Map<String, dynamic> quiz =
          results[1];

      final int assignmentEarned =
          (assignment[
                      'earnedPoints']
                  as num?)
              ?.toInt() ??
          0;

      final int assignmentAvailable =
          (assignment[
                      'availablePoints']
                  as num?)
              ?.toInt() ??
          0;

      final int quizEarned =
          (quiz['earnedPoints']
                      as num?)
                  ?.toInt() ??
              0;

      final int quizAvailable =
          (quiz['availablePoints']
                      as num?)
                  ?.toInt() ??
              0;

      final int earnedPoints =
          assignmentEarned +
              quizEarned;

      final int availablePoints =
          assignmentAvailable +
              quizAvailable;

      final double percentage =
          availablePoints == 0
              ? 0.0
              : (earnedPoints /
                      availablePoints)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

      return {
        'gradedAssignments':
            assignment[
                'gradedAssignments'],

        'assignmentEarnedPoints':
            assignmentEarned,

        'assignmentAvailablePoints':
            assignmentAvailable,

        'assignmentPercentage':
            assignment[
                'percentage'],

        'completedQuizzes':
            quiz[
                'completedQuizzes'],

        'passedQuizzes':
            quiz[
                'passedQuizzes'],

        'quizEarnedPoints':
            quizEarned,

        'quizAvailablePoints':
            quizAvailable,

        'quizPercentage':
            quiz['percentage'],

        'earnedPoints':
            earnedPoints,

        'availablePoints':
            availablePoints,

        'percentage':
            percentage,

        'hasGrades':
            availablePoints > 0,
      };
    } on ProgressServiceException {
      rethrow;
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate academic performance.',
      );
    }
  }

  // ============================================================
  // STUDENT ACTIVE COURSES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStudentCourses() async {
    try {
      final User user =
          await _requireCurrentStudent();

      final QuerySnapshot<Map<String, dynamic>>
          enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where(
                'studentId',
                isEqualTo: user.uid,
              )
              .get();

      final List<Map<String, dynamic>> courses =
          [];

      final Set<String> addedCourseIds =
          {};

      for (final enrollment
          in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollmentData =
            enrollment.data();

        final String enrollmentStatus =
            (enrollmentData['status'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String courseId =
            (enrollmentData['courseId'] ??
                    '')
                .toString()
                .trim();

        if (courseId.isEmpty ||
            addedCourseIds.contains(
              courseId,
            )) {
          continue;
        }

        final DocumentSnapshot<Map<String, dynamic>>
            courseDocument =
            await _firestore
                .collection('courses')
                .doc(courseId)
                .get();

        if (!courseDocument.exists ||
            courseDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> course =
            courseDocument.data()!;

        final String courseStatus =
            (course['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        final Map<String, dynamic>
            learning =
            await getCourseLearningProgress(
          courseId: courseId,
        );

        addedCourseIds.add(
          courseId,
        );

        courses.add({
          ...course,

          'id':
              courseDocument.id,

          'courseId':
              courseDocument.id,

          ...learning,
        });
      }

      courses.sort(
        (a, b) {
          return (a['code'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['code'] ?? '')
                    .toString()
                    .toLowerCase(),
              );
        },
      );

      return courses;
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to load student progress.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to load student progress.',
      );
    }
  }

  // ============================================================
  // OVERALL MODULE PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getOverallModuleProgress() async {
    try {
      final List<Map<String, dynamic>>
          courses =
          await getStudentCourses();

      int totalModules = 0;
      int completedModules = 0;

      for (final course in courses) {
        totalModules +=
            (course['totalModules']
                        as num?)
                    ?.toInt() ??
                0;

        completedModules +=
            (course['completedModules']
                        as num?)
                    ?.toInt() ??
                0;
      }

      final int remainingModules =
          totalModules -
              completedModules;

      final double progress =
          totalModules == 0
              ? 0.0
              : (completedModules /
                      totalModules)
                  .clamp(
                    0.0,
                    1.0,
                  )
                  .toDouble();

      return {
        'courseCount':
            courses.length,
        'totalModules':
            totalModules,
        'completedModules':
            completedModules,
        'remainingModules':
            remainingModules,
        'progress':
            progress,
        'courses':
            courses,
      };
    } on ProgressServiceException {
      rethrow;
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate overall module progress.',
      );
    }
  }

  // ============================================================
  // OVERALL LEARNING PROGRESS
  // ============================================================

  Future<Map<String, dynamic>>
      getOverallLearningProgress() async {
    try {
      final List<Map<String, dynamic>>
          courses =
          await getStudentCourses();

      int totalModules = 0;
      int completedModules = 0;

      int totalAssignments = 0;
      int submittedAssignments = 0;
      int gradedAssignments = 0;

      int totalQuizzes = 0;
      int completedQuizzes = 0;
      int passedQuizzes = 0;
      int inProgressQuizzes = 0;

      int totalItems = 0;
      int completedItems = 0;

      for (final course in courses) {
        totalModules +=
            (course['totalModules']
                        as num?)
                    ?.toInt() ??
                0;

        completedModules +=
            (course['completedModules']
                        as num?)
                    ?.toInt() ??
                0;

        totalAssignments +=
            (course['totalAssignments']
                        as num?)
                    ?.toInt() ??
                0;

        submittedAssignments +=
            (course['submittedAssignments']
                        as num?)
                    ?.toInt() ??
                0;

        gradedAssignments +=
            (course['gradedAssignments']
                        as num?)
                    ?.toInt() ??
                0;

        totalQuizzes +=
            (course['totalQuizzes']
                        as num?)
                    ?.toInt() ??
                0;

        completedQuizzes +=
            (course['completedQuizzes']
                        as num?)
                    ?.toInt() ??
                0;

        passedQuizzes +=
            (course['passedQuizzes']
                        as num?)
                    ?.toInt() ??
                0;

        inProgressQuizzes +=
            (course['inProgressQuizzes']
                        as num?)
                    ?.toInt() ??
                0;

        totalItems +=
            (course['totalItems']
                        as num?)
                    ?.toInt() ??
                0;

        completedItems +=
            (course['completedItems']
                        as num?)
                    ?.toInt() ??
                0;
      }

      final int remainingModules =
          totalModules -
              completedModules;

      final int remainingAssignments =
          totalAssignments -
              submittedAssignments;

      final int remainingQuizzes =
          totalQuizzes -
              completedQuizzes;

      final int remainingItems =
          totalItems -
              completedItems;

      final double moduleProgress =
          totalModules == 0
              ? 0.0
              : completedModules /
                  totalModules;

      final double assignmentProgress =
          totalAssignments == 0
              ? 0.0
              : submittedAssignments /
                  totalAssignments;

      final double quizProgress =
          totalQuizzes == 0
              ? 0.0
              : completedQuizzes /
                  totalQuizzes;

      final double learningProgress =
          totalItems == 0
              ? 0.0
              : completedItems /
                  totalItems;

      return {
        'courseCount':
            courses.length,

        'totalModules':
            totalModules,
        'completedModules':
            completedModules,
        'remainingModules':
            remainingModules,
        'moduleProgress':
            moduleProgress,

        'totalAssignments':
            totalAssignments,
        'submittedAssignments':
            submittedAssignments,
        'gradedAssignments':
            gradedAssignments,
        'remainingAssignments':
            remainingAssignments,
        'assignmentProgress':
            assignmentProgress,

        'totalQuizzes':
            totalQuizzes,
        'completedQuizzes':
            completedQuizzes,
        'passedQuizzes':
            passedQuizzes,
        'inProgressQuizzes':
            inProgressQuizzes,
        'remainingQuizzes':
            remainingQuizzes,
        'quizProgress':
            quizProgress,

        'totalItems':
            totalItems,
        'completedItems':
            completedItems,
        'remainingItems':
            remainingItems,
        'learningProgress':
            learningProgress,

        'courses':
            courses,
      };
    } on ProgressServiceException {
      rethrow;
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate learning progress.',
      );
    }
  }

  // ============================================================
  // OVERALL ACADEMIC PERFORMANCE
  // ============================================================

  Future<Map<String, dynamic>>
      getOverallAcademicPerformance() async {
    try {
      final List<Map<String, dynamic>>
          courses =
          await getStudentCourses();

      final List<Map<String, dynamic>>
          results =
          [];

      int assignmentEarned = 0;
      int assignmentAvailable = 0;

      int quizEarned = 0;
      int quizAvailable = 0;

      int gradedAssignments = 0;
      int completedQuizzes = 0;
      int passedQuizzes = 0;

      for (final course in courses) {
        final String courseId =
            (course['courseId'] ??
                    course['id'] ??
                    '')
                .toString();

        if (courseId.isEmpty) {
          continue;
        }

        final Map<String, dynamic>
            performance =
            await getCourseAcademicPerformance(
          courseId: courseId,
        );

        assignmentEarned +=
            (performance[
                        'assignmentEarnedPoints']
                    as num?)
                ?.toInt() ??
            0;

        assignmentAvailable +=
            (performance[
                        'assignmentAvailablePoints']
                    as num?)
                ?.toInt() ??
            0;

        quizEarned +=
            (performance[
                        'quizEarnedPoints']
                    as num?)
                ?.toInt() ??
            0;

        quizAvailable +=
            (performance[
                        'quizAvailablePoints']
                    as num?)
                ?.toInt() ??
            0;

        gradedAssignments +=
            (performance[
                        'gradedAssignments']
                    as num?)
                ?.toInt() ??
            0;

        completedQuizzes +=
            (performance[
                        'completedQuizzes']
                    as num?)
                ?.toInt() ??
            0;

        passedQuizzes +=
            (performance[
                        'passedQuizzes']
                    as num?)
                ?.toInt() ??
            0;

        results.add({
          ...course,

          'academicPerformance':
              performance[
                  'percentage'],

          'academicEarnedPoints':
              performance[
                  'earnedPoints'],

          'academicAvailablePoints':
              performance[
                  'availablePoints'],

          'hasGrades':
              performance[
                  'hasGrades'],

          'assignmentPerformance':
              performance[
                  'assignmentPercentage'],

          'quizPerformance':
              performance[
                  'quizPercentage'],
        });
      }

      final int earnedPoints =
          assignmentEarned +
              quizEarned;

      final int availablePoints =
          assignmentAvailable +
              quizAvailable;

      final double assignmentPercentage =
          assignmentAvailable == 0
              ? 0.0
              : assignmentEarned /
                  assignmentAvailable;

      final double quizPercentage =
          quizAvailable == 0
              ? 0.0
              : quizEarned /
                  quizAvailable;

      final double percentage =
          availablePoints == 0
              ? 0.0
              : earnedPoints /
                  availablePoints;

      return {
        'courseCount':
            courses.length,

        'gradedAssignments':
            gradedAssignments,

        'assignmentEarnedPoints':
            assignmentEarned,

        'assignmentAvailablePoints':
            assignmentAvailable,

        'assignmentPercentage':
            assignmentPercentage,

        'completedQuizzes':
            completedQuizzes,

        'passedQuizzes':
            passedQuizzes,

        'quizEarnedPoints':
            quizEarned,

        'quizAvailablePoints':
            quizAvailable,

        'quizPercentage':
            quizPercentage,

        'earnedPoints':
            earnedPoints,

        'availablePoints':
            availablePoints,

        'percentage':
            percentage,

        'hasGrades':
            availablePoints > 0,

        'courses':
            results,
      };
    } on ProgressServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ProgressServiceException(
        e.message ??
            'Unable to calculate academic performance.',
      );
    } catch (_) {
      throw ProgressServiceException(
        'Unable to calculate academic performance.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class ProgressServiceException implements Exception {
  final String message;

  ProgressServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}