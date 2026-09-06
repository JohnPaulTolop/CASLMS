import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

class InstructorAiQuizEditorScreen extends StatefulWidget {
  const InstructorAiQuizEditorScreen({
    super.key,
    required this.assessmentId,
    required this.courseId,
    required this.moduleId,
  });

  final String assessmentId;
  final String courseId;
  final String moduleId;

  @override
  State<InstructorAiQuizEditorScreen> createState() =>
      _InstructorAiQuizEditorScreenState();
}

class _InstructorAiQuizEditorScreenState
    extends State<InstructorAiQuizEditorScreen> {
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color red = Color(0xFFFF4B4B);
  static const Color green = Color(0xFF26A65B);
  static const Color purple = Color(0xFF7B4DFF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _instructionsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  String _difficulty = 'medium';

  DateTime? _dueAt;

  List<_EditableQuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();

    _loadAssessment();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();

    for (final _EditableQuizQuestion question in _questions) {
      question.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // LOAD DRAFT
  // ============================================================

  Future<void> _loadAssessment() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('No instructor is currently logged in.');
      }

      final DocumentSnapshot<Map<String, dynamic>> profileDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDocument.exists || profileDocument.data() == null) {
        throw Exception('Instructor profile could not be found.');
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

      if (role != 'instructor') {
        throw Exception('Only instructors can edit AI quizzes.');
      }

      if (accountStatus != 'active') {
        throw Exception('This instructor account is not active.');
      }

      final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!assessmentDocument.exists || assessmentDocument.data() == null) {
        throw Exception('AI quiz assessment could not be found.');
      }

      final Map<String, dynamic> data = assessmentDocument.data()!;

      final String courseId = (data['courseId'] ?? '').toString().trim();

      final String moduleId = (data['moduleId'] ?? '').toString().trim();

      final String createdBy = (data['createdBy'] ?? '').toString().trim();

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

      if (createdBy.isNotEmpty && createdBy != user.uid) {
        throw Exception('You can only edit assessments that you created.');
      }

      if (assessmentType != 'quiz' || deliveryType != 'ai_generated') {
        throw Exception('This editor only supports AI-generated quizzes.');
      }

      final List<dynamic> rawQuestions = data['questions'] is List
          ? List<dynamic>.from(data['questions'] as List)
          : <dynamic>[];

      if (rawQuestions.isEmpty) {
        throw Exception('This AI quiz has no questions.');
      }

      final List<_EditableQuizQuestion> loadedQuestions = [];

      for (int index = 0; index < rawQuestions.length; index++) {
        final dynamic raw = rawQuestions[index];

        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> questionData = Map<String, dynamic>.from(
          raw,
        );

        final List<String> options = questionData['options'] is List
            ? (questionData['options'] as List)
                  .map((dynamic value) => value.toString())
                  .toList()
            : <String>[];

        while (options.length < 4) {
          options.add('');
        }

        if (options.length > 4) {
          options.removeRange(4, options.length);
        }

        final int correctIndex =
            ((questionData['correctAnswerIndex'] as num?)?.toInt() ?? 0).clamp(
              0,
              3,
            );

        final int points = ((questionData['points'] as num?)?.toInt() ?? 1)
            .clamp(1, 100);

        loadedQuestions.add(
          _EditableQuizQuestion(
            question: (questionData['question'] ?? '').toString(),
            options: options,
            correctAnswerIndex: correctIndex,
            explanation: (questionData['explanation'] ?? '').toString(),
            points: points,
          ),
        );
      }

      if (loadedQuestions.isEmpty) {
        throw Exception('No valid AI quiz questions could be loaded.');
      }

      final dynamic rawDueAt = data['dueAt'];

      DateTime? dueAt;

      if (rawDueAt is Timestamp) {
        dueAt = rawDueAt.toDate();
      } else if (rawDueAt is DateTime) {
        dueAt = rawDueAt;
      }

      if (!mounted) {
        for (final question in loadedQuestions) {
          question.dispose();
        }

        return;
      }

      setState(() {
        _titleController.text = (data['title'] ?? '').toString();

        _instructionsController.text = (data['instructions'] ?? '').toString();

        final String savedDifficulty = (data['aiDifficulty'] ?? 'medium')
            .toString()
            .trim()
            .toLowerCase();

        _difficulty = {'easy', 'medium', 'hard'}.contains(savedDifficulty)
            ? savedDifficulty
            : 'medium';

        _dueAt = dueAt;

        _questions = loadedQuestions;

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
  // DATE / TIME
  // ============================================================

  Future<void> _pickDueDate() async {
    final DateTime now = DateTime.now();

    final DateTime initial =
        _dueAt?.toLocal() ?? now.add(const Duration(days: 7));

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (!mounted || date == null) {
      return;
    }

    final TimeOfDay currentTime = TimeOfDay.fromDateTime(initial);

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (!mounted || time == null) {
      return;
    }

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatDueDate(DateTime? value) {
    if (value == null) {
      return 'No due date';
    }

    final DateTime local = value.toLocal();

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

    final String minute = local.minute.toString().padLeft(2, '0');

    return '${months[local.month - 1]} '
        '${local.day}, ${local.year} • '
        '$hour:$minute $period';
  }

  // ============================================================
  // QUESTION MANAGEMENT
  // ============================================================

  void _addQuestion() {
    setState(() {
      _questions.add(
        _EditableQuizQuestion(
          question: '',
          options: const ['', '', '', ''],
          correctAnswerIndex: 0,
          explanation: '',
          points: 1,
        ),
      );
    });
  }

  Future<void> _deleteQuestion(int index) async {
    if (_questions.length <= 1) {
      _showError('A quiz must contain at least one question.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Question?'),
          content: Text('Remove question ${index + 1} from this quiz draft?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete', style: TextStyle(color: red)),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      final _EditableQuizQuestion removed = _questions.removeAt(index);

      removed.dispose();
    });
  }

  // ============================================================
  // VALIDATE AND SAVE
  // ============================================================

  Future<void> _saveDraft() async {
    if (_isSaving) {
      return;
    }

    final String title = _titleController.text.trim();

    final String instructions = _instructionsController.text.trim();

    if (title.isEmpty) {
      _showError('Quiz title is required.');

      return;
    }

    if (_questions.isEmpty) {
      _showError('Add at least one quiz question.');

      return;
    }

    final List<Map<String, dynamic>> questionData = [];

    int totalPoints = 0;

    for (int index = 0; index < _questions.length; index++) {
      final _EditableQuizQuestion question = _questions[index];

      final String questionText = question.questionController.text.trim();

      final List<String> options = question.optionControllers
          .map((TextEditingController controller) => controller.text.trim())
          .toList();

      final String explanation = question.explanationController.text.trim();

      final int points =
          int.tryParse(question.pointsController.text.trim()) ?? 0;

      if (questionText.isEmpty) {
        _showError('Question ${index + 1} is empty.');

        return;
      }

      if (options.length != 4 ||
          options.any((String option) => option.isEmpty)) {
        _showError(
          'Question ${index + 1} must have exactly 4 non-empty choices.',
        );

        return;
      }

      if (options.toSet().length != options.length) {
        _showError('Question ${index + 1} contains duplicate choices.');

        return;
      }

      if (question.correctAnswerIndex < 0 || question.correctAnswerIndex > 3) {
        _showError('Select a correct answer for question ${index + 1}.');

        return;
      }

      if (points <= 0 || points > 100) {
        _showError(
          'Points for question ${index + 1} must be between 1 and 100.',
        );

        return;
      }

      totalPoints += points;

      questionData.add({
        'order': index + 1,
        'questionType': 'multiple_choice',
        'question': questionText,
        'options': options,
        'correctAnswerIndex': question.correctAnswerIndex,
        'explanation': explanation,
        'points': points,
      });
    }

    if (_dueAt != null && _dueAt!.isBefore(DateTime.now())) {
      _showError('Due date must be in the future.');

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('No instructor is currently logged in.');
      }

      final DocumentReference<Map<String, dynamic>> reference = _firestore
          .collection('assessments')
          .doc(widget.assessmentId);

      final DocumentSnapshot<Map<String, dynamic>> currentDocument =
          await reference.get();

      if (!currentDocument.exists || currentDocument.data() == null) {
        throw Exception('The AI quiz no longer exists.');
      }

      final Map<String, dynamic> currentData = currentDocument.data()!;

      final String createdBy = (currentData['createdBy'] ?? '')
          .toString()
          .trim();

      final String status = (currentData['status'] ?? 'draft')
          .toString()
          .trim()
          .toLowerCase();

      if (createdBy.isNotEmpty && createdBy != user.uid) {
        throw Exception('You can only edit assessments that you created.');
      }

      // Phase 13C-3 edits are intended for drafts.
      // Published/closed assessments are protected from accidental
      // edits here. Later phases can define a separate revision flow.
      if (status != 'draft') {
        throw Exception(
          'Only draft AI quizzes can be edited. Move this assessment to Draft first.',
        );
      }

      await reference.update({
        'title': title,
        'instructions': instructions,
        'questions': questionData,
        'questionCount': questionData.length,
        'totalPoints': totalPoints,
        'dueAt': _dueAt == null ? null : Timestamp.fromDate(_dueAt!),
        'aiDifficulty': _difficulty,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
          _isSaving = false;
        });
      }
    }
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
    return instructorScaffold(
      context: context,
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
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
        title: const Text(
          'Review AI Quiz',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveDraft,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryTeal,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'Saving' : 'Save Draft'),
            style: TextButton.styleFrom(foregroundColor: primaryTeal),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryTeal))
          : _errorMessage != null
          ? _buildErrorState()
          : _buildEditor(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 52),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Unable to load AI quiz.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });

                _loadAssessment();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: primaryTeal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final int totalPoints = _questions.fold<int>(0, (
      int total,
      _EditableQuizQuestion question,
    ) {
      return total + (int.tryParse(question.pointsController.text.trim()) ?? 0);
    });

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoBanner(),
                const SizedBox(height: 20),
                _buildQuizSettingsCard(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Questions',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_questions.length} questions • $totalPoints points',
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  _questions.length,
                  (int index) => _buildQuestionCard(index, _questions[index]),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _addQuestion,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Question'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTeal,
                    side: const BorderSide(color: primaryTeal),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveDraft,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSaving ? 'Saving Draft...' : 'Save Quiz Draft',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purple.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: purple),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Review every AI-generated question before publishing. '
              'You can edit the question, all four choices, the correct '
              'answer, explanation, points, quiz details, and due date.',
              style: TextStyle(
                color: textDark,
                height: 1.45,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quiz Details',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            enabled: !_isSaving,
            decoration: const InputDecoration(
              labelText: 'Quiz title',
              prefixIcon: Icon(Icons.quiz_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _instructionsController,
            enabled: !_isSaving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty',
              prefixIcon: Icon(Icons.speed_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'easy', child: Text('Easy')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'hard', child: Text('Hard')),
            ],
            onChanged: _isSaving
                ? null
                : (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _difficulty = value;
                    });
                  },
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSaving ? null : _pickDueDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due date',
                prefixIcon: Icon(Icons.schedule_rounded),
                suffixIcon: Icon(Icons.edit_calendar_rounded),
              ),
              child: Text(
                _formatDueDate(_dueAt),
                style: const TextStyle(color: textDark),
              ),
            ),
          ),
          if (_dueAt != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _dueAt = null;
                        });
                      },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Remove due date'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, _EditableQuizQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                  color: primaryTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: const TextStyle(
                    color: primaryTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete question',
                onPressed: _isSaving
                    ? null
                    : () {
                        _deleteQuestion(index);
                      },
                icon: const Icon(Icons.delete_outline_rounded, color: red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: question.questionController,
            enabled: !_isSaving,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Question',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Answer choices',
            style: TextStyle(
              color: textDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (int optionIndex) {
            final String letter = String.fromCharCode(65 + optionIndex);

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Radio<int>(
                    value: optionIndex,
                    groupValue: question.correctAnswerIndex,
                    activeColor: green,
                    onChanged: _isSaving
                        ? null
                        : (int? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              question.correctAnswerIndex = value;
                            });
                          },
                  ),
                  SizedBox(
                    width: 26,
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: textGrey,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: question.optionControllers[optionIndex],
                      enabled: !_isSaving,
                      decoration: InputDecoration(hintText: 'Choice $letter'),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          TextField(
            controller: question.explanationController,
            enabled: !_isSaving,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
              prefixIcon: Icon(Icons.lightbulb_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 170,
            child: TextField(
              controller: question.pointsController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Points',
                prefixIcon: Icon(Icons.stars_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: green, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Correct answer: '
                  '${String.fromCharCode(65 + question.correctAnswerIndex)}',
                  style: const TextStyle(
                    color: green,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

// ============================================================
// EDITABLE QUESTION MODEL
// ============================================================

class _EditableQuizQuestion {
  _EditableQuizQuestion({
    required String question,
    required List<String> options,
    required int correctAnswerIndex,
    required String explanation,
    required int points,
  }) : questionController = TextEditingController(text: question),
       optionControllers = List<TextEditingController>.generate(4, (int index) {
         final String value = index < options.length ? options[index] : '';

         return TextEditingController(text: value);
       }),
       explanationController = TextEditingController(text: explanation),
       pointsController = TextEditingController(text: points.toString()),
       correctAnswerIndex = correctAnswerIndex;

  final TextEditingController questionController;

  final List<TextEditingController> optionControllers;

  final TextEditingController explanationController;

  final TextEditingController pointsController;

  int correctAnswerIndex;

  void dispose() {
    questionController.dispose();

    for (final controller in optionControllers) {
      controller.dispose();
    }

    explanationController.dispose();

    pointsController.dispose();
  }
}
