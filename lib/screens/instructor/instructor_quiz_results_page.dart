import '../../core/app_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'instructor_task_widgets.dart';

import '../../services/quiz_service.dart';

class InstructorQuizResultsScreen extends StatefulWidget {
  const InstructorQuizResultsScreen({super.key, this.quizService});
  final QuizService? quizService;

  @override
  State<InstructorQuizResultsScreen> createState() =>
      _InstructorQuizResultsScreenState();
}

class _InstructorQuizResultsScreenState
    extends State<InstructorQuizResultsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);

  Color get green => AppColors.resolve(context, AppColors.green);

  Color get red => AppColors.resolve(context, AppColors.error);

  // ============================================================
  // SERVICE
  // ============================================================

  late final QuizService _quizService = widget.quizService ?? QuizService();

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _results = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  String _filter = 'all';

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadResults();
  }

  // ============================================================
  // LOAD RESULTS
  // ============================================================

  Future<void> _loadResults() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> results = await _quizService
          .getInstructorQuizResults();

      if (!mounted) return;

      setState(() {
        _results = results;

        _isLoading = false;

        _errorMessage = null;
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

        _errorMessage = 'Unable to load quiz results.';
      });
    }
  }

  // ============================================================
  // FILTER RESULTS
  // ============================================================

  List<Map<String, dynamic>> get _filteredResults {
    return _results.where((result) {
      final String query = _searchQuery.trim().toLowerCase();

      final String studentName = (result['studentName'] ?? '')
          .toString()
          .toLowerCase();

      final String studentEmail = (result['studentEmail'] ?? '')
          .toString()
          .toLowerCase();

      final String quizTitle = (result['quizTitle'] ?? '')
          .toString()
          .toLowerCase();

      final String courseCode = (result['courseCode'] ?? '')
          .toString()
          .toLowerCase();

      final String courseTitle = (result['courseTitle'] ?? '')
          .toString()
          .toLowerCase();

      final bool matchesSearch =
          query.isEmpty ||
          studentName.contains(query) ||
          studentEmail.contains(query) ||
          quizTitle.contains(query) ||
          courseCode.contains(query) ||
          courseTitle.contains(query);

      final bool passed = result['passed'] == true;

      bool matchesFilter = true;

      if (_filter == 'passed') {
        matchesFilter = passed;
      }

      if (_filter == 'failed') {
        matchesFilter = !passed;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _passedCount {
    return _results.where((result) {
      return result['passed'] == true;
    }).length;
  }

  int get _failedCount {
    return _results.where((result) {
      return result['passed'] != true;
    }).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return InstructorTaskScaffold(
      loading: _isLoading,
      title: 'Quiz results',
      subtitle: 'Find a student and review their scored quiz attempts.',
      actions: [
        IconButton(
          tooltip: 'Refresh results',
          onPressed: _isLoading ? null : _loadResults,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],

      // ==========================================================
      // BODY
      // ==========================================================
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: RefreshIndicator(
              color: primaryTeal,
              onRefresh: _loadResults,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: InstructorTaskScaffold.paddingOf(context),
                children: [
                  // ==============================================
                  // PAGE INTRO
                  // ==============================================

                  // ==============================================
                  // SEARCH
                  // ==============================================
                  _buildSearch(),

                  const SizedBox(height: 18),

                  // ==============================================
                  // FILTERS
                  // ==============================================
                  _buildFilters(),

                  const SizedBox(height: 24),

                  // ==============================================
                  // RESULTS
                  // ==============================================
                  _buildContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search student, quiz, or course...',

        hintStyle: const TextStyle(color: Color(0xFFA0A8B7), fontSize: 13),

        prefixIcon: Icon(Icons.search_rounded, color: primaryTeal),

        filled: true,

        fillColor: Theme.of(context).colorScheme.surface,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.resolve(context, AppColors.inputBorder),
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.resolve(context, AppColors.inputBorder),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryTeal, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilter('All (${_results.length})', 'all'),

          const SizedBox(width: 10),

          _buildFilter('Passed ($_passedCount)', 'passed'),

          const SizedBox(width: 10),

          _buildFilter('Failed ($_failedCount)', 'failed'),
        ],
      ),
    );
  }

  Widget _buildFilter(String title, String value) {
    final bool selected = _filter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? primaryTeal : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? primaryTeal
                : AppColors.resolve(context, AppColors.inputBorder),
            width: 1.3,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : textGrey,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    // ------------------------------------------------------------
    // LOADING
    // ------------------------------------------------------------

    if (_isLoading) {
      return SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(color: primaryTeal)),
      );
    }

    // ------------------------------------------------------------
    // ERROR
    // ------------------------------------------------------------

    if (_errorMessage != null) {
      return _buildMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load results',
        message: _errorMessage!,
        color: Colors.redAccent,
        showRetry: true,
      );
    }

    // ------------------------------------------------------------
    // NO RESULTS
    // ------------------------------------------------------------

    if (_results.isEmpty) {
      return _buildMessage(
        icon: Icons.quiz_outlined,
        title: 'No quiz results yet',
        message: 'Submitted student quiz attempts will appear here.',
        color: primaryTeal,
      );
    }

    // ------------------------------------------------------------
    // NO FILTERED RESULTS
    // ------------------------------------------------------------

    if (_filteredResults.isEmpty) {
      return _buildMessage(
        icon: Icons.search_off_rounded,
        title: 'No matching results',
        message: 'Try another search or filter.',
        color: textGrey,
      );
    }

    // ------------------------------------------------------------
    // REAL RESULTS
    // ------------------------------------------------------------

    return Column(
      children: _filteredResults.map((result) {
        return _buildResultCard(result);
      }).toList(),
    );
  }

  // ============================================================
  // RESULT CARD
  // ============================================================

  Widget _buildResultCard(Map<String, dynamic> result) {
    final String studentName = (result['studentName'] ?? 'Student').toString();

    final String studentEmail = (result['studentEmail'] ?? '').toString();

    final String quizTitle = (result['quizTitle'] ?? 'Quiz').toString();

    final String courseCode = (result['courseCode'] ?? '').toString();

    final String courseTitle = (result['courseTitle'] ?? 'Course').toString();

    final int score = result['score'] is num
        ? (result['score'] as num).toInt()
        : 0;

    final int totalPoints = result['totalPoints'] is num
        ? (result['totalPoints'] as num).toInt()
        : 0;

    final int passingScore = result['passingScore'] is num
        ? (result['passingScore'] as num).toInt()
        : 0;

    final bool passed = result['passed'] == true;

    final DateTime? submittedAt = _toDate(result['submittedAt']);

    final double percentage = totalPoints <= 0
        ? 0
        : (score / totalPoints) * 100;

    final String initial = studentName.trim().isEmpty
        ? '?'
        : studentName.trim()[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.resolve(context, AppColors.inputBorder),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================================================
          // STUDENT
          // ======================================================

          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: primaryTeal.withValues(alpha: 0.10),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: primaryTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (studentEmail.trim().isNotEmpty)
                      Text(
                        studentEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textGrey, fontSize: 11),
                      ),

                    if (submittedAt != null)
                      Text(
                        'Submitted ${_formatDate(submittedAt)}',
                        style: TextStyle(color: textGrey, fontSize: 10.5),
                      ),
                  ],
                ),
              ),

              // ==================================================
              // PASS / FAIL
              // ==================================================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (passed ? green : red).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  passed ? 'Passed' : 'Failed',
                  style: TextStyle(
                    color: passed ? green : red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ======================================================
          // QUIZ
          // ======================================================
          Text(
            quizTitle,
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            courseCode.isEmpty ? courseTitle : '$courseCode • $courseTitle',
            style: TextStyle(
              color: primaryTeal,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // SCORE BOXES
          // ======================================================
          Row(
            children: [
              Expanded(
                child: _buildScoreBox(
                  label: 'Score',
                  value: '$score / $totalPoints',
                  icon: Icons.stars_rounded,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildScoreBox(
                  label: 'Percentage',
                  value: '${percentage.toStringAsFixed(0)}%',
                  icon: Icons.percent_rounded,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildScoreBox(
                  label: 'Pass Mark',
                  value: '$passingScore',
                  icon: Icons.flag_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCORE BOX
  // ============================================================

  Widget _buildScoreBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.resolve(context, AppColors.background),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryTeal, size: 17),

          const SizedBox(height: 6),

          Text(label, style: TextStyle(color: textGrey, fontSize: 9.5)),

          const SizedBox(height: 2),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE STATE
  // ============================================================

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    bool showRetry = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.resolve(context, AppColors.inputBorder),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 46),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
          ),

          if (showRetry) ...[
            const SizedBox(height: 14),

            TextButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(DateTime date) {
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

    final int hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final String minute = date.minute.toString().padLeft(2, '0');

    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year} • '
        '$hour:$minute $period';
  }
}
