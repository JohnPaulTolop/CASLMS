import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AssignmentService {
  AssignmentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _notificationService =
           notificationService ??
           NotificationService(firestore: firestore, auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================
  // GET ONE ASSIGNMENT
  // ============================================================

  Future<Map<String, dynamic>?> getAssignmentById(String assignmentId) async {
    try {
      if (assignmentId.trim().isEmpty) {
        return null;
      }

      final document = await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .get();

      if (!document.exists) {
        return null;
      }

      final data = document.data();

      if (data == null) {
        return null;
      }

      return {'id': document.id, ...data};
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load assignment.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load assignment.');
    }
  }

  // ============================================================
  // GET STUDENT ACTIVE COURSE IDS
  // ============================================================

  Future<List<String>> _getStudentCourseIds(String studentId) async {
    final snapshot = await _firestore
        .collection('enrollments')
        .where('studentId', isEqualTo: studentId)
        .get();

    final List<String> courseIds = [];

    for (final document in snapshot.docs) {
      final data = document.data();

      final status = (data['status'] ?? '').toString().trim().toLowerCase();

      if (status != 'active') {
        continue;
      }

      final courseId = (data['courseId'] ?? '').toString().trim();

      if (courseId.isNotEmpty) {
        courseIds.add(courseId);
      }
    }

    return courseIds;
  }

  // ============================================================
  // GET STUDENT ASSIGNMENTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getStudentAssignments() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw AssignmentServiceException('No student is currently logged in.');
      }

      final courseIds = await _getStudentCourseIds(user.uid);

      if (courseIds.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> assignments = [];

      for (final courseId in courseIds) {
        // --------------------------------------------------------
        // Get published assignments for this course
        // --------------------------------------------------------

        final assignmentSnapshot = await _firestore
            .collection('assignments')
            .where('courseId', isEqualTo: courseId)
            .get();

        // --------------------------------------------------------
        // Get course information for display
        // --------------------------------------------------------

        final courseDocument = await _firestore
            .collection('courses')
            .doc(courseId)
            .get();

        final courseData = courseDocument.data();

        final courseCode = (courseData?['code'] ?? '').toString();

        final courseTitle = (courseData?['title'] ?? 'Course').toString();

        for (final assignmentDocument in assignmentSnapshot.docs) {
          final assignment = assignmentDocument.data();

          final status = (assignment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (status != 'published') {
            continue;
          }

          // ------------------------------------------------------
          // Check if this student already submitted
          // ------------------------------------------------------

          final submissionSnapshot = await _firestore
              .collection('submissions')
              .where('assignmentId', isEqualTo: assignmentDocument.id)
              .where('studentId', isEqualTo: user.uid)
              .limit(1)
              .get();

          Map<String, dynamic>? submission;

          if (submissionSnapshot.docs.isNotEmpty) {
            final submissionDocument = submissionSnapshot.docs.first;

            submission = {
              'id': submissionDocument.id,
              ...submissionDocument.data(),
            };
          }

          assignments.add({
            'id': assignmentDocument.id,
            ...assignment,

            // Course display information
            'courseCode': courseCode,
            'courseTitle': courseTitle,

            // Student submission
            'submission': submission,
          });
        }
      }

      // ----------------------------------------------------------
      // Sort by due date
      // ----------------------------------------------------------

      assignments.sort((a, b) {
        final dueA = a['dueAt'];
        final dueB = b['dueAt'];

        if (dueA is Timestamp && dueB is Timestamp) {
          return dueA.toDate().compareTo(dueB.toDate());
        }

        if (dueA is Timestamp) {
          return -1;
        }

        if (dueB is Timestamp) {
          return 1;
        }

        return 0;
      });

      return assignments;
    } on AssignmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load assignments.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load assignments.');
    }
  }

  // ============================================================
  // GET STUDENT SUBMISSION
  // ============================================================

  Future<Map<String, dynamic>?> getMySubmission(String assignmentId) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return null;
      }

      final snapshot = await _firestore
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final document = snapshot.docs.first;

      return {'id': document.id, ...document.data()};
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load submission.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load submission.');
    }
  }

  // ============================================================
  // SUBMIT TEXT / LINK ASSIGNMENT
  // ============================================================

  Future<void> submitAssignment({
    required String assignmentId,
    required String courseId,
    required String answerText,
    String fileUrl = '',
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw AssignmentServiceException('You must be logged in to submit.');
      }

      if (assignmentId.trim().isEmpty) {
        throw AssignmentServiceException('Assignment ID is missing.');
      }

      if (courseId.trim().isEmpty) {
        throw AssignmentServiceException('Course ID is missing.');
      }

      // ----------------------------------------------------------
      // Check for an existing submission
      // ----------------------------------------------------------

      final existingSnapshot = await _firestore
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      final submissionData = {
        'assignmentId': assignmentId,
        'courseId': courseId,
        'studentId': user.uid,
        'answerText': answerText.trim(),
        'fileUrl': fileUrl.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'score': 0,
        'feedback': '',
      };

      // ----------------------------------------------------------
      // Update existing submission
      // ----------------------------------------------------------

      if (existingSnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('submissions')
            .doc(existingSnapshot.docs.first.id)
            .update(submissionData);

        return;
      }

      // ----------------------------------------------------------
      // Create new submission
      // ----------------------------------------------------------

      await _firestore.collection('submissions').add(submissionData);
    } on AssignmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to submit assignment.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to submit assignment.');
    }
  }

  // ============================================================
  // GET ASSIGNMENTS FOR INSTRUCTOR COURSE
  // ============================================================

  Future<List<Map<String, dynamic>>> getCourseAssignments(
    String courseId,
  ) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('assignments')
          .where('courseId', isEqualTo: courseId)
          .get();

      final assignments = snapshot.docs.map((document) {
        return {'id': document.id, ...document.data()};
      }).toList();

      assignments.sort((a, b) {
        final dueA = a['dueAt'];
        final dueB = b['dueAt'];

        if (dueA is Timestamp && dueB is Timestamp) {
          return dueA.toDate().compareTo(dueB.toDate());
        }

        return 0;
      });

      return assignments;
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load course assignments.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load course assignments.');
    }
  }

  // ============================================================
  // GET SUBMISSIONS FOR AN ASSIGNMENT
  // ============================================================

  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    try {
      if (assignmentId.trim().isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      return snapshot.docs.map((document) {
        return {'id': document.id, ...document.data()};
      }).toList();
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load submissions.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load submissions.');
    }
  }
  // ============================================================
  // GET CURRENT INSTRUCTOR PENDING SUBMISSIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstructorPendingSubmissions() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw AssignmentServiceException(
          'No instructor is currently logged in.',
        );
      }

      // ----------------------------------------------------------
      // 1. Get courses owned by this instructor
      // ----------------------------------------------------------

      final courseSnapshot = await _firestore
          .collection('courses')
          .where('instructorId', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> results = [];

      // ----------------------------------------------------------
      // 2. Process instructor courses
      // ----------------------------------------------------------

      for (final courseDocument in courseSnapshot.docs) {
        final course = courseDocument.data();

        final String courseStatus = (course['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        final String courseId = courseDocument.id;

        // --------------------------------------------------------
        // 3. Get assignments for course
        // --------------------------------------------------------

        final assignmentSnapshot = await _firestore
            .collection('assignments')
            .where('courseId', isEqualTo: courseId)
            .get();

        for (final assignmentDocument in assignmentSnapshot.docs) {
          final assignment = assignmentDocument.data();

          final String assignmentId = assignmentDocument.id;

          // ------------------------------------------------------
          // 4. Get submissions for assignment
          // ------------------------------------------------------

          final submissionSnapshot = await _firestore
              .collection('submissions')
              .where('assignmentId', isEqualTo: assignmentId)
              .get();

          for (final submissionDocument in submissionSnapshot.docs) {
            final submission = submissionDocument.data();

            final String status = (submission['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            // Only work waiting for grading
            if (status != 'submitted' &&
                status != 'under_review' &&
                status != 'late') {
              continue;
            }

            final String studentId = (submission['studentId'] ?? '').toString();

            String studentName = 'Student';

            String studentEmail = '';

            // ----------------------------------------------------
            // 5. Load student information
            // ----------------------------------------------------

            if (studentId.isNotEmpty) {
              final studentDocument = await _firestore
                  .collection('users')
                  .doc(studentId)
                  .get();

              final student = studentDocument.data();

              if (student != null) {
                studentName = (student['name'] ?? 'Student').toString();

                studentEmail = (student['email'] ?? '').toString();
              }
            }

            // ----------------------------------------------------
            // 6. Combine everything into one UI object
            // ----------------------------------------------------

            results.add({
              'id': submissionDocument.id,
              ...submission,

              'assignmentId': assignmentId,

              'assignmentTitle': (assignment['title'] ?? 'Assignment')
                  .toString(),

              'assignmentDescription': (assignment['description'] ?? '')
                  .toString(),

              'assignmentInstructions': (assignment['instructions'] ?? '')
                  .toString(),

              'assignmentPoints': assignment['points'],

              'assignmentDueAt': assignment['dueAt'],

              'courseId': courseId,

              'courseCode': (course['code'] ?? '').toString(),

              'courseTitle': (course['title'] ?? 'Course').toString(),

              'studentName': studentName,

              'studentEmail': studentEmail,
            });
          }
        }
      }

      // ----------------------------------------------------------
      // Most recently submitted first
      // ----------------------------------------------------------

      results.sort((a, b) {
        final submittedA = a['submittedAt'];

        final submittedB = b['submittedAt'];

        if (submittedA is Timestamp && submittedB is Timestamp) {
          return submittedB.toDate().compareTo(submittedA.toDate());
        }

        return 0;
      });

      return results;
    } on AssignmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load pending submissions.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load pending submissions.');
    }
  }

  // ============================================================
  // GET ONE SUBMISSION FOR GRADING
  // ============================================================

  Future<Map<String, dynamic>?> getSubmissionById(String submissionId) async {
    try {
      if (submissionId.trim().isEmpty) {
        return null;
      }

      final submissionDocument = await _firestore
          .collection('submissions')
          .doc(submissionId)
          .get();

      if (!submissionDocument.exists) {
        return null;
      }

      final submission = submissionDocument.data();

      if (submission == null) {
        return null;
      }

      final String assignmentId = (submission['assignmentId'] ?? '').toString();

      final String studentId = (submission['studentId'] ?? '').toString();

      final String courseId = (submission['courseId'] ?? '').toString();

      Map<String, dynamic> assignment = {};
      Map<String, dynamic> student = {};
      Map<String, dynamic> course = {};

      if (assignmentId.isNotEmpty) {
        final document = await _firestore
            .collection('assignments')
            .doc(assignmentId)
            .get();

        assignment = document.data() ?? {};
      }

      if (studentId.isNotEmpty) {
        final document = await _firestore
            .collection('users')
            .doc(studentId)
            .get();

        student = document.data() ?? {};
      }

      if (courseId.isNotEmpty) {
        final document = await _firestore
            .collection('courses')
            .doc(courseId)
            .get();

        course = document.data() ?? {};
      }

      return {
        'id': submissionDocument.id,
        ...submission,

        'assignmentTitle': (assignment['title'] ?? 'Assignment').toString(),

        'assignmentDescription': (assignment['description'] ?? '').toString(),

        'assignmentInstructions': (assignment['instructions'] ?? '').toString(),

        'assignmentPoints': assignment['points'],

        'studentName': (student['name'] ?? 'Student').toString(),

        'studentEmail': (student['email'] ?? '').toString(),

        'courseCode': (course['code'] ?? '').toString(),

        'courseTitle': (course['title'] ?? 'Course').toString(),
      };
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(
        e.message ?? 'Unable to load submission.',
      );
    } catch (_) {
      throw AssignmentServiceException('Unable to load submission.');
    }
  }

  // ============================================================
  // GRADE SUBMISSION
  // ============================================================

  Future<void> gradeSubmission({
    required String submissionId,
    required int score,
    required String feedback,
  }) async {
    try {
      final String cleanSubmissionId = submissionId.trim();

      if (cleanSubmissionId.isEmpty) {
        throw AssignmentServiceException('Submission ID is missing.');
      }

      final User? instructor = _auth.currentUser;

      if (instructor == null) {
        throw AssignmentServiceException(
          'You must be logged in to grade submissions.',
        );
      }

      final instructorProfile = await _firestore
          .collection('users')
          .doc(instructor.uid)
          .get();
      if (instructorProfile.data()?['role'] != 'instructor' ||
          instructorProfile.data()?['status'] != 'active') {
        throw AssignmentServiceException(
          'An active instructor account is required.',
        );
      }

      final submissionDocument = await _firestore
          .collection('submissions')
          .doc(cleanSubmissionId)
          .get();

      if (!submissionDocument.exists) {
        throw AssignmentServiceException('Submission could not be found.');
      }

      final submission = submissionDocument.data();

      if (submission == null) {
        throw AssignmentServiceException('Submission data is missing.');
      }

      final String assignmentId = (submission['assignmentId'] ?? '').toString();

      if (assignmentId.isEmpty) {
        throw AssignmentServiceException('Assignment information is missing.');
      }

      final assignmentDocument = await _firestore
          .collection('assignments')
          .doc(assignmentId)
          .get();

      final assignment = assignmentDocument.data();

      if (!assignmentDocument.exists || assignment == null) {
        throw AssignmentServiceException('Assignment could not be found.');
      }

      final String courseId = (assignment['courseId'] ?? '').toString().trim();

      if (courseId.isEmpty) {
        throw AssignmentServiceException(
          'Assignment course information is missing.',
        );
      }

      final courseDocument = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      final course = courseDocument.data();

      if (!courseDocument.exists || course == null) {
        throw AssignmentServiceException('Course could not be found.');
      }

      final String courseInstructorId = (course['instructorId'] ?? '')
          .toString()
          .trim();

      if (courseInstructorId != instructor.uid) {
        throw AssignmentServiceException(
          'You can only grade submissions from your own courses.',
        );
      }

      final String studentId = (submission['studentId'] ?? '')
          .toString()
          .trim();

      if (studentId.isEmpty) {
        throw AssignmentServiceException(
          'Submission student information is missing.',
        );
      }

      final int maximumPoints = assignment['points'] is num
          ? (assignment['points'] as num).toInt()
          : 0;

      if (score < 0) {
        throw AssignmentServiceException('Score cannot be negative.');
      }

      if (maximumPoints > 0 && score > maximumPoints) {
        throw AssignmentServiceException(
          'Score cannot be higher than $maximumPoints.',
        );
      }

      final DocumentReference<Map<String, dynamic>> submissionReference =
          _firestore.collection('submissions').doc(cleanSubmissionId);

      bool shouldCreateNotification = false;

      // Decide the first manual grading transition inside the same transaction
      // that saves the grade. A retry or double tap therefore cannot schedule a
      // second notification attempt.
      await _firestore.runTransaction((transaction) async {
        shouldCreateNotification = false;

        final DocumentSnapshot<Map<String, dynamic>> currentDocument =
            await transaction.get(submissionReference);

        if (!currentDocument.exists || currentDocument.data() == null) {
          throw AssignmentServiceException('Submission could not be found.');
        }

        final Map<String, dynamic> currentSubmission = currentDocument.data()!;

        final String currentAssignmentId =
            (currentSubmission['assignmentId'] ?? '').toString().trim();

        if (currentAssignmentId != assignmentId) {
          throw AssignmentServiceException(
            'Submission assignment information changed. Please try again.',
          );
        }

        final String previousStatus = (currentSubmission['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String previousGrader = (currentSubmission['gradedBy'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        shouldCreateNotification =
            previousStatus != 'graded' && !previousGrader.startsWith('system:');

        transaction.update(submissionReference, {
          'score': score,
          'feedback': feedback.trim(),
          'status': 'graded',
          'gradedBy': instructor.uid,
          'gradedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (shouldCreateNotification) {
        try {
          await _notificationService.createLegacyAssignmentGradeNotification(
            submissionId: cleanSubmissionId,
          );
        } catch (error, stackTrace) {
          // The grade is already committed. Keep grading successful even if the
          // optional notification cannot be written on this attempt.
          developer.log(
            'Assignment grade saved, but its notification could not be created.',
            name: 'AssignmentService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    } on AssignmentServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AssignmentServiceException(e.message ?? 'Unable to save grade.');
    } catch (_) {
      throw AssignmentServiceException('Unable to save grade.');
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class AssignmentServiceException implements Exception {
  final String message;

  AssignmentServiceException(this.message);

  @override
  String toString() => message;
}
