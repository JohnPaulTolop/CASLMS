import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/quiz_service.dart';

class InstructorQuizResultsScreen extends StatefulWidget {
  const InstructorQuizResultsScreen({
    super.key,
  });

  @override
  State<InstructorQuizResultsScreen> createState() =>
      _InstructorQuizResultsScreenState();
}

class _InstructorQuizResultsScreenState
    extends State<InstructorQuizResultsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal =
      Color(0xFF00897B);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color green =
      Color(0xFF26A65B);

  static const Color red =
      Color(0xFFFF4B4B);

  // ============================================================
  // SERVICE
  // ============================================================

  final QuizService _quizService =
      QuizService();

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _results = [];

  bool _isLoading =
      true;

  String? _errorMessage;

  String _searchQuery =
      '';

  String _filter =
      'all';

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
      final List<Map<String, dynamic>> results =
          await _quizService
              .getInstructorQuizResults();

      if (!mounted) return;

      setState(() {
        _results =
            results;

        _isLoading =
            false;

        _errorMessage =
            null;
      });
    } on QuizServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            'Unable to load quiz results.';
      });
    }
  }

  // ============================================================
  // FILTER RESULTS
  // ============================================================

  List<Map<String, dynamic>>
      get _filteredResults {
    return _results.where(
      (result) {
        final String query =
            _searchQuery
                .trim()
                .toLowerCase();

        final String studentName =
            (result['studentName'] ?? '')
                .toString()
                .toLowerCase();

        final String studentEmail =
            (result['studentEmail'] ?? '')
                .toString()
                .toLowerCase();

        final String quizTitle =
            (result['quizTitle'] ?? '')
                .toString()
                .toLowerCase();

        final String courseCode =
            (result['courseCode'] ?? '')
                .toString()
                .toLowerCase();

        final String courseTitle =
            (result['courseTitle'] ?? '')
                .toString()
                .toLowerCase();

        final bool matchesSearch =
            query.isEmpty ||
                studentName.contains(query) ||
                studentEmail.contains(query) ||
                quizTitle.contains(query) ||
                courseCode.contains(query) ||
                courseTitle.contains(query);

        final bool passed =
            result['passed'] == true;

        bool matchesFilter =
            true;

        if (_filter == 'passed') {
          matchesFilter =
              passed;
        }

        if (_filter == 'failed') {
          matchesFilter =
              !passed;
        }

        return matchesSearch &&
            matchesFilter;
      },
    ).toList();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _passedCount {
    return _results.where(
      (result) {
        return result['passed'] == true;
      },
    ).length;
  }

  int get _failedCount {
    return _results.where(
      (result) {
        return result['passed'] != true;
      },
    ).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar:
          AppBar(
        backgroundColor:
            background,
        elevation:
            0,
        centerTitle:
            true,

        leading:
            IconButton(
          icon:
              const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            color:
                textDark,
            size:
                20,
          ),
          onPressed:
              () {
            Navigator.pop(
              context,
            );
          },
        ),

        title:
            const Text(
          'Quiz Results',
          style:
              TextStyle(
            color:
                textDark,
            fontSize:
                18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Refresh',
            icon:
                const Icon(
              Icons
                  .refresh_rounded,
              color:
                  textDark,
            ),
            onPressed:
                _loadResults,
          ),

          const SizedBox(
            width:
                8,
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

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
                  1100,
            ),
            child:
                RefreshIndicator(
              color:
                  primaryTeal,
              onRefresh:
                  _loadResults,
              child:
                  ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(
                  parent:
                      BouncingScrollPhysics(),
                ),
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  32,
                ),
                children: [
                  // ==============================================
                  // PAGE INTRO
                  // ==============================================

                  const Text(
                    'Student Quiz Performance',
                    style:
                        TextStyle(
                      color:
                          textDark,
                      fontSize:
                          22,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing:
                          -0.5,
                    ),
                  ),

                  const SizedBox(
                    height:
                        5,
                  ),

                  const Text(
                    'View automatically scored quiz attempts from your students.',
                    style:
                        TextStyle(
                      color:
                          textGrey,
                      fontSize:
                          13,
                      height:
                          1.4,
                    ),
                  ),

                  const SizedBox(
                    height:
                        22,
                  ),

                  // ==============================================
                  // SEARCH
                  // ==============================================

                  _buildSearch(),

                  const SizedBox(
                    height:
                        18,
                  ),

                  // ==============================================
                  // FILTERS
                  // ==============================================

                  _buildFilters(),

                  const SizedBox(
                    height:
                        24,
                  ),

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
      onChanged:
          (value) {
        setState(() {
          _searchQuery =
              value;
        });
      },
      decoration:
          InputDecoration(
        hintText:
            'Search student, quiz, or course...',

        hintStyle:
            const TextStyle(
          color:
              Color(
            0xFFA0A8B7,
          ),
          fontSize:
              13,
        ),

        prefixIcon:
            const Icon(
          Icons
              .search_rounded,
          color:
              primaryTeal,
        ),

        filled:
            true,

        fillColor:
            Colors.white,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFFE3E7EE,
            ),
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(
              0xFFE3E7EE,
            ),
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                primaryTeal,
            width:
                1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      physics:
          const BouncingScrollPhysics(),
      child:
          Row(
        children: [
          _buildFilter(
            'All (${_results.length})',
            'all',
          ),

          const SizedBox(
            width:
                10,
          ),

          _buildFilter(
            'Passed ($_passedCount)',
            'passed',
          ),

          const SizedBox(
            width:
                10,
          ),

          _buildFilter(
            'Failed ($_failedCount)',
            'failed',
          ),
        ],
      ),
    );
  }

  Widget _buildFilter(
    String title,
    String value,
  ) {
    final bool selected =
        _filter ==
            value;

    return GestureDetector(
      onTap:
          () {
        setState(() {
          _filter =
              value;
        });
      },
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              16,
          vertical:
              9,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? primaryTeal
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border:
              Border.all(
            color: selected
                ? primaryTeal
                : const Color(
                    0xFFE3E7EE,
                  ),
            width:
                1.3,
          ),
        ),
        child:
            Text(
          title,
          style:
              TextStyle(
            color: selected
                ? Colors.white
                : textGrey,
            fontWeight:
                FontWeight.w700,
            fontSize:
                12,
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
      return const SizedBox(
        height:
            280,
        child:
            Center(
          child:
              CircularProgressIndicator(
            color:
                primaryTeal,
          ),
        ),
      );
    }

    // ------------------------------------------------------------
    // ERROR
    // ------------------------------------------------------------

    if (_errorMessage != null) {
      return _buildMessage(
        icon:
            Icons.cloud_off_rounded,
        title:
            'Unable to load results',
        message:
            _errorMessage!,
        color:
            Colors.redAccent,
        showRetry:
            true,
      );
    }

    // ------------------------------------------------------------
    // NO RESULTS
    // ------------------------------------------------------------

    if (_results.isEmpty) {
      return _buildMessage(
        icon:
            Icons.quiz_outlined,
        title:
            'No quiz results yet',
        message:
            'Submitted student quiz attempts will appear here.',
        color:
            primaryTeal,
      );
    }

    // ------------------------------------------------------------
    // NO FILTERED RESULTS
    // ------------------------------------------------------------

    if (_filteredResults.isEmpty) {
      return _buildMessage(
        icon:
            Icons.search_off_rounded,
        title:
            'No matching results',
        message:
            'Try another search or filter.',
        color:
            textGrey,
      );
    }

    // ------------------------------------------------------------
    // REAL RESULTS
    // ------------------------------------------------------------

    return Column(
      children:
          _filteredResults.map(
        (result) {
          return _buildResultCard(
            result,
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // RESULT CARD
  // ============================================================

  Widget _buildResultCard(
    Map<String, dynamic> result,
  ) {
    final String studentName =
        (result['studentName'] ??
                'Student')
            .toString();

    final String studentEmail =
        (result['studentEmail'] ??
                '')
            .toString();

    final String quizTitle =
        (result['quizTitle'] ??
                'Quiz')
            .toString();

    final String courseCode =
        (result['courseCode'] ??
                '')
            .toString();

    final String courseTitle =
        (result['courseTitle'] ??
                'Course')
            .toString();

    final int score =
        result['score'] is num
            ? (result['score'] as num)
                .toInt()
            : 0;

    final int totalPoints =
        result['totalPoints'] is num
            ? (result['totalPoints']
                    as num)
                .toInt()
            : 0;

    final int passingScore =
        result['passingScore'] is num
            ? (result['passingScore']
                    as num)
                .toInt()
            : 0;

    final bool passed =
        result['passed'] ==
            true;

    final DateTime? submittedAt =
        _toDate(
      result['submittedAt'],
    );

    final double percentage =
        totalPoints <= 0
            ? 0
            : (score / totalPoints) *
                100;

    final String initial =
        studentName.trim().isEmpty
            ? '?'
            : studentName
                .trim()[0]
                .toUpperCase();

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            14,
      ),
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE6EAF0,
          ),
          width:
              1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  0.02,
            ),
            blurRadius:
                12,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================================
          // STUDENT
          // ======================================================

          Row(
            children: [
              CircleAvatar(
                radius:
                    21,
                backgroundColor:
                    primaryTeal.withValues(
                  alpha:
                      0.10,
                ),
                child:
                    Text(
                  initial,
                  style:
                      const TextStyle(
                    color:
                        primaryTeal,
                    fontWeight:
                        FontWeight.w800,
                    fontSize:
                        16,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style:
                          const TextStyle(
                        color:
                            textDark,
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    if (studentEmail
                        .trim()
                        .isNotEmpty)
                      Text(
                        studentEmail,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              textGrey,
                          fontSize:
                              11,
                        ),
                      ),

                    if (submittedAt != null)
                      Text(
                        'Submitted ${_formatDate(submittedAt)}',
                        style:
                            const TextStyle(
                          color:
                              textGrey,
                          fontSize:
                              10.5,
                        ),
                      ),
                  ],
                ),
              ),

              // ==================================================
              // PASS / FAIL
              // ==================================================

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      10,
                  vertical:
                      6,
                ),
                decoration:
                    BoxDecoration(
                  color: (passed
                          ? green
                          : red)
                      .withValues(
                    alpha:
                        0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child:
                    Text(
                  passed
                      ? 'Passed'
                      : 'Failed',
                  style:
                      TextStyle(
                    color: passed
                        ? green
                        : red,
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                18,
          ),

          // ======================================================
          // QUIZ
          // ======================================================

          Text(
            quizTitle,
            style:
                const TextStyle(
              color:
                  textDark,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
                4,
          ),

          Text(
            courseCode.isEmpty
                ? courseTitle
                : '$courseCode • $courseTitle',
            style:
                const TextStyle(
              color:
                  primaryTeal,
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          // ======================================================
          // SCORE BOXES
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                    _buildScoreBox(
                  label:
                      'Score',
                  value:
                      '$score / $totalPoints',
                  icon:
                      Icons.stars_rounded,
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Expanded(
                child:
                    _buildScoreBox(
                  label:
                      'Percentage',
                  value:
                      '${percentage.toStringAsFixed(0)}%',
                  icon:
                      Icons.percent_rounded,
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              Expanded(
                child:
                    _buildScoreBox(
                  label:
                      'Pass Mark',
                  value:
                      '$passingScore',
                  icon:
                      Icons.flag_outlined,
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
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF7F9FC,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                primaryTeal,
            size:
                17,
          ),

          const SizedBox(
            height:
                6,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color:
                  textGrey,
              fontSize:
                  9.5,
            ),
          ),

          const SizedBox(
            height:
                2,
          ),

          Text(
            value,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  textDark,
              fontSize:
                  14,
              fontWeight:
                  FontWeight.w800,
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
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        32,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
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
        children: [
          Icon(
            icon,
            color:
                color,
            size:
                46,
          ),

          const SizedBox(
            height:
                12,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  textDark,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
                5,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  textGrey,
              fontSize:
                  12,
              height:
                  1.4,
            ),
          ),

          if (showRetry) ...[
            const SizedBox(
              height:
                  14,
            ),

            TextButton.icon(
              onPressed:
                  _loadResults,
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
        ],
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(
    DateTime date,
  ) {
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

    final int hour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final String minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year} • '
        '$hour:$minute $period';
  }
}