import 'package:flutter/material.dart';

import '../../services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
  });

  @override
  State<ProgressScreen> createState() =>
      _ProgressScreenState();
}

class _ProgressScreenState
    extends State<ProgressScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color green =
      Color(0xFF26A65B);

  static const Color orange =
      Color(0xFFFF9418);

  static const Color purple =
      Color(0xFF7B4DFF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color borderColor =
      Color(0xFFE6EAF0);

  // ============================================================
  // SERVICE
  // ============================================================

  final ProgressService _progressService =
      ProgressService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading =
      true;

  String? _errorMessage;

  Map<String, dynamic> _learning =
      {};

  Map<String, dynamic> _academic =
      {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>>
          results =
          await Future.wait([
        _progressService
            .getOverallLearningProgress(),

        _progressService
            .getOverallAcademicPerformance(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _learning =
            results[0];

        _academic =
            results[1];

        _isLoading =
            false;
      });
    } on ProgressServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage =
            'Unable to load your progress.';
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _learningInt(
    String key,
  ) {
    return (_learning[key] as num?)
            ?.toInt() ??
        0;
  }

  double _learningDouble(
    String key,
  ) {
    return ((_learning[key] as num?)
                ?.toDouble() ??
            0.0)
        .clamp(
          0.0,
          1.0,
        )
        .toDouble();
  }

  int _academicInt(
    String key,
  ) {
    return (_academic[key] as num?)
            ?.toInt() ??
        0;
  }

  double _academicDouble(
    String key,
  ) {
    return ((_academic[key] as num?)
                ?.toDouble() ??
            0.0)
        .clamp(
          0.0,
          1.0,
        )
        .toDouble();
  }

  bool get _hasGrades =>
      _academic['hasGrades'] ==
      true;

  List<Map<String, dynamic>>
      get _academicCourses {
    final dynamic raw =
        _academic['courses'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<
            Map<String, dynamic>>()
        .toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          AppBar(
        automaticallyImplyLeading:
            false,

        backgroundColor:
            background,

        elevation:
            0,

        centerTitle:
            true,

        title:
            const Text(
          'My Progress',

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

            onPressed:
                _isLoading
                    ? null
                    : _loadData,

            icon:
                const Icon(
              Icons.refresh_rounded,

              color:
                  textDark,
            ),
          ),

          const SizedBox(
            width:
                8,
          ),
        ],
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
                  1200,
            ),

            child:
                _buildBody(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
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
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh:
          _loadData,

      color:
          primaryBlue,

      child:
          SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),

        padding:
            const EdgeInsets.fromLTRB(
          24,
          10,
          24,
          40,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ====================================================
            // LEARNING PROGRESS
            // ====================================================

            _buildLearningCard(),

            const SizedBox(
              height:
                  26,
            ),

            _sectionTitle(
              'Learning Completion',
              'Modules, assignments, and quizzes completed',
            ),

            const SizedBox(
              height:
                  14,
            ),

            _buildLearningComponents(),

            const SizedBox(
              height:
                  30,
            ),

            // ====================================================
            // ACADEMIC PERFORMANCE
            // ====================================================

            _sectionTitle(
              'Academic Performance',
              'Based only on graded assignments and submitted quizzes',
            ),

            const SizedBox(
              height:
                  14,
            ),

            _buildAcademicCard(),

            if (_hasGrades) ...[
              const SizedBox(
                height:
                    14,
              ),

              _buildPerformanceBreakdown(),

              const SizedBox(
                height:
                    30,
              ),

              _sectionTitle(
                'Course Performance',
                'Performance based on assessed points in each course',
              ),

              const SizedBox(
                height:
                    14,
              ),

              if (_academicCourses
                  .isEmpty)
                _buildEmptyState(
                  'No course grades available.',
                )
              else
                ..._academicCourses.map(
                  _buildCoursePerformanceCard,
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LEARNING CARD
  // ============================================================

  Widget _buildLearningCard() {
    final double progress =
        _learningDouble(
      'learningProgress',
    );

    final int percentage =
        (progress * 100)
            .round();

    final int completed =
        _learningInt(
      'completedItems',
    );

    final int total =
        _learningInt(
      'totalItems',
    );

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        22,
      ),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(
              0xFF1769FF,
            ),
            Color(
              0xFF4387FF,
            ),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),

      child:
          Row(
        children: [
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'OVERALL LEARNING PROGRESS',

                  style:
                      TextStyle(
                    color:
                        Colors.white70,

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.w800,

                    letterSpacing:
                        1,
                  ),
                ),

                const SizedBox(
                  height:
                      12,
                ),

                Text(
                  '$percentage%',

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        40,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      6,
                ),

                Text(
                  total == 0
                      ? 'No published learning activities yet.'
                      : '$completed of $total activities completed',

                  style:
                      const TextStyle(
                    color:
                        Colors.white70,

                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width:
                85,

            height:
                85,

            child:
                CircularProgressIndicator(
              value:
                  progress,

              strokeWidth:
                  8,

              backgroundColor:
                  Colors.white
                      .withValues(
                alpha:
                    0.18,
              ),

              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LEARNING COMPONENTS
  // ============================================================

  Widget _buildLearningComponents() {
    return Column(
      children: [
        _buildProgressRow(
          title:
              'Modules',

          value:
              '${_learningInt('completedModules')} / ${_learningInt('totalModules')}',

          progress:
              _learningDouble(
            'moduleProgress',
          ),

          icon:
              Icons.menu_book_rounded,

          color:
              primaryBlue,
        ),

        const SizedBox(
          height:
              12,
        ),

        _buildProgressRow(
          title:
              'Assignments',

          value:
              '${_learningInt('submittedAssignments')} / ${_learningInt('totalAssignments')}',

          progress:
              _learningDouble(
            'assignmentProgress',
          ),

          icon:
              Icons
                  .assignment_turned_in_rounded,

          color:
              orange,
        ),

        const SizedBox(
          height:
              12,
        ),

        _buildProgressRow(
          title:
              'Quizzes',

          value:
              '${_learningInt('completedQuizzes')} / ${_learningInt('totalQuizzes')}',

          progress:
              _learningDouble(
            'quizProgress',
          ),

          icon:
              Icons.quiz_rounded,

          color:
              purple,
        ),
      ],
    );
  }

  // ============================================================
  // ACADEMIC CARD
  // ============================================================

  Widget _buildAcademicCard() {
    if (!_hasGrades) {
      return Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(
          22,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border:
              Border.all(
            color:
                borderColor,
          ),
        ),

        child:
            const Column(
          children: [
            Icon(
              Icons
                  .analytics_outlined,

              color:
                  purple,

              size:
                  45,
            ),

            SizedBox(
              height:
                  10,
            ),

            Text(
              'No graded performance yet',

              style:
                  TextStyle(
                color:
                    textDark,

                fontSize:
                    15,

                fontWeight:
                    FontWeight.w800,
              ),
            ),

            SizedBox(
              height:
                  5,
            ),

            Text(
              'Academic performance will appear after assignments are graded or quizzes are submitted.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    textGrey,

                fontSize:
                    11,
              ),
            ),
          ],
        ),
      );
    }

    final double performance =
        _academicDouble(
      'percentage',
    );

    final int percentage =
        (performance * 100)
            .round();

    final int earned =
        _academicInt(
      'earnedPoints',
    );

    final int available =
        _academicInt(
      'availablePoints',
    );

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        22,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              borderColor,
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width:
                62,

            height:
                62,

            decoration:
                BoxDecoration(
              color:
                  purple.withValues(
                alpha:
                    0.10,
              ),

              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            child:
                const Icon(
              Icons
                  .analytics_rounded,

              color:
                  purple,

              size:
                  30,
            ),
          ),

          const SizedBox(
            width:
                16,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Academic Performance',

                  style:
                      TextStyle(
                    color:
                        textDark,

                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Text(
                  '$earned / $available assessed points',

                  style:
                      const TextStyle(
                    color:
                        textGrey,

                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '$percentage%',

            style:
                const TextStyle(
              color:
                  purple,

              fontSize:
                  26,

              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERFORMANCE BREAKDOWN
  // ============================================================

  Widget _buildPerformanceBreakdown() {
    return Column(
      children: [
        _buildPerformanceCard(
          title:
              'Assignment Performance',

          earned:
              _academicInt(
            'assignmentEarnedPoints',
          ),

          available:
              _academicInt(
            'assignmentAvailablePoints',
          ),

          progress:
              _academicDouble(
            'assignmentPercentage',
          ),

          icon:
              Icons.assignment_rounded,

          color:
              orange,
        ),

        const SizedBox(
          height:
              12,
        ),

        _buildPerformanceCard(
          title:
              'Quiz Performance',

          earned:
              _academicInt(
            'quizEarnedPoints',
          ),

          available:
              _academicInt(
            'quizAvailablePoints',
          ),

          progress:
              _academicDouble(
            'quizPercentage',
          ),

          icon:
              Icons.quiz_rounded,

          color:
              purple,
        ),
      ],
    );
  }

  Widget _buildPerformanceCard({
    required String title,
    required int earned,
    required int available,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    final int percentage =
        (progress * 100)
            .round();

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
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
              borderColor,
        ),
      ),

      child:
          Column(
        children: [
          Row(
            children: [
              Container(
                width:
                    42,

                height:
                    42,

                decoration:
                    BoxDecoration(
                  color:
                      color.withValues(
                    alpha:
                        0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  color:
                      color,
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
                      title,

                      style:
                          const TextStyle(
                        color:
                            textDark,

                        fontSize:
                            13,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      available == 0
                          ? 'No assessed points yet'
                          : '$earned of $available points',

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

              Text(
                available == 0
                    ? '—'
                    : '$percentage%',

                style:
                    TextStyle(
                  color:
                      color,

                  fontSize:
                      16,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                13,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),

            child:
                LinearProgressIndicator(
              value:
                  available == 0
                      ? 0
                      : progress,

              minHeight:
                  6,

              backgroundColor:
                  const Color(
                0xFFECEFF4,
              ),

              valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COURSE PERFORMANCE
  // ============================================================

  Widget _buildCoursePerformanceCard(
    Map<String, dynamic> course,
  ) {
    final String code =
        (course['code'] ?? '')
            .toString();

    final String title =
        (course['title'] ??
                'Course')
            .toString();

    final bool hasGrades =
        course['hasGrades'] ==
            true;

    final int earned =
        (course['academicEarnedPoints']
                    as num?)
                ?.toInt() ??
            0;

    final int available =
        (course['academicAvailablePoints']
                    as num?)
                ?.toInt() ??
            0;

    final double performance =
        ((course['academicPerformance']
                    as num?)
                ?.toDouble() ??
            0.0)
            .clamp(
              0.0,
              1.0,
            )
            .toDouble();

    final int percentage =
        (performance * 100)
            .round();

    return Container(
      width:
          double.infinity,

      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),

      padding:
          const EdgeInsets.all(
        17,
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
              borderColor,
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width:
                    44,

                height:
                    44,

                decoration:
                    BoxDecoration(
                  color:
                      primaryBlue
                          .withValues(
                    alpha:
                        0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons.school_rounded,

                  color:
                      primaryBlue,
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
                      code.isEmpty
                          ? title
                          : '$code • $title',

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        color:
                            textDark,

                        fontSize:
                            13.5,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      hasGrades
                          ? '$earned of $available assessed points'
                          : 'No graded assessments yet',

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

              Text(
                hasGrades
                    ? '$percentage%'
                    : '—',

                style:
                    TextStyle(
                  color:
                      hasGrades
                          ? purple
                          : textGrey,

                  fontSize:
                      17,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          if (hasGrades) ...[
            const SizedBox(
              height:
                  13,
            ),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),

              child:
                  LinearProgressIndicator(
                value:
                    performance,

                minHeight:
                    6,

                backgroundColor:
                    const Color(
                  0xFFECEFF4,
                ),

                valueColor:
                    const AlwaysStoppedAnimation<
                        Color>(
                  purple,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // COMMON PROGRESS ROW
  // ============================================================

  Widget _buildProgressRow({
    required String title,
    required String value,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    final int percentage =
        (progress * 100)
            .round();

    return Container(
      padding:
          const EdgeInsets.all(
        17,
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
              borderColor,
        ),
      ),

      child:
          Column(
        children: [
          Row(
            children: [
              Container(
                width:
                    42,

                height:
                    42,

                decoration:
                    BoxDecoration(
                  color:
                      color.withValues(
                    alpha:
                        0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  color:
                      color,
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
                      title,

                      style:
                          const TextStyle(
                        color:
                            textDark,

                        fontSize:
                            13,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    Text(
                      value,

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

              Text(
                '$percentage%',

                style:
                    TextStyle(
                  color:
                      color,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                13,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),

            child:
                LinearProgressIndicator(
              value:
                  progress,

              minHeight:
                  6,

              backgroundColor:
                  const Color(
                0xFFECEFF4,
              ),

              valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style:
              const TextStyle(
            color:
                textDark,

            fontSize:
                18,

            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(
          height:
              4,
        ),

        Text(
          subtitle,

          style:
              const TextStyle(
            color:
                textGrey,

            fontSize:
                11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState(
    String message,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        25,
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
              borderColor,
        ),
      ),

      child:
          Text(
        message,

        textAlign:
            TextAlign.center,

        style:
            const TextStyle(
          color:
              textGrey,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
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
                  50,
            ),

            const SizedBox(
              height:
                  12,
            ),

            Text(
              _errorMessage ??
                  'Unable to load progress.',

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
                  14,
            ),

            ElevatedButton.icon(
              onPressed:
                  _loadData,

              icon:
                  const Icon(
                Icons.refresh_rounded,

                color:
                    Colors.white,
              ),

              label:
                  const Text(
                'Try Again',

                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryBlue,

                elevation:
                    0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}