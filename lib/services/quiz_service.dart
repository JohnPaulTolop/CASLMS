import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizService {
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
  // GET ONE QUIZ
  // ============================================================

  Future<Map<String, dynamic>?> getQuizById(
    String quizId,
  ) async {
    try {
      if (quizId.trim().isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document =
          await _firestore
              .collection('quizzes')
              .doc(quizId)
              .get();

      if (!document.exists) {
        return null;
      }

      final Map<String, dynamic>? data =
          document.data();

      if (data == null) {
        return null;
      }

      return {
        ...data,
        'id': document.id,
      };
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to load quiz.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to load quiz.',
      );
    }
  }

  // ============================================================
  // GET PUBLISHED QUIZZES FOR COURSE
  // ============================================================

  Future<List<Map<String, dynamic>>> getCourseQuizzes(
    String courseId,
  ) async {
    try {
      if (courseId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('quizzes')
              .where(
                'courseId',
                isEqualTo: courseId,
              )
              .get();

      final List<Map<String, dynamic>> quizzes =
          snapshot.docs
              .map(
                (document) {
                  return {
                    ...document.data(),
                    'id': document.id,
                  };
                },
              )
              .where(
                (quiz) {
                  final String status =
                      (quiz['status'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                  return status == 'published';
                },
              )
              .toList();

      quizzes.sort(
        (a, b) {
          final dynamic createdA =
              a['createdAt'];

          final dynamic createdB =
              b['createdAt'];

          if (createdA is Timestamp &&
              createdB is Timestamp) {
            return createdA
                .toDate()
                .compareTo(
                  createdB.toDate(),
                );
          }

          return 0;
        },
      );

      return quizzes;
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to load course quizzes.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to load course quizzes.',
      );
    }
  }

  // ============================================================
  // GET QUIZ QUESTIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getQuizQuestions(
    String quizId,
  ) async {
    try {
      if (quizId.trim().isEmpty) {
        return [];
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('quizzes')
              .doc(quizId)
              .collection('questions')
              .get();

      final List<Map<String, dynamic>> questions =
          snapshot.docs.map(
        (document) {
          return {
            ...document.data(),
            'id': document.id,
          };
        },
      ).toList();

      questions.sort(
        (a, b) {
          final num orderA =
              a['order'] is num
                  ? a['order'] as num
                  : 0;

          final num orderB =
              b['order'] is num
                  ? b['order'] as num
                  : 0;

          return orderA.compareTo(
            orderB,
          );
        },
      );

      return questions;
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to load quiz questions.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to load quiz questions.',
      );
    }
  }

  // ============================================================
  // FIND CURRENT STUDENT QUIZ ATTEMPT
  // ============================================================

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _findMyAttemptDocument(
    String quizId,
  ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('quiz_attempts')
            .where(
              'studentId',
              isEqualTo: user.uid,
            )
            .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>>
        document in snapshot.docs) {
      final Map<String, dynamic> data =
          document.data();

      final String storedQuizId =
          (data['quizId'] ?? '')
              .toString();

      if (storedQuizId == quizId) {
        return document;
      }
    }

    return null;
  }

  // ============================================================
  // GET CURRENT STUDENT QUIZ ATTEMPT
  // ============================================================

  Future<Map<String, dynamic>?> getMyQuizAttempt(
    String quizId,
  ) async {
    try {
      final QueryDocumentSnapshot<Map<String, dynamic>>?
          document =
          await _findMyAttemptDocument(
        quizId,
      );

      if (document == null) {
        return null;
      }

      return {
        ...document.data(),
        'id': document.id,
      };
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to load quiz attempt.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to load quiz attempt.',
      );
    }
  }

  // ============================================================
  // START QUIZ ATTEMPT
  // ============================================================

  Future<String> startQuizAttempt({
    required String quizId,
    required String courseId,
    required int totalPoints,
  }) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw QuizServiceException(
          'You must be logged in to take the quiz.',
        );
      }

      if (quizId.trim().isEmpty) {
        throw QuizServiceException(
          'Quiz ID is missing.',
        );
      }

      if (courseId.trim().isEmpty) {
        throw QuizServiceException(
          'Course ID is missing.',
        );
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>?
          existing =
          await _findMyAttemptDocument(
        quizId,
      );

      // Do not create duplicate attempt.
      if (existing != null) {
        return existing.id;
      }

      final DocumentReference<Map<String, dynamic>> document =
          await _firestore
              .collection('quiz_attempts')
              .add({
        'quizId':
            quizId,
        'courseId':
            courseId,
        'studentId':
            user.uid,
        'score':
            0,
        'totalPoints':
            totalPoints,
        'status':
            'in_progress',
        'startedAt':
            FieldValue.serverTimestamp(),
        'submittedAt':
            null,
      });

      return document.id;
    } on QuizServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to start quiz.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to start quiz.',
      );
    }
  }

  // ============================================================
  // SUBMIT QUIZ ATTEMPT
  // ============================================================

  Future<void> submitQuizAttempt({
    required String quizId,
    required String courseId,
    required int score,
    required int totalPoints,
  }) async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw QuizServiceException(
          'You must be logged in to submit the quiz.',
        );
      }

      if (quizId.trim().isEmpty) {
        throw QuizServiceException(
          'Quiz ID is missing.',
        );
      }

      if (courseId.trim().isEmpty) {
        throw QuizServiceException(
          'Course ID is missing.',
        );
      }

      if (score < 0) {
        throw QuizServiceException(
          'Quiz score cannot be negative.',
        );
      }

      if (totalPoints < 0) {
        throw QuizServiceException(
          'Quiz total points cannot be negative.',
        );
      }

      if (score > totalPoints) {
        throw QuizServiceException(
          'Quiz score cannot exceed total points.',
        );
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>?
          existing =
          await _findMyAttemptDocument(
        quizId,
      );

      final Map<String, dynamic> data = {
        'quizId':
            quizId,
        'courseId':
            courseId,
        'studentId':
            user.uid,
        'score':
            score,
        'totalPoints':
            totalPoints,
        'status':
            'submitted',
        'submittedAt':
            FieldValue.serverTimestamp(),
      };

      // ----------------------------------------------------------
      // UPDATE EXISTING ATTEMPT
      // ----------------------------------------------------------

      if (existing != null) {
        await _firestore
            .collection('quiz_attempts')
            .doc(existing.id)
            .update(
              data,
            );

        return;
      }

      // ----------------------------------------------------------
      // FALLBACK CREATE
      // ----------------------------------------------------------

      await _firestore
          .collection('quiz_attempts')
          .add({
        ...data,
        'startedAt':
            FieldValue.serverTimestamp(),
      });
    } on QuizServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to submit quiz.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to submit quiz.',
      );
    }
  }

  // ============================================================
  // GET QUIZ RESULTS FOR CURRENT INSTRUCTOR
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getInstructorQuizResults() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        throw QuizServiceException(
          'No instructor is currently logged in.',
        );
      }

      final List<Map<String, dynamic>> results = [];

      // ----------------------------------------------------------
      // 1. GET COURSES OWNED BY CURRENT INSTRUCTOR
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>>
          courseSnapshot =
          await _firestore
              .collection('courses')
              .where(
                'instructorId',
                isEqualTo: user.uid,
              )
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>>
          courseDocument in courseSnapshot.docs) {
        final Map<String, dynamic> course =
            courseDocument.data();

        final String courseStatus =
            (course['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        final String courseId =
            courseDocument.id;

        // --------------------------------------------------------
        // 2. GET QUIZZES IN THIS COURSE
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>>
            quizSnapshot =
            await _firestore
                .collection('quizzes')
                .where(
                  'courseId',
                  isEqualTo: courseId,
                )
                .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>>
            quizDocument in quizSnapshot.docs) {
          final Map<String, dynamic> quiz =
              quizDocument.data();

          final String quizId =
              quizDocument.id;

          // ------------------------------------------------------
          // 3. GET QUIZ ATTEMPTS
          // ------------------------------------------------------

          final QuerySnapshot<Map<String, dynamic>>
              attemptSnapshot =
              await _firestore
                  .collection('quiz_attempts')
                  .where(
                    'quizId',
                    isEqualTo: quizId,
                  )
                  .get();

          for (final QueryDocumentSnapshot<Map<String, dynamic>>
              attemptDocument in attemptSnapshot.docs) {
            final Map<String, dynamic> attempt =
                attemptDocument.data();

            final String attemptStatus =
                (attempt['status'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

            if (attemptStatus != 'submitted') {
              continue;
            }

            final String studentId =
                (attempt['studentId'] ?? '')
                    .toString()
                    .trim();

            String studentName =
                'Student';

            String studentEmail =
                '';

            // ----------------------------------------------------
            // 4. LOAD STUDENT INFORMATION
            // ----------------------------------------------------

            if (studentId.isNotEmpty) {
              final DocumentSnapshot<Map<String, dynamic>>
                  studentDocument =
                  await _firestore
                      .collection('users')
                      .doc(studentId)
                      .get();

              final Map<String, dynamic>? student =
                  studentDocument.data();

              if (student != null) {
                studentName =
                    (student['name'] ??
                            'Student')
                        .toString();

                studentEmail =
                    (student['email'] ?? '')
                        .toString();
              }
            }

            final int score =
                attempt['score'] is num
                    ? (attempt['score'] as num)
                        .toInt()
                    : 0;

            final int totalPoints =
                attempt['totalPoints'] is num
                    ? (attempt['totalPoints']
                            as num)
                        .toInt()
                    : quiz['totalPoints'] is num
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

            final bool passed =
                score >= passingScore;

            // ----------------------------------------------------
            // 5. BUILD RESULT OBJECT
            // ----------------------------------------------------

            results.add({
              ...attempt,

              'id':
                  attemptDocument.id,

              'quizId':
                  quizId,

              'quizTitle':
                  (quiz['title'] ??
                          'Quiz')
                      .toString(),

              'quizDescription':
                  (quiz['description'] ?? '')
                      .toString(),

              'passingScore':
                  passingScore,

              'score':
                  score,

              'totalPoints':
                  totalPoints,

              'passed':
                  passed,

              'courseId':
                  courseId,

              'courseCode':
                  (course['code'] ?? '')
                      .toString(),

              'courseTitle':
                  (course['title'] ??
                          'Course')
                      .toString(),

              'studentId':
                  studentId,

              'studentName':
                  studentName,

              'studentEmail':
                  studentEmail,
            });
          }
        }
      }

      // ----------------------------------------------------------
      // MOST RECENT RESULTS FIRST
      // ----------------------------------------------------------

      results.sort(
        (a, b) {
          final dynamic submittedA =
              a['submittedAt'];

          final dynamic submittedB =
              b['submittedAt'];

          if (submittedA is Timestamp &&
              submittedB is Timestamp) {
            return submittedB
                .toDate()
                .compareTo(
                  submittedA.toDate(),
                );
          }

          if (submittedA is Timestamp) {
            return -1;
          }

          if (submittedB is Timestamp) {
            return 1;
          }

          return 0;
        },
      );

      return results;
    } on QuizServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw QuizServiceException(
        e.message ??
            'Unable to load quiz results.',
      );
    } catch (_) {
      throw QuizServiceException(
        'Unable to load quiz results.',
      );
    }
  }
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class QuizServiceException implements Exception {
  final String message;

  QuizServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}