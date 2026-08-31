import 'package:flutter/material.dart';

import '../../services/quiz_service.dart';

class GeneralQuizScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const GeneralQuizScreen({
    super.key,
    this.quizId = '',
    this.quizTitle = 'Quiz',
  });

  @override
  State<GeneralQuizScreen> createState() =>
      _GeneralQuizScreenState();
}

class _GeneralQuizScreenState
    extends State<GeneralQuizScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color green =
      Color(0xFF26A65B);

  // ============================================================
  // SERVICE
  // ============================================================

  final QuizService _quizService =
      QuizService();

  // ============================================================
  // FIRESTORE DATA
  // ============================================================

  Map<String, dynamic>? _quiz;

  List<Map<String, dynamic>> _questions = [];

  Map<String, dynamic>? _previousAttempt;

  // ============================================================
  // STUDENT ANSWERS
  // ============================================================

  int _currentQuestionIndex = 0;

  final Map<int, int> _selectedAnswers = {};

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  bool _isSubmitting = false;

  String? _errorMessage;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadQuiz();
  }

  // ============================================================
  // LOAD QUIZ
  // ============================================================

  Future<void> _loadQuiz() async {
    if (widget.quizId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Quiz information is missing.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic>? quiz =
          await _quizService.getQuizById(
        widget.quizId,
      );

      if (quiz == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Quiz could not be found.';
        });

        return;
      }

      final String quizStatus =
          (quiz['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (quizStatus != 'published') {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'This quiz is not currently available.';
        });

        return;
      }

      final List<Map<String, dynamic>> questions =
          await _quizService.getQuizQuestions(
        widget.quizId,
      );

      final Map<String, dynamic>? previousAttempt =
          await _quizService.getMyQuizAttempt(
        widget.quizId,
      );

      if (previousAttempt == null) {
        await _quizService.startQuizAttempt(
          quizId:
              widget.quizId,
          courseId:
              (quiz['courseId'] ?? '')
                  .toString(),
          totalPoints:
              _getQuizTotalPoints(
            quiz,
            questions,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _quiz =
            quiz;

        _questions =
            questions;

        _previousAttempt =
            previousAttempt;

        _currentQuestionIndex =
            0;

        _selectedAnswers.clear();

        _isLoading =
            false;

        _errorMessage =
            null;
      });
    } on QuizServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load quiz.';
      });
    }
  }

  // ============================================================
  // SELECT ANSWER
  // ============================================================

  void _selectAnswer(
    int optionIndex,
  ) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _selectedAnswers[
              _currentQuestionIndex] =
          optionIndex;
    });
  }

  // ============================================================
  // NEXT QUESTION
  // ============================================================

  void _nextQuestion() {
    if (!_selectedAnswers.containsKey(
      _currentQuestionIndex,
    )) {
      return;
    }

    if (_currentQuestionIndex <
        _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });

      return;
    }

    _finishQuiz();
  }

  // ============================================================
  // PREVIOUS QUESTION
  // ============================================================

  void _previousQuestion() {
    if (_currentQuestionIndex <= 0 ||
        _isSubmitting) {
      return;
    }

    setState(() {
      _currentQuestionIndex--;
    });
  }

  // ============================================================
  // CALCULATE SCORE
  // ============================================================

  int _calculateScore() {
    int score = 0;

    for (int questionIndex = 0;
        questionIndex < _questions.length;
        questionIndex++) {
      final Map<String, dynamic> question =
          _questions[questionIndex];

      final dynamic optionsData =
          question['options'];

      if (optionsData is! List) {
        continue;
      }

      final List<String> options =
          optionsData
              .map(
                (option) =>
                    option.toString(),
              )
              .toList();

      final int? selectedIndex =
          _selectedAnswers[
              questionIndex];

      if (selectedIndex == null ||
          selectedIndex < 0 ||
          selectedIndex >= options.length) {
        continue;
      }

      final String selectedAnswer =
          options[selectedIndex]
              .trim();

      final String correctAnswer =
          (question['correctAnswer'] ?? '')
              .toString()
              .trim();

      final int points =
          question['points'] is num
              ? (question['points'] as num)
                  .toInt()
              : 0;

      if (selectedAnswer ==
          correctAnswer) {
        score += points;
      }
    }

    return score;
  }

  // ============================================================
  // FINISH QUIZ
  // ============================================================

  Future<void> _finishQuiz() async {
    final Map<String, dynamic>? quiz =
        _quiz;

    if (quiz == null ||
        _questions.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final int score =
        _calculateScore();

    final int totalPoints =
        _getQuizTotalPoints(
      quiz,
      _questions,
    );

    try {
      await _quizService.submitQuizAttempt(
        quizId:
            widget.quizId,
        courseId:
            (quiz['courseId'] ?? '')
                .toString(),
        score:
            score,
        totalPoints:
            totalPoints,
      );

      if (!mounted) return;

      setState(() {
        _previousAttempt = {
          'quizId':
              widget.quizId,
          'score':
              score,
          'totalPoints':
              totalPoints,
          'status':
              'submitted',
        };

        _isSubmitting =
            false;
      });

      _showResultDialog(
        score:
            score,
        totalPoints:
            totalPoints,
      );
    } on QuizServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting =
            false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            e.message,
          ),
          backgroundColor:
              Colors.redAccent,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting =
            false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to submit quiz.',
          ),
          backgroundColor:
              Colors.redAccent,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // RESULTS DIALOG
  // ============================================================

  void _showResultDialog({
    required int score,
    required int totalPoints,
  }) {
    final int passingScore =
        _quiz?['passingScore'] is num
            ? (_quiz!['passingScore']
                    as num)
                .toInt()
            : 0;

    final bool passed =
        score >= passingScore;

    showDialog<void>(
      context: context,
      barrierDismissible:
          false,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title: const Text(
            'Quiz Completed',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                passed
                    ? Icons
                        .verified_rounded
                    : Icons
                        .school_rounded,
                color: passed
                    ? green
                    : primaryBlue,
                size: 60,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                '$score / $totalPoints',
                style:
                    const TextStyle(
                  fontSize:
                      28,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      textDark,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                passed
                    ? 'You passed the quiz.'
                    : 'Your attempt has been submitted.',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      textGrey,
                  fontSize:
                      13,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );

                  Navigator.pop(
                    context,
                    true,
                  );
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryBlue,
                ),
                child:
                    const Text(
                  'Finish',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // TOTAL QUIZ POINTS
  // ============================================================

  int _getQuizTotalPoints(
    Map<String, dynamic> quiz,
    List<Map<String, dynamic>> questions,
  ) {
    if (quiz['totalPoints'] is num) {
      return (quiz['totalPoints'] as num)
          .toInt();
    }

    int total = 0;

    for (final Map<String, dynamic> question
        in questions) {
      if (question['points'] is num) {
        total +=
            (question['points'] as num)
                .toInt();
      }
    }

    return total;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          AppBar(
        backgroundColor:
            const Color(
          0xFF1E2841,
        ),
        elevation:
            0,
        foregroundColor:
            Colors.white,
        title:
            Text(
          _quiz == null
              ? widget.quizTitle
              : (_quiz!['title'] ??
                      widget.quizTitle)
                  .toString(),
          style:
              const TextStyle(
            fontSize:
                16,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            Align(
          alignment:
              Alignment.topCenter,
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  1000,
            ),
            child:
                _buildContent(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              primaryBlue,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                    Colors.redAccent,
                size:
                    46,
              ),

              const SizedBox(
                height:
                    12,
              ),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      textGrey,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),

              TextButton.icon(
                onPressed:
                    _loadQuiz,
                icon:
                    const Icon(
                  Icons
                      .refresh_rounded,
                ),
                label:
                    const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Center(
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .quiz_outlined,
              color:
                  primaryBlue,
              size:
                  50,
            ),

            SizedBox(
              height:
                  12,
            ),

            Text(
              'No questions available',
              style:
                  TextStyle(
                color:
                    textDark,
                fontSize:
                    17,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final String attemptStatus =
        (_previousAttempt?['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (attemptStatus ==
        'submitted') {
      return _buildPreviousResult();
    }

    return _buildQuizQuestions();
  }

  // ============================================================
  // ALREADY SUBMITTED
  // ============================================================

  Widget _buildPreviousResult() {
    final int score =
        _previousAttempt?['score'] is num
            ? (_previousAttempt!['score']
                    as num)
                .toInt()
            : 0;

    final int totalPoints =
        _previousAttempt?['totalPoints']
                is num
            ? (_previousAttempt![
                        'totalPoints']
                    as num)
                .toInt()
            : _getQuizTotalPoints(
                _quiz!,
                _questions,
              );

    final int passingScore =
        _quiz?['passingScore'] is num
            ? (_quiz!['passingScore']
                    as num)
                .toInt()
            : 0;

    final bool passed =
        score >= passingScore;

    return Center(
      child:
          Container(
        margin:
            const EdgeInsets.all(
          24,
        ),
        constraints:
            const BoxConstraints(
          maxWidth:
              500,
        ),
        padding:
            const EdgeInsets.all(
          30,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          border:
              Border.all(
            color:
                const Color(
              0xFFE6EAF0,
            ),
          ),
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              passed
                  ? Icons
                      .fact_check_rounded
                  : Icons
                      .quiz_rounded,
              color: passed
                  ? green
                  : primaryBlue,
              size:
                  55,
            ),

            const SizedBox(
              height:
                  16,
            ),

            const Text(
              'Quiz Already Submitted',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    textDark,
                fontSize:
                    19,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              '$score / $totalPoints',
              style:
                  const TextStyle(
                color:
                    primaryBlue,
                fontSize:
                    30,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            Text(
              passed
                  ? 'Passed'
                  : 'Attempt submitted',
              style:
                  TextStyle(
                color: passed
                    ? green
                    : textGrey,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton(
                onPressed:
                    () {
                  Navigator.pop(
                    context,
                  );
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryBlue,
                ),
                child:
                    const Text(
                  'Back',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUIZ QUESTIONS
  // ============================================================

  Widget _buildQuizQuestions() {
    final Map<String, dynamic> question =
        _questions[
            _currentQuestionIndex];

    // Support both questionText and question just in case.
    final String questionText =
        (question['questionText'] ??
                question['question'] ??
                'Question')
            .toString();

    final dynamic optionsData =
        question['options'];

    final List<String> options =
        optionsData is List
            ? optionsData
                .map(
                  (option) =>
                      option.toString(),
                )
                .toList()
            : [];

    final int? selectedIndex =
        _selectedAnswers[
            _currentQuestionIndex];

    final double progress =
        (_currentQuestionIndex + 1) /
            _questions.length;

    final int points =
        question['points'] is num
            ? (question['points']
                    as num)
                .toInt()
            : 0;

    return Padding(
      padding:
          const EdgeInsets.all(
        24,
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  'Question ${_currentQuestionIndex + 1} '
                  'of ${_questions.length}',
                  style:
                      const TextStyle(
                    color:
                        textGrey,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              Text(
                '$points pts',
                style:
                    const TextStyle(
                  color:
                      primaryBlue,
                  fontSize:
                      13,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                10,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              5,
            ),
            child:
                LinearProgressIndicator(
              value:
                  progress,
              minHeight:
                  7,
              backgroundColor:
                  const Color(
                0xFFE4E8EF,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                primaryBlue,
              ),
            ),
          ),

          const SizedBox(
            height:
                32,
          ),

          Text(
            questionText,
            style:
                const TextStyle(
              color:
                  textDark,
              fontSize:
                  20,
              fontWeight:
                  FontWeight.w800,
              height:
                  1.4,
            ),
          ),

          const SizedBox(
            height:
                24,
          ),

          Expanded(
            child:
                options.isEmpty
                    ? const Center(
                        child:
                            Text(
                          'No answer options available.',
                          style:
                              TextStyle(
                            color:
                                textGrey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics:
                            const BouncingScrollPhysics(),
                        itemCount:
                            options.length,
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final bool isSelected =
                              selectedIndex ==
                                  index;

                          return GestureDetector(
                            onTap:
                                _isSubmitting
                                    ? null
                                    : () {
                                        _selectAnswer(
                                          index,
                                        );
                                      },
                            child:
                                Container(
                              margin:
                                  const EdgeInsets.only(
                                bottom:
                                    12,
                              ),
                              padding:
                                  const EdgeInsets.all(
                                16,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: isSelected
                                    ? primaryBlue.withValues(
                                        alpha:
                                            0.06,
                                      )
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                                border:
                                    Border.all(
                                  color: isSelected
                                      ? primaryBlue
                                      : const Color(
                                          0xFFE1E5EC,
                                        ),
                                  width: isSelected
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child:
                                  Row(
                                children: [
                                  Container(
                                    width:
                                        24,
                                    height:
                                        24,
                                    decoration:
                                        BoxDecoration(
                                      shape:
                                          BoxShape.circle,
                                      color: isSelected
                                          ? primaryBlue
                                          : Colors.transparent,
                                      border:
                                          Border.all(
                                        color: isSelected
                                            ? primaryBlue
                                            : const Color(
                                                0xFFADB5C3,
                                              ),
                                        width:
                                            2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color:
                                                Colors.white,
                                            size:
                                                15,
                                          )
                                        : null,
                                  ),

                                  const SizedBox(
                                    width:
                                        14,
                                  ),

                                  Expanded(
                                    child:
                                        Text(
                                      options[index],
                                      style:
                                          TextStyle(
                                        color: isSelected
                                            ? primaryBlue
                                            : textDark,
                                        fontSize:
                                            14.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          const SizedBox(
            height:
                12,
          ),

          Row(
            children: [
              if (_currentQuestionIndex >
                  0) ...[
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed:
                        _isSubmitting
                            ? null
                            : _previousQuestion,
                    style:
                        OutlinedButton.styleFrom(
                      minimumSize:
                          const Size(
                        0,
                        52,
                      ),
                      foregroundColor:
                          primaryBlue,
                    ),
                    child:
                        const Text(
                      'Previous',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      12,
                ),
              ],

              Expanded(
                flex:
                    2,
                child:
                    ElevatedButton(
                  onPressed:
                      selectedIndex != null &&
                              !_isSubmitting
                          ? _nextQuestion
                          : null,
                  style:
                      ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      52,
                    ),
                    backgroundColor:
                        primaryBlue,
                    disabledBackgroundColor:
                        const Color(
                      0xFFD1D6DE,
                    ),
                    elevation:
                        0,
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                              width:
                                  20,
                              height:
                                  20,
                              child:
                                  CircularProgressIndicator(
                                color:
                                    Colors.white,
                                strokeWidth:
                                    2.2,
                              ),
                            )
                          : Text(
                              _currentQuestionIndex ==
                                      _questions.length -
                                          1
                                  ? 'Submit Quiz'
                                  : 'Next Question',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}