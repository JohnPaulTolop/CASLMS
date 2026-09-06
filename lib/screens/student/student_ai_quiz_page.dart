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
  State<StudentAiQuizScreen> createState() =>
      _StudentAiQuizScreenState();
}

class _StudentAiQuizScreenState extends State<StudentAiQuizScreen> {
  static const primaryBlue = Color(0xFF1769FF);
  static const background = Color(0xFFF7F9FC);
  static const textDark = Color(0xFF10182F);
  static const textGrey = Color(0xFF68738A);
  static const borderColor = Color(0xFFE6EAF0);
  static const green = Color(0xFF26A65B);
  static const red = Color(0xFFFF4B4B);

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  bool _confirming = false;

  String? _errorMessage;
  Map<String, dynamic>? _assessment;

  List<_QuizQuestion> _questions = [];
  final Map<int, int> _answers = {};
  int _currentQuestion = 0;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  String get _title => (_assessment?['title'] ?? 'Quiz').toString();

  String get _instructions =>
      (_assessment?['instructions'] ?? '').toString().trim();

  int get _totalPoints =>
      _questions.fold<int>(0, (sum, question) => sum + question.points);

  bool get _allAnswered =>
      _questions.isNotEmpty && _answers.length == _questions.length;

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _dateFrom(value)?.toLocal();
    if (date == null) return 'No due date';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} ${date.day}, ${date.year}'
        ' • $hour:$minute $period';
  }

  void _validateStudent(Map<String, dynamic>? profile) {
    if (profile == null) {
      throw Exception('Student profile could not be found.');
    }

    if (profile['role'] != 'student' || profile['status'] != 'active') {
      throw Exception('An active student account is required.');
    }
  }

  void _validateEnrollment(
    Map<String, dynamic>? enrollment,
    String studentId,
  ) {
    if (enrollment == null ||
        enrollment['status'] != 'active' ||
        enrollment['courseId'] != widget.courseId ||
        enrollment['studentId'] != studentId) {
      throw Exception('You do not have an active enrollment in this course.');
    }
  }

  void _validateAssessment(Map<String, dynamic>? assessment) {
    if (assessment == null) {
      throw Exception('Quiz could not be found.');
    }

    if (assessment['courseId'] != widget.courseId ||
        assessment['moduleId'] != widget.moduleId) {
      throw Exception('This quiz does not belong to the selected module.');
    }

    if (assessment['status'] != 'published') {
      throw Exception('This quiz is not currently published.');
    }

    if (assessment['assessmentType'] != 'quiz' ||
        assessment['deliveryType'] != 'ai_generated') {
      throw Exception('This assessment is not an in-app AI quiz.');
    }

    final dueAt = _dateFrom(assessment['dueAt']);
    if (dueAt != null && DateTime.now().isAfter(dueAt)) {
      throw Exception('The deadline for this quiz has already passed.');
    }
  }

  void _checkExistingSubmission(Map<String, dynamic>? submission) {
    final status = submission?['status'];
    if (status == 'submitted' || status == 'graded') {
      throw Exception('You have already submitted this quiz.');
    }
  }

  Future<void> _loadQuiz() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to take this quiz.');
      }

      final profile = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      _validateStudent(profile.data());

      final enrollment = await _firestore
          .collection('enrollments')
          .doc('${widget.courseId}_${user.uid}')
          .get();

      _validateEnrollment(enrollment.data(), user.uid);

      final submission = await _firestore
          .collection('assessmentSubmissions')
          .doc('${widget.assessmentId}_${user.uid}')
          .get();

      _checkExistingSubmission(submission.data());

      final assessmentDocument = await _firestore
          .collection('assessments')
          .doc(widget.assessmentId)
          .get();

      final assessment = assessmentDocument.data();
      _validateAssessment(assessment);

      final questions = _parseQuestions(assessment!['questions']);

      if (!mounted) return;

      setState(() {
        _assessment = assessment;
        _questions = questions;
        _answers.clear();
        _currentQuestion = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<_QuizQuestion> _parseQuestions(dynamic rawQuestions) {
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw Exception('This quiz does not contain any questions.');
    }

    final result = <_QuizQuestion>[];

    for (var index = 0; index < rawQuestions.length; index++) {
      final raw = rawQuestions[index];

      if (raw is! Map) {
        throw Exception('Question ${index + 1} has an invalid format.');
      }

      final data = Map<String, dynamic>.from(raw);
      final question = (data['question'] ?? '').toString().trim();
      final rawOptions = data['options'];

      if (question.isEmpty || rawOptions is! List || rawOptions.length != 4) {
        throw Exception('Question ${index + 1} is incomplete.');
      }

      final options = rawOptions
          .map((option) => option.toString().trim())
          .toList();

      final answerValue = data['correctAnswerIndex'];
      final pointsValue = data['points'];

      final correctIndex = answerValue is num ? answerValue.toInt() : -1;
      final points = pointsValue is num ? pointsValue.toInt() : 1;

      if (options.any((option) => option.isEmpty) ||
          correctIndex < 0 ||
          correctIndex >= options.length ||
          points <= 0) {
        throw Exception('Question ${index + 1} has invalid quiz data.');
      }

      result.add(
        _QuizQuestion(
          question: question,
          options: options,
          points: points,
          correctAnswerIndex: correctIndex,
          explanation: (data['explanation'] ?? '').toString().trim(),
        ),
      );
    }

    return result;
  }

  Future<T?> _showModal<T>(WidgetBuilder builder) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      barrierDismissible: false,
      builder: builder,
    );

    final result = await navigator.push<T>(route);
    await route.completed;
    return result;
  }

  Future<void> _leaveQuiz() async {
    if (_isSubmitting || _confirming) return;

    if (_answers.isEmpty || _hasSubmitted) {
      Navigator.of(context).pop();
      return;
    }

    _confirming = true;

    try {
      final leave = await _showModal<bool>((dialogContext) {
        return AlertDialog(
          title: const Text('Leave Quiz?'),
          content: const Text(
            'Your selected answers have not been submitted and will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Leave', style: TextStyle(color: red)),
            ),
          ],
        );
      });

      if (!mounted || leave != true) return;
      Navigator.of(context).pop();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _hasSubmitted || _confirming) return;

    if (!_allAnswered) {
      _showError(
        'Answer all questions first. '
        '${_questions.length - _answers.length} remaining.',
      );
      return;
    }

    _confirming = true;
    bool? confirmed;

    try {
      confirmed = await _showModal<bool>((dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.fact_check, color: primaryBlue),
          title: const Text('Submit Quiz?'),
          content: Text(
            'You answered all ${_questions.length} questions.\n\n'
            'CASLMS will automatically score the quiz. '
            'You cannot submit it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review Again'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit Quiz'),
            ),
          ],
        );
      });
    } finally {
      _confirming = false;
    }

    if (!mounted || confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to submit this quiz.');
      }

      final submissionId = '${widget.assessmentId}_${user.uid}';

      final profileReference = _firestore.collection('users').doc(user.uid);

      final enrollmentReference = _firestore
          .collection('enrollments')
          .doc('${widget.courseId}_${user.uid}');

      final assessmentReference = _firestore
          .collection('assessments')
          .doc(widget.assessmentId);

      final submissionReference = _firestore
          .collection('assessmentSubmissions')
          .doc(submissionId);

      final notificationReference = _firestore
          .collection('notifications')
          .doc('assessmentGrade_$submissionId');

      final result = await _firestore.runTransaction<_QuizResult>((
        transaction,
      ) async {
        // All reads happen before any writes.
        final profileDocument = await transaction.get(profileReference);
        final enrollmentDocument = await transaction.get(enrollmentReference);
        final assessmentDocument = await transaction.get(assessmentReference);
        final existingSubmission = await transaction.get(submissionReference);

        final profile = profileDocument.data();
        final assessment = assessmentDocument.data();

        _validateStudent(profile);
        _validateEnrollment(enrollmentDocument.data(), user.uid);
        _validateAssessment(assessment);
        _checkExistingSubmission(existingSubmission.data());

        final latestQuestions = _parseQuestions(assessment!['questions']);

        if (_answers.length != latestQuestions.length) {
          throw Exception(
            'The quiz has changed. Reopen it before submitting.',
          );
        }

        var score = 0;
        var totalPoints = 0;

        final storedAnswers = <Map<String, dynamic>>[];
        final items = <_QuizResultItem>[];

        for (var index = 0; index < latestQuestions.length; index++) {
          final question = latestQuestions[index];
          final selectedIndex = _answers[index];

          if (selectedIndex == null ||
              selectedIndex < 0 ||
              selectedIndex >= question.options.length) {
            throw Exception(
              'Question ${index + 1} does not have a valid answer.',
            );
          }

          final correct = selectedIndex == question.correctAnswerIndex;
          final earned = correct ? question.points : 0;

          score += earned;
          totalPoints += question.points;

          storedAnswers.add({
            'order': index + 1,
            'selectedAnswerIndex': selectedIndex,
            'selectedAnswerText': question.options[selectedIndex],
            'isCorrect': correct,
            'earnedPoints': earned,
            'possiblePoints': question.points,
          });

          items.add(
            _QuizResultItem(
              order: index + 1,
              question: question.question,
              selectedAnswer: question.options[selectedIndex],
              correctAnswer: question.options[question.correctAnswerIndex],
              correct: correct,
              earned: earned,
              possible: question.points,
              explanation: question.explanation,
            ),
          );
        }

        final percentage = totalPoints > 0
            ? score / totalPoints * 100
            : 0.0;

        final submissionData = <String, dynamic>{
          'assessmentId': widget.assessmentId,
          'courseId': widget.courseId,
          'moduleId': widget.moduleId,
          'studentId': user.uid,
          'studentName':
              (profile!['name'] ?? profile['universityId'] ?? 'Student')
                  .toString(),
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

        // Grade and notification are committed together.
        transaction.set(notificationReference, {
          'userId': user.uid,
          'type': 'grade',
          'sourceType': 'automaticAssessmentGrade',
          'sourceId': submissionId,
          'actorId': user.uid,
          'actorName': 'CASLMS',
          'title': 'Graded: ${assessment['title']}',
          'message':
              'Your score is $score / $totalPoints. '
              'Rating: ${percentage.toStringAsFixed(1)}%.',
          'courseId': widget.courseId,
          'moduleId': widget.moduleId,
          'isRead': false,
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return _QuizResult(
          score: score,
          totalPoints: totalPoints,
          percentage: percentage,
          items: items,
        );
      });

      if (!mounted) return;

      setState(() => _hasSubmitted = true);

      await _showResult(result);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showResult(_QuizResult result) async {
    await _showModal<void>((dialogContext) {
      return AlertDialog(
        title: const Text('Quiz Submitted'),
        icon: const Icon(
          Icons.verified_rounded,
          color: primaryBlue,
          size: 42,
        ),
        content: SizedBox(
          width: 560,
          height: 440,
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
              Text(
                '${result.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Automatically scored by CASLMS',
                style: TextStyle(color: textGrey, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: result.items.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = result.items[index];
                    final color = item.correct ? green : red;

                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item.correct
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Question ${item.order}'),
                              ),
                              Text('${item.earned}/${item.possible}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Your answer: ${item.selectedAnswer}',
                            style: TextStyle(color: color),
                          ),
                          if (!item.correct)
                            Text(
                              'Correct answer: ${item.correctAnswer}',
                              style: const TextStyle(color: green),
                            ),
                          if (item.explanation.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.explanation,
                              style: const TextStyle(
                                color: textGrey,
                                fontSize: 12,
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
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.done),
            label: const Text('Done'),
          ),
        ],
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goToQuestion(int index) {
    if (_isSubmitting ||
        _hasSubmitted ||
        index < 0 ||
        index >= _questions.length) {
      return;
    }
    setState(() => _currentQuestion = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_isSubmitting && (_answers.isEmpty || _hasSubmitted),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveQuiz();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: textDark,
          centerTitle: true,
          leading: IconButton(
            onPressed: _isSubmitting ? null : _leaveQuiz,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: const Text(
            'Take Quiz',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryBlue),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: red,
                        size: 52,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _loadQuiz,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            : _buildQuiz(),
      ),
    );
  }

  Widget _buildQuiz() {
    final question = _questions[_currentQuestion];
    final selected = _answers[_currentQuestion];

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_instructions.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _instructions,
                    style: const TextStyle(color: textGrey, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text('${_questions.length} questions'),
                    Text('$_totalPoints points'),
                    Text('Due ${_formatDate(_assessment?['dueAt'])}'),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _answers.length / _questions.length,
                  minHeight: 8,
                  color: primaryBlue,
                  backgroundColor: const Color(0xFFEAF0FF),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_answers.length} of ${_questions.length} answered',
                  style: const TextStyle(color: textGrey, fontSize: 11),
                ),
              ],
            ),
          ),
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_questions.length, (index) {
                            final current = index == _currentQuestion;
                            final answered = _answers.containsKey(index);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: _isSubmitting
                                    ? null
                                    : () => _goToQuestion(index),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: current
                                        ? primaryBlue
                                        : answered
                                        ? green.withValues(alpha: 0.1)
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
                                          : textDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
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
                                Text(
                                  'Question ${_currentQuestion + 1}',
                                  style: const TextStyle(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text('${question.points} points'),
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
                            ...List.generate(question.options.length, (index) {
                              final isSelected = selected == index;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isSubmitting || _hasSubmitted
                                      ? null
                                      : () {
                                          setState(() {
                                            _answers[_currentQuestion] = index;
                                          });
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
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: isSelected
                                              ? primaryBlue
                                              : const Color(0xFFF1F4F8),
                                          child: Text(
                                            String.fromCharCode(65 + index),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : textDark,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(question.options[index]),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
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
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !_isSubmitting && _currentQuestion > 0
                        ? () => _goToQuestion(_currentQuestion - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : _currentQuestion < _questions.length - 1
                        ? () => _goToQuestion(_currentQuestion + 1)
                        : _submitQuiz,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _currentQuestion < _questions.length - 1
                                ? Icons.chevron_right
                                : Icons.fact_check,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : _currentQuestion < _questions.length - 1
                          ? 'Next Question'
                          : 'Review & Submit',
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
}

class _QuizQuestion {
  const _QuizQuestion({
    required this.question,
    required this.options,
    required this.points,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int points;
  final int correctAnswerIndex;
  final String explanation;
}

class _QuizResult {
  const _QuizResult({
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.items,
  });

  final int score;
  final int totalPoints;
  final double percentage;
  final List<_QuizResultItem> items;
}

class _QuizResultItem {
  const _QuizResultItem({
    required this.order,
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.correct,
    required this.earned,
    required this.possible,
    required this.explanation,
  });

  final int order;
  final String question;
  final String selectedAnswer;
  final String correctAnswer;
  final bool correct;
  final int earned;
  final int possible;
  final String explanation;
}