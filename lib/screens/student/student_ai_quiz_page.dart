import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentAiQuizScreen extends StatefulWidget {
  const StudentAiQuizScreen({
    super.key,
    required this.assessmentId,
    required this.courseId,
    required this.moduleId,
  });

  final String assessmentId;
  final String courseId;
  final String moduleId;

  @override
  State<StudentAiQuizScreen> createState() => _StudentAiQuizScreenState();
}

class _StudentAiQuizScreenState extends State<StudentAiQuizScreen> {
  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);
  static const Color purple = Color(0xFF7B4DFF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  String? _errorMessage;

  Map<String, dynamic>? _assessment;

  List<_StudentQuizQuestion> _questions = [];

  // question index -> selected option index
  final Map<int, int> _answers = {};

  int _currentQuestion = 0;

  @override
  void initState() {
    super.initState();

    _loadQuiz();
  }

  // ============================================================
  // LOAD / SECURITY CHECKS
  // ============================================================

  Future<void> _loadQuiz() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to take this quiz.');
      }

      // ----------------------------------------------------------
      // VERIFY ACTIVE STUDENT
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> profileDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDocument.exists || profileDocument.data() == null) {
        throw Exception('Student profile could not be found.');
      }

      final Map<String, dynamic> profile = profileDocument.data()!;

      final String role = (profile['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String accountStatus = (profile['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'student') {
        throw Exception('Only students can take this quiz.');
      }

      if (accountStatus != 'active') {
        throw Exception('This student account is not active.');
      }

      // ----------------------------------------------------------
      // VERIFY ACTIVE ENROLLMENT
      // ----------------------------------------------------------

      final String enrollmentId = '${widget.courseId}_${user.uid}';

      final DocumentSnapshot<Map<String, dynamic>> enrollmentDocument =
          await _firestore.collection('enrollments').doc(enrollmentId).get();

      if (!enrollmentDocument.exists || enrollmentDocument.data() == null) {
        throw Exception('You are not enrolled in this course.');
      }

      final String enrollmentStatus =
          (enrollmentDocument.data()!['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (enrollmentStatus != 'active') {
        throw Exception('Your enrollment is not active.');
      }

      // ----------------------------------------------------------
      // CHECK EXISTING SUBMISSION
      // ----------------------------------------------------------

      final String submissionId = '${widget.assessmentId}_${user.uid}';

      final DocumentSnapshot<Map<String, dynamic>> submissionDocument =
          await _firestore
              .collection('assessmentSubmissions')
              .doc(submissionId)
              .get();

      if (submissionDocument.exists && submissionDocument.data() != null) {
        final String submissionStatus =
            (submissionDocument.data()!['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (submissionStatus == 'submitted' || submissionStatus == 'graded') {
          throw Exception('You have already submitted this quiz.');
        }
      }

      // ----------------------------------------------------------
      // LOAD PUBLISHED AI QUIZ
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!assessmentDocument.exists || assessmentDocument.data() == null) {
        throw Exception('Quiz could not be found.');
      }

      final Map<String, dynamic> data = assessmentDocument.data()!;

      final String courseId = (data['courseId'] ?? '').toString().trim();

      final String moduleId = (data['moduleId'] ?? '').toString().trim();

      final String status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String assessmentType = (data['assessmentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String deliveryType = (data['deliveryType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (courseId != widget.courseId || moduleId != widget.moduleId) {
        throw Exception('This quiz does not belong to the selected module.');
      }

      if (status != 'published') {
        throw Exception('This quiz is not currently published.');
      }

      if (assessmentType != 'quiz' || deliveryType != 'ai_generated') {
        throw Exception('This assessment is not an in-app AI quiz.');
      }

      // ----------------------------------------------------------
      // DUE DATE
      // ----------------------------------------------------------

      final DateTime? dueAt = _dateFrom(data['dueAt']);

      if (dueAt != null && DateTime.now().isAfter(dueAt)) {
        throw Exception('The deadline for this quiz has already passed.');
      }

      // ----------------------------------------------------------
      // QUESTIONS
      //
      // correctAnswerIndex is loaded only for scoring.
      // It is never rendered before submission.
      // ----------------------------------------------------------

      final List<_StudentQuizQuestion> questions = _parseQuestionsForStudent(
        data['questions'],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _assessment = {...data, 'assessmentId': assessmentDocument.id};

        _questions = questions;

        _isLoading = false;

        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // PARSE QUESTIONS
  // ============================================================

  List<_StudentQuizQuestion> _parseQuestionsForStudent(dynamic rawQuestions) {
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw Exception('This quiz does not contain any questions.');
    }

    final List<_StudentQuizQuestion> questions = [];

    for (int index = 0; index < rawQuestions.length; index++) {
      final dynamic raw = rawQuestions[index];

      if (raw is! Map) {
        throw Exception('Question ${index + 1} has an invalid format.');
      }

      final Map<String, dynamic> questionData = Map<String, dynamic>.from(raw);

      final String question = (questionData['question'] ?? '')
          .toString()
          .trim();

      final dynamic rawOptions = questionData['options'];

      final int points = (questionData['points'] as num?)?.toInt() ?? 1;

      final int? correctAnswerIndex =
          (questionData['correctAnswerIndex'] as num?)?.toInt();

      final String explanation = (questionData['explanation'] ?? '')
          .toString()
          .trim();

      if (question.isEmpty || rawOptions is! List || rawOptions.length != 4) {
        throw Exception('Question ${index + 1} is incomplete.');
      }

      final List<String> options = rawOptions
          .map((dynamic option) => option.toString().trim())
          .toList();

      if (options.any((String option) => option.isEmpty)) {
        throw Exception(
          'Question ${index + 1} contains an empty answer choice.',
        );
      }

      if (correctAnswerIndex == null ||
          correctAnswerIndex < 0 ||
          correctAnswerIndex >= options.length) {
        throw Exception('Question ${index + 1} has an invalid answer key.');
      }

      if (points <= 0) {
        throw Exception('Question ${index + 1} has invalid points.');
      }

      questions.add(
        _StudentQuizQuestion(
          question: question,
          options: options,
          points: points,
          correctAnswerIndex: correctAnswerIndex,
          explanation: explanation,
        ),
      );
    }

    return questions;
  }

  // ============================================================
  // VALUES
  // ============================================================

  String get _title => (_assessment?['title'] ?? 'Quiz').toString();

  String get _instructions =>
      (_assessment?['instructions'] ?? '').toString().trim();

  int get _totalPoints => _questions.fold<int>(
    0,
    (int sum, _StudentQuizQuestion question) => sum + question.points,
  );

  int get _answeredCount => _answers.length;

  bool get _allAnswered =>
      _questions.isNotEmpty && _answers.length == _questions.length;

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final DateTime? date = _dateFrom(value);

    if (date == null) {
      return 'No due date';
    }

    final DateTime local = date.toLocal();

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    int hour = local.hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return '${months[local.month - 1]} '
        '${local.day}, ${local.year} • '
        '$hour:${local.minute.toString().padLeft(2, '0')} '
        '$period';
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _goToQuestion(int index) {
    if (_isSubmitting ||
        _hasSubmitted ||
        index < 0 ||
        index >= _questions.length) {
      return;
    }

    setState(() {
      _currentQuestion = index;
    });
  }

  void _selectAnswer(int optionIndex) {
    if (_isSubmitting || _hasSubmitted) {
      return;
    }

    setState(() {
      _answers[_currentQuestion] = optionIndex;
    });
  }

  // ============================================================
  // PHASE 13C-6 — SUBMIT + AUTO-SCORE
  // ============================================================

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _hasSubmitted) {
      return;
    }

    if (!_allAnswered) {
      final int remaining = _questions.length - _answeredCount;

      _showError(
        'Answer all questions first. '
        '$remaining remaining.',
      );

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.fact_check_rounded,
            color: primaryBlue,
            size: 34,
          ),
          title: const Text('Submit Quiz?'),
          content: Text(
            'You answered all ${_questions.length} questions.\n\n'
            'After submission, CASLMS will automatically score the quiz. '
            'You cannot submit this quiz again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Review Again'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Quiz'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to submit this quiz.');
      }

      final String submissionId = '${widget.assessmentId}_${user.uid}';

      final DocumentReference<Map<String, dynamic>> profileReference =
          _firestore.collection('users').doc(user.uid);

      final DocumentReference<Map<String, dynamic>> enrollmentReference =
          _firestore
              .collection('enrollments')
              .doc('${widget.courseId}_${user.uid}');

      final DocumentReference<Map<String, dynamic>> assessmentReference =
          _firestore.collection('assessments').doc(widget.assessmentId);

      final DocumentReference<Map<String, dynamic>> submissionReference =
          _firestore.collection('assessmentSubmissions').doc(submissionId);

      final _AiQuizSubmissionResult
      result = await _firestore.runTransaction<_AiQuizSubmissionResult>((
        Transaction transaction,
      ) async {
        // ----------------------------------------------------
        // RE-READ EVERYTHING AT SUBMISSION TIME
        // ----------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>> profileDocument =
            await transaction.get(profileReference);

        final DocumentSnapshot<Map<String, dynamic>> enrollmentDocument =
            await transaction.get(enrollmentReference);

        final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
            await transaction.get(assessmentReference);

        final DocumentSnapshot<Map<String, dynamic>> existingSubmission =
            await transaction.get(submissionReference);

        // ----------------------------------------------------
        // STUDENT
        // ----------------------------------------------------

        if (!profileDocument.exists || profileDocument.data() == null) {
          throw Exception('Student profile could not be found.');
        }

        final Map<String, dynamic> profile = profileDocument.data()!;

        final String role = (profile['role'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String accountStatus = (profile['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        if (role != 'student' || accountStatus != 'active') {
          throw Exception(
            'Your student account is not allowed to submit this quiz.',
          );
        }

        // ----------------------------------------------------
        // ENROLLMENT
        // ----------------------------------------------------

        if (!enrollmentDocument.exists || enrollmentDocument.data() == null) {
          throw Exception('You are not enrolled in this course.');
        }

        final String enrollmentStatus =
            (enrollmentDocument.data()!['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (enrollmentStatus != 'active') {
          throw Exception('Your enrollment is not active.');
        }

        // ----------------------------------------------------
        // PREVENT DOUBLE SUBMISSION
        // ----------------------------------------------------

        if (existingSubmission.exists && existingSubmission.data() != null) {
          final String existingStatus =
              (existingSubmission.data()!['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          if (existingStatus == 'submitted' || existingStatus == 'graded') {
            throw Exception('This quiz has already been submitted.');
          }
        }

        // ----------------------------------------------------
        // ASSESSMENT
        // ----------------------------------------------------

        if (!assessmentDocument.exists || assessmentDocument.data() == null) {
          throw Exception('Quiz could not be found.');
        }

        final Map<String, dynamic> assessment = assessmentDocument.data()!;

        final String courseId = (assessment['courseId'] ?? '')
            .toString()
            .trim();

        final String moduleId = (assessment['moduleId'] ?? '')
            .toString()
            .trim();

        final String status = (assessment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String assessmentType = (assessment['assessmentType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String deliveryType = (assessment['deliveryType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (courseId != widget.courseId || moduleId != widget.moduleId) {
          throw Exception('This quiz does not belong to the selected module.');
        }

        if (status != 'published') {
          throw Exception('This quiz is no longer published.');
        }

        if (assessmentType != 'quiz' || deliveryType != 'ai_generated') {
          throw Exception('This assessment is not an AI-generated quiz.');
        }

        final DateTime? dueAt = _dateFrom(assessment['dueAt']);

        if (dueAt != null && DateTime.now().isAfter(dueAt)) {
          throw Exception('The deadline for this quiz has already passed.');
        }

        // ----------------------------------------------------
        // USE THE LATEST FIRESTORE QUESTIONS FOR SCORING
        // ----------------------------------------------------

        final List<_StudentQuizQuestion> latestQuestions =
            _parseQuestionsForStudent(assessment['questions']);

        if (_answers.length != latestQuestions.length) {
          throw Exception(
            'Your answers do not match the current quiz. '
            'Please reopen the quiz and try again.',
          );
        }

        int score = 0;
        int totalPoints = 0;

        final List<Map<String, dynamic>> storedAnswers = [];

        final List<_AiQuizQuestionResult> questionResults = [];

        for (int index = 0; index < latestQuestions.length; index++) {
          final _StudentQuizQuestion question = latestQuestions[index];

          final int? selectedIndex = _answers[index];

          if (selectedIndex == null ||
              selectedIndex < 0 ||
              selectedIndex >= question.options.length) {
            throw Exception(
              'Question ${index + 1} does not have a valid answer.',
            );
          }

          final bool isCorrect = selectedIndex == question.correctAnswerIndex;

          final int earnedPoints = isCorrect ? question.points : 0;

          score += earnedPoints;

          totalPoints += question.points;

          storedAnswers.add({
            'order': index + 1,
            'selectedAnswerIndex': selectedIndex,
            'selectedAnswerText': question.options[selectedIndex],
            'isCorrect': isCorrect,
            'earnedPoints': earnedPoints,
            'possiblePoints': question.points,
          });

          questionResults.add(
            _AiQuizQuestionResult(
              order: index + 1,
              question: question.question,
              selectedAnswer: question.options[selectedIndex],
              correctAnswer: question.options[question.correctAnswerIndex],
              isCorrect: isCorrect,
              earnedPoints: earnedPoints,
              possiblePoints: question.points,
              explanation: question.explanation,
            ),
          );
        }

        final double percentage = totalPoints > 0
            ? (score / totalPoints) * 100
            : 0;

        final String studentName =
            (profile['name'] ?? profile['universityId'] ?? 'Student')
                .toString();

        final Map<String, dynamic> submissionData = {
          'assessmentId': widget.assessmentId,
          'courseId': widget.courseId,
          'moduleId': widget.moduleId,
          'studentId': user.uid,
          'studentName': studentName,

          // Auto-scored quizzes are immediately graded.
          'status': 'graded',

          'submissionType': 'ai_quiz',
          'gradingMode': 'automatic',

          'answers': storedAnswers,

          'score': score,
          'totalPoints': totalPoints,
          'percentage': percentage,

          'feedback': 'Automatically scored by CASLMS.',

          'submittedAt': FieldValue.serverTimestamp(),
          'gradedAt': FieldValue.serverTimestamp(),
          'gradedBy': 'system:auto-score',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!existingSubmission.exists) {
          submissionData['createdAt'] = FieldValue.serverTimestamp();
        }

        transaction.set(
          submissionReference,
          submissionData,
          SetOptions(merge: true),
        );

        return _AiQuizSubmissionResult(
          score: score,
          totalPoints: totalPoints,
          percentage: percentage,
          questionResults: questionResults,
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _hasSubmitted = true;
      });

      await _showResult(result);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // RESULT
  // ============================================================

  Future<void> _showResult(_AiQuizSubmissionResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: primaryBlue,
              size: 34,
            ),
          ),
          title: const Text('Quiz Submitted'),
          content: SizedBox(
            width: 560,
            height: 500,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${result.score} / ${result.totalPoints}',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatically scored by CASLMS',
                        style: TextStyle(color: textGrey, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: result.questionResults.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final _AiQuizQuestionResult item =
                          result.questionResults[index];

                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: item.isCorrect
                              ? green.withValues(alpha: 0.06)
                              : red.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: item.isCorrect
                                ? green.withValues(alpha: 0.25)
                                : red.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  item.isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: item.isCorrect ? green : red,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Question ${item.order}',
                                    style: const TextStyle(
                                      color: textDark,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.earnedPoints}/${item.possiblePoints}',
                                  style: TextStyle(
                                    color: item.isCorrect ? green : red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              item.question,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Your answer: ${item.selectedAnswer}',
                              style: TextStyle(
                                color: item.isCorrect ? green : red,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!item.isCorrect) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Correct answer: ${item.correctAnswer}',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (item.explanation.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.explanation,
                                style: const TextStyle(
                                  color: textGrey,
                                  fontSize: 10,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.done_rounded),
              label: const Text('Done'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _answers.isEmpty || _hasSubmitted,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop || _answers.isEmpty || _hasSubmitted) {
          return;
        }

        final bool? leave = await _confirmLeave();

        if (!mounted || leave != true) {
          return;
        }

        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textDark,
              size: 20,
            ),
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_answers.isEmpty || _hasSubmitted) {
                      Navigator.pop(context);

                      return;
                    }

                    final bool? leave = await _confirmLeave();

                    if (!mounted || leave != true) {
                      return;
                    }

                    Navigator.pop(context);
                  },
          ),
          title: const Text(
            'Take Quiz',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : _errorMessage != null
            ? _buildError()
            : _buildQuiz(),
      ),
    );
  }

  Future<bool?> _confirmLeave() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Leave Quiz?'),
          content: const Text(
            'Your selected answers have not been submitted and will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Leave', style: TextStyle(color: red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 52),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Unable to load quiz.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final _StudentQuizQuestion question = _questions[_currentQuestion];

    final int? selected = _answers[_currentQuestion];

    final double progress = _questions.isEmpty
        ? 0
        : _answeredCount / _questions.length;

    return SafeArea(
      child: Column(
        children: [
          // ------------------------------------------------------
          // HEADER / QUIZ INFO
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_instructions.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _instructions,
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _infoChip(
                      Icons.quiz_outlined,
                      '${_questions.length} questions',
                    ),
                    _infoChip(Icons.stars_outlined, '$_totalPoints points'),
                    _infoChip(
                      Icons.schedule_rounded,
                      'Due ${_formatDate(_assessment?['dueAt'])}',
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEAF0FF),
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$_answeredCount of ${_questions.length} answered',
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // QUESTION BODY
          // ------------------------------------------------------
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuestionNavigator(),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    'Question ${_currentQuestion + 1}',
                                    style: const TextStyle(
                                      color: primaryBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${question.points} ${question.points == 1 ? 'point' : 'points'}',
                                  style: const TextStyle(
                                    color: textGrey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              question.question,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ...List.generate(question.options.length, (
                              int optionIndex,
                            ) {
                              final bool isSelected = selected == optionIndex;

                              final String letter = String.fromCharCode(
                                65 + optionIndex,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isSubmitting
                                      ? null
                                      : () {
                                          _selectAnswer(optionIndex);
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryBlue.withValues(alpha: 0.07)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? primaryBlue
                                            : borderColor,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? primaryBlue
                                                : const Color(0xFFF1F4F8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : textDark,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            question.options[optionIndex],
                                            style: const TextStyle(
                                              color: textDark,
                                              fontSize: 13,
                                              height: 1.4,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                          color: isSelected
                                              ? primaryBlue
                                              : textGrey,
                                          size: 21,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ------------------------------------------------------
          // BOTTOM NAVIGATION
          // ------------------------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !_isSubmitting && _currentQuestion > 0
                        ? () {
                            _goToQuestion(_currentQuestion - 1);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _currentQuestion < _questions.length - 1
                      ? FilledButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  _goToQuestion(_currentQuestion + 1);
                                },
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('Next Question'),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submitQuiz,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.fact_check_rounded),
                          label: Text(
                            _isSubmitting ? 'Submitting...' : 'Review & Submit',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigator() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_questions.length, (int index) {
          final bool current = index == _currentQuestion;

          final bool answered = _answers.containsKey(index);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _isSubmitting
                  ? null
                  : () {
                      _goToQuestion(index);
                    },
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current
                      ? primaryBlue
                      : answered
                      ? green.withValues(alpha: 0.11)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: current
                        ? primaryBlue
                        : answered
                        ? green
                        : borderColor,
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: current
                        ? Colors.white
                        : answered
                        ? green
                        : textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: textGrey, size: 15),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: textGrey,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// QUIZ QUESTION
// ============================================================

class _StudentQuizQuestion {
  const _StudentQuizQuestion({
    required this.question,
    required this.options,
    required this.points,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int points;

  // Never displayed before submission.
  final int correctAnswerIndex;

  final String explanation;
}

// ============================================================
// SUBMISSION RESULT
// ============================================================

class _AiQuizSubmissionResult {
  const _AiQuizSubmissionResult({
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.questionResults,
  });

  final int score;
  final int totalPoints;
  final double percentage;

  final List<_AiQuizQuestionResult> questionResults;
}

class _AiQuizQuestionResult {
  const _AiQuizQuestionResult({
    required this.order,
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.earnedPoints,
    required this.possiblePoints,
    required this.explanation,
  });

  final int order;
  final String question;

  final String selectedAnswer;
  final String correctAnswer;

  final bool isCorrect;

  final int earnedPoints;
  final int possiblePoints;

  final String explanation;
}
