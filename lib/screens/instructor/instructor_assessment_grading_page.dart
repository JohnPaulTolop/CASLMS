import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/assessment_submission_service.dart';

class InstructorAssessmentGradingScreen extends StatefulWidget {
  const InstructorAssessmentGradingScreen({
    super.key,
    required this.assessmentId,
  });

  final String assessmentId;

  @override
  State<InstructorAssessmentGradingScreen> createState() =>
      _InstructorAssessmentGradingScreenState();
}

class _InstructorAssessmentGradingScreenState
    extends State<InstructorAssessmentGradingScreen> {
  static const primaryTeal = Color(0xFF00897B);
  static const background = Color(0xFFF7F9FC);
  static const textDark = Color(0xFF10182F);
  static const textGrey = Color(0xFF68738A);
  static const borderColor = Color(0xFFE6EAF0);
  static const green = Color(0xFF26A65B);
  static const orange = Color(0xFFFF9418);
  static const red = Color(0xFFFF4B4B);

  final _firestore = FirebaseFirestore.instance;
  final _submissionService = AssessmentSubmissionService();

  bool _isLoading = true;
  bool _gradeDialogOpen = false;
  String? _errorMessage;

  Map<String, dynamic>? _assessment;
  Map<String, dynamic>? _course;
  Map<String, dynamic>? _module;

  List<Map<String, dynamic>> _submissions = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  String get _assessmentTitle =>
      (_assessment?['title'] ?? 'Assessment').toString();

  String get _assessmentType =>
      (_assessment?['assessmentType'] ?? 'assessment').toString();

  num get _totalPoints =>
      (_assessment?['totalPoints'] as num?) ?? 0;

  String _status(Map<String, dynamic> submission) =>
      (submission['status'] ?? '').toString().trim().toLowerCase();

  int get _gradedCount =>
      _submissions.where((s) => _status(s) == 'graded').length;

  int get _submittedCount =>
      _submissions.where((s) => _status(s) == 'submitted').length;

  List<Map<String, dynamic>> get _filteredSubmissions {
    if (_selectedFilter == 'all') return _submissions;
    return _submissions
        .where((s) => _status(s) == _selectedFilter)
        .toList();
  }

  Future<void> _loadPage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final id = widget.assessmentId.trim();

      if (id.isEmpty) {
        throw AssessmentSubmissionException('Assessment ID is missing.');
      }

      final assessmentDocument = await _firestore
          .collection('assessments')
          .doc(id)
          .get();

      final assessment = assessmentDocument.data();

      if (assessment == null) {
        throw AssessmentSubmissionException(
          'Assessment could not be found.',
        );
      }

      final courseId = (assessment['courseId'] ?? '').toString();
      final moduleId = (assessment['moduleId'] ?? '').toString();

      if (courseId.isEmpty || moduleId.isEmpty) {
        throw AssessmentSubmissionException(
          'Course or module information is missing.',
        );
      }

      final submissions = await _submissionService
          .getAssessmentSubmissions(assessmentId: id);

      final courseDocument = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      final moduleDocument = await _firestore
          .collection('modules')
          .doc(moduleId)
          .get();

      submissions.sort((a, b) {
        final aPending = _status(a) == 'submitted';
        final bPending = _status(b) == 'submitted';

        if (aPending != bPending) return aPending ? -1 : 1;

        return (a['studentName'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              (b['studentName'] ?? '').toString().toLowerCase(),
            );
      });

      if (!mounted) return;

      setState(() {
        _assessment = {...assessment, 'id': id};
        _course = courseDocument.data();
        _module = moduleDocument.data();
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is AssessmentSubmissionException
            ? error.message
            : error.toString();
      });
    }
  }

  num _submissionTotal(Map<String, dynamic> submission) {
    return submission['totalPoints'] is num
        ? submission['totalPoints'] as num
        : _totalPoints;
  }

  String _rating(Map<String, dynamic> submission) {
    final stored = submission['percentage'];

    if (stored is num && stored.isFinite) {
      return '${stored.toStringAsFixed(1)}%';
    }

    final score = submission['score'];
    final total = _submissionTotal(submission);

    if (score is! num || total <= 0) return 'Not available';

    return '${(score / total * 100).toStringAsFixed(1)}%';
  }

  String _formatDate(dynamic value) {
    final DateTime? date = value is Timestamp
        ? value.toDate().toLocal()
        : value is DateTime
        ? value.toLocal()
        : null;

    if (date == null) return 'Unknown';

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

  Future<void> _openGradeDialog(
    Map<String, dynamic> submission,
  ) async {
    if (!mounted || _gradeDialogOpen) return;

    final id = (submission['submissionId'] ?? submission['id'] ?? '')
        .toString()
        .trim();

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission ID is missing.')),
      );
      return;
    }

    _gradeDialogOpen = true;

    try {
      final navigator = Navigator.of(context, rootNavigator: true);

      // Do not put the automatic scoring message into the
      // instructor's feedback editor on a new quiz submission.
      final automaticWithoutFeedback =
          submission['gradingMode'] == 'automatic' &&
          submission['feedbackBy'] == null;

      final route = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AssessmentFeedbackDialog(
          service: _submissionService,
          submissionId: id,
          studentName:
              (submission['studentName'] ?? 'Student').toString(),
          assessmentTitle: _assessmentTitle,
          score: submission['score'] is num
              ? submission['score'] as num
              : null,
          totalPoints: _submissionTotal(submission),
          rating: _rating(submission),
          feedback: automaticWithoutFeedback
              ? ''
              : (submission['feedback'] ?? '').toString(),
        ),
      );

      final saved = await navigator.push<bool>(route);

      // Wait for the overlay and closing transition to finish.
      await route.completed;

      if (!mounted || saved != true) return;

      await _loadPage();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback saved successfully.'),
          backgroundColor: green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _gradeDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Assessment Grading',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPage,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryTeal),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPage,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filteredSubmissions;

    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryTeal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Total',
                  '${_submissions.length}',
                  Icons.people_alt_outlined,
                  primaryTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  'Submitted',
                  '$_submittedCount',
                  Icons.pending_actions,
                  orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  'Graded',
                  '$_gradedCount',
                  Icons.verified_outlined,
                  green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Student Submissions',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'View scores and ratings. Only instructor feedback is editable.',
            style: TextStyle(color: textGrey, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filter('all', 'All (${_submissions.length})'),
              _filter('submitted', 'Submitted ($_submittedCount)'),
              _filter('graded', 'Graded ($_gradedCount)'),
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    color: primaryTeal,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text('No submissions in this filter.'),
                ],
              ),
            )
          else
            ...visible.map(_submissionCard),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final courseCode = (_course?['code'] ?? '').toString();
    final moduleTitle = (_module?['title'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (courseCode.isNotEmpty) courseCode,
              if (moduleTitle.isNotEmpty) moduleTitle,
            ].join(' • '),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            _assessmentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            (_course?['title'] ?? '').toString(),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(_assessmentType),
              _headerChip('$_totalPoints points'),
              _headerChip('Due ${_formatDate(_assessment?['dueAt'])}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _filter(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      selectedColor: primaryTeal.withValues(alpha: 0.12),
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _submissionCard(Map<String, dynamic> submission) {
    final name = (submission['studentName'] ?? 'Student').toString();
    final graded = _status(submission) == 'graded';
    final score = submission['score'];
    final total = _submissionTotal(submission);
    final feedback = (submission['feedback'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryTeal.withValues(alpha: 0.1),
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(color: primaryTeal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      graded
                          ? 'Graded ${_formatDate(submission['gradedAt'])}'
                          : 'Submitted ${_formatDate(submission['submittedAt'])}',
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                graded ? 'GRADED' : 'SUBMITTED',
                style: TextStyle(
                  color: graded ? green : orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            score is num ? 'Score: $score / $total' : 'Score: Not graded',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text('Rating: ${_rating(submission)}'),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              feedback,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textGrey),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openGradeDialog(submission),
              icon: const Icon(Icons.comment_outlined),
              label: const Text('View Score & Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentFeedbackDialog extends StatefulWidget {
  const _AssessmentFeedbackDialog({
    required this.service,
    required this.submissionId,
    required this.studentName,
    required this.assessmentTitle,
    required this.score,
    required this.totalPoints,
    required this.rating,
    required this.feedback,
  });

  final AssessmentSubmissionService service;
  final String submissionId;
  final String studentName;
  final String assessmentTitle;
  final num? score;
  final num totalPoints;
  final String rating;
  final String feedback;

  @override
  State<_AssessmentFeedbackDialog> createState() =>
      _AssessmentFeedbackDialogState();
}

class _AssessmentFeedbackDialogState
    extends State<_AssessmentFeedbackDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.feedback);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final feedback = _controller.text.trim();

    if (feedback.isEmpty) {
      setState(() => _error = 'Please enter feedback.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.saveFeedback(
        submissionId: widget.submissionId,
        feedback: feedback,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = error is AssessmentSubmissionException
            ? error.message
            : 'Unable to save feedback: $error';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Score, Rating & Feedback'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.assessmentTitle),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.score == null
                            ? 'Score: Not graded'
                            : 'Score: ${widget.score} / ${widget.totalPoints}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Rating: ${widget.rating}'),
                      const SizedBox(height: 10),
                      const Text(
                        'Scores and ratings are read-only.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !_saving,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Instructor feedback',
                    hintText: 'Write feedback for this student...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text(
                  'New or changed feedback notifies only this student.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).pop(false);
                  },
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.comment_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Feedback'),
          ),
        ],
      ),
    );
  }
}