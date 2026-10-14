import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
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
  bool _hasStarted = false;
  bool _isStarting = false;

  int _lastAnsweredQuestion = 0;
  Future<void> _draftWriteChain = Future<void>.value();
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
      _questions.fold<int>(0, (total, question) => total + question.points);

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

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} ${date.day}, ${date.year}'
        ' Ã¢â‚¬Â¢ $hour:$minute $period';
  }

  void _validateStudent(Map<String, dynamic>? profile) {
    if (profile == null) {
      throw Exception('Student profile could not be found.');
    }

    if (profile['role'] != 'student' || profile['status'] != 'active') {
      throw Exception('An active student account is required.');
    }
  }

  void _validateEnrollment(Map<String, dynamic>? enrollment, String studentId) {
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

    final version = assessment['quizVersion'];

    if (version is! String || version.trim().isEmpty) {
      throw Exception(
        'This quiz is not yet ready for secure grading. '
        'Please contact your instructor.',
      );
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

  // Verify that this quiz is assigned to the student's section.
  // Firestore rules and the backend independently enforce access.
  void _validateQuizSection({
    required Map<String, dynamic>? enrollment,
    required Map<String, dynamic>? assessment,
  }) {
    if (enrollment == null || assessment == null) {
      throw Exception('Quiz section information is unavailable.');
    }

    final String quizSectionId = (assessment['sectionId'] ?? '')
        .toString()
        .trim();

    final String studentSectionId = (enrollment['sectionId'] ?? '')
        .toString()
        .trim();

    if (quizSectionId.isEmpty) {
      throw Exception(
        'This quiz has no section assignment. '
        'Please contact your instructor.',
      );
    }

    if (studentSectionId.isEmpty || studentSectionId != quizSectionId) {
      throw Exception('This quiz is not available to your section.');
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

      final profile = await _firestore.collection('users').doc(user.uid).get();

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

      // Check section membership before loading the questions.
      _validateQuizSection(
        enrollment: enrollment.data(),
        assessment: assessment,
      );

      final questions = _parseQuestions(assessment!['questions']);

      final draftDocument = await _firestore
          .collection('aiQuizDrafts')
          .doc('${widget.assessmentId}_${user.uid}')
          .get();

      final draftData = draftDocument.data();
      final restoredAnswers = _parseDraftAnswers(
        draftData?['answers'],
        questions,
      );

      final lastAnsweredQuestion = _restoreLastAnsweredQuestion(
        draftData,
        restoredAnswers,
        questions.length,
      );

      if (!mounted) return;

      setState(() {
        _assessment = assessment;
        _questions = questions;
        _answers
          ..clear()
          ..addAll(restoredAnswers);
        _currentQuestion = lastAnsweredQuestion;
        _lastAnsweredQuestion = lastAnsweredQuestion;
        _hasStarted = draftDocument.exists;
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
    if (rawQuestions is! List ||
        rawQuestions.isEmpty ||
        rawQuestions.length > 100) {
      throw Exception('This quiz has an invalid question list.');
    }

    final result = <_QuizQuestion>[];

    const allowedFields = <String>{
      'order',
      'questionType',
      'question',
      'options',
      'points',
    };

    for (var index = 0; index < rawQuestions.length; index++) {
      final raw = rawQuestions[index];

      if (raw is! Map) {
        throw Exception('Question ${index + 1} has an invalid format.');
      }

      final data = Map<String, dynamic>.from(raw);

      if (data.keys.any((key) => !allowedFields.contains(key))) {
        throw Exception('This quiz has not been prepared for secure grading.');
      }

      final question = data['question'];
      final rawOptions = data['options'];
      final points = data['points'];

      if (data['order'] != index + 1 ||
          data['questionType'] != 'multiple_choice' ||
          question is! String ||
          question.trim().isEmpty ||
          rawOptions is! List ||
          rawOptions.length != 4 ||
          points is! int ||
          points < 1 ||
          points > 100) {
        throw Exception('Question ${index + 1} has invalid quiz data.');
      }

      final options = rawOptions
          .map((option) => option is String ? option.trim() : '')
          .toList();

      if (options.any((option) => option.isEmpty) ||
          options.toSet().length != options.length) {
        throw Exception('Question ${index + 1} has invalid choices.');
      }

      result.add(
        _QuizQuestion(
          question: question.trim(),
          options: options,
          points: points,
        ),
      );
    }

    return result;
  }

  Map<int, int> _parseDraftAnswers(
    dynamic rawAnswers,
    List<_QuizQuestion> questions,
  ) {
    final restored = <int, int>{};

    if (rawAnswers is! List) {
      return restored;
    }

    for (final rawAnswer in rawAnswers) {
      if (rawAnswer is! Map) continue;

      final data = Map<String, dynamic>.from(rawAnswer);
      final order = data['order'];
      final selected = data['selectedAnswerIndex'];

      if (order is! num || selected is! num) continue;

      final questionIndex = order.toInt() - 1;
      final selectedIndex = selected.toInt();

      if (questionIndex < 0 || questionIndex >= questions.length) continue;
      if (selectedIndex < 0 ||
          selectedIndex >= questions[questionIndex].options.length) {
        continue;
      }

      restored[questionIndex] = selectedIndex;
    }

    return restored;
  }

  int _restoreLastAnsweredQuestion(
    Map<String, dynamic>? draft,
    Map<int, int> restoredAnswers,
    int questionCount,
  ) {
    if (questionCount <= 0) return 0;

    final storedIndex = draft?['lastAnsweredQuestion'];

    if (storedIndex is num) {
      final index = storedIndex.toInt();
      if (index >= 0 && index < questionCount) {
        return index;
      }
    }

    if (restoredAnswers.isEmpty) return 0;

    return restoredAnswers.keys.reduce(
      (current, next) => current > next ? current : next,
    );
  }

  List<Map<String, dynamic>> _draftAnswersSnapshot() {
    final entries = _answers.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return entries
        .map(
          (entry) => <String, dynamic>{
            'order': entry.key + 1,
            'selectedAnswerIndex': entry.value,
          },
        )
        .toList();
  }

  Future<void> _startQuiz() async {
    if (_isStarting || _hasStarted || _assessment == null) return;

    setState(() => _isStarting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to take this quiz.');
      }

      await _firestore
          .collection('aiQuizDrafts')
          .doc('${widget.assessmentId}_${user.uid}')
          .set({
            'assessmentId': widget.assessmentId,
            'courseId': widget.courseId,
            'moduleId': widget.moduleId,
            'studentId': user.uid,
            'answers': _draftAnswersSnapshot(),
            'lastAnsweredQuestion': -1,
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() {
        _hasStarted = true;
        _currentQuestion = 0;
        _lastAnsweredQuestion = 0;
      });
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _selectAnswer(int selectedIndex) {
    if (_isSubmitting || _hasSubmitted || !_hasStarted) return;

    setState(() {
      _answers[_currentQuestion] = selectedIndex;
      _lastAnsweredQuestion = _currentQuestion;
    });

    _queueDraftSave();
  }

  void _queueDraftSave() {
    final user = _auth.currentUser;
    if (user == null || !_hasStarted || _hasSubmitted) return;

    final answers = _draftAnswersSnapshot();
    final lastAnsweredQuestion = _lastAnsweredQuestion;
    final reference = _firestore
        .collection('aiQuizDrafts')
        .doc('${widget.assessmentId}_${user.uid}');

    _draftWriteChain = _draftWriteChain
        .then<void>((_) async {
          await reference.set({
            'assessmentId': widget.assessmentId,
            'courseId': widget.courseId,
            'moduleId': widget.moduleId,
            'studentId': user.uid,
            'answers': answers,
            'lastAnsweredQuestion': lastAnsweredQuestion,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        })
        .catchError((Object error) {
          if (mounted && _hasStarted && !_hasSubmitted) {
            _showError(
              'Your answer is selected, but CASLMS could not save '
              'the latest progress. Check your connection.',
            );
          }
        });
  }

  void _returnToLastAnsweredQuestion() {
    if (!_hasStarted || _hasSubmitted || _isSubmitting || _isStarting) {
      return;
    }

    final target = _answers.isEmpty ? 0 : _lastAnsweredQuestion;

    setState(() {
      _currentQuestion = target.clamp(0, _questions.length - 1).toInt();
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'This quiz attempt is active. Submit the quiz to leave it.',
        ),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    await _draftWriteChain;

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to submit this quiz.');
      }

      final String? token = await user.getIdToken(true);

      if (token == null || token.isEmpty) {
        throw Exception('Unable to verify your student account.');
      }

      // Submit answer selections only. Never calculate or send a grade.
      final selectedAnswers = <int>[];

      for (var index = 0; index < _questions.length; index++) {
        final selected = _answers[index];

        if (selected == null ||
            selected < 0 ||
            selected >= _questions[index].options.length) {
          throw Exception(
            'Question ${index + 1} does not have a valid answer.',
          );
        }

        selectedAnswers.add(selected);
      }

      final response = await sb.Supabase.instance.client.functions.invoke(
        'assessment-submission',
        headers: <String, String>{'Authorization': 'Bearer $token'},
        body: <String, dynamic>{
          'action': 'submit_ai_quiz',
          'assessmentId': widget.assessmentId,
          'answers': selectedAnswers,
        },
      );

      final dynamic rawResponse = response.data;

      if (rawResponse is! Map) {
        throw Exception('The grading server returned an invalid response.');
      }

      final data = Map<String, dynamic>.from(rawResponse);

      if (data['success'] != true) {
        throw Exception(
          (data['error'] ?? 'Unable to submit this quiz.').toString(),
        );
      }

      if (data['score'] is! num ||
          data['totalPoints'] is! num ||
          data['percentage'] is! num ||
          data['items'] is! List) {
        throw Exception('The grading result is incomplete.');
      }

      final rawItems = data['items'] as List;

      if (rawItems.length != _questions.length) {
        throw Exception('The grading result has an unexpected question count.');
      }

      final items = <_QuizResultItem>[];

      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          throw Exception('Invalid grading feedback received.');
        }

        final item = Map<String, dynamic>.from(rawItem);

        if (item['order'] is! num ||
            item['correct'] is! bool ||
            item['earned'] is! num ||
            item['possible'] is! num) {
          throw Exception('Incomplete grading feedback received.');
        }

        items.add(
          _QuizResultItem(
            order: (item['order'] as num).toInt(),
            question: (item['question'] ?? '').toString(),
            selectedAnswer: (item['selectedAnswer'] ?? '').toString(),
            correctAnswer: (item['correctAnswer'] ?? '').toString(),
            correct: item['correct'] as bool,
            earned: (item['earned'] as num).toInt(),
            possible: (item['possible'] as num).toInt(),
            explanation: (item['explanation'] ?? '').toString(),
          ),
        );
      }

      final result = _QuizResult(
        score: (data['score'] as num).toInt(),
        totalPoints: (data['totalPoints'] as num).toInt(),
        percentage: (data['percentage'] as num).toDouble(),
        items: items,
      );
      if (!mounted) return;

      setState(() {
        _hasSubmitted = true;
      });

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
        icon: const Icon(Icons.verified_rounded, color: primaryBlue, size: 42),
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
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
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
                              Expanded(child: Text('Question ${item.order}')),
                              Text('${item.earned}/${item.possible}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.question,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
      canPop: !_hasStarted || _hasSubmitted,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _returnToLastAnsweredQuestion();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: textDark,
          centerTitle: true,
          leading: IconButton(
            onPressed: _isSubmitting || _isStarting
                ? null
                : _hasStarted
                ? _returnToLastAnsweredQuestion
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: Text(
            _hasStarted ? 'Take Quiz' : 'Quiz Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: red, size: 52),
                      const SizedBox(height: 14),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _loadQuiz,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            : _hasStarted
            ? _buildQuiz()
            : _buildOverview(),
      ),
    );
  }

  Widget _buildOverview() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.quiz_rounded,
                          color: primaryBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_instructions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _instructions,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: textGrey,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _overviewStat(
                            icon: Icons.help_outline_rounded,
                            value: '${_questions.length}',
                            label: 'Questions',
                          ),
                          _overviewStat(
                            icon: Icons.stars_rounded,
                            value: '$_totalPoints',
                            label: 'Total points',
                          ),
                          _overviewStat(
                            icon: Icons.event_outlined,
                            value: _formatDate(_assessment?['dueAt']),
                            label: 'Due date',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFD98A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            color: Color(0xFFB66A00),
                          ),
                          SizedBox(width: 9),
                          Text(
                            'Before you begin',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Ã¢â‚¬Â¢ Starting creates an active quiz attempt.\n'
                        'Ã¢â‚¬Â¢ Every answer is saved automatically.\n'
                        'Ã¢â‚¬Â¢ Back cannot close an active attempt.\n'
                        'Ã¢â‚¬Â¢ Reopening the quiz returns to your latest answered item.\n'
                        'Ã¢â‚¬Â¢ Submit only after reviewing all answers.',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 12.5,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isStarting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Not Yet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isStarting ? null : _startQuiz,
                        icon: _isStarting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(_isStarting ? 'Starting...' : 'Begin Quiz'),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overviewStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryBlue, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: textGrey, fontSize: 10.5),
              ),
            ],
          ),
        ],
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
                                      color: current ? Colors.white : textDark,
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
                                      : () => _selectAnswer(index),
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
  });

  final String question;
  final List<String> options;
  final int points;
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
