import 'package:flutter/material.dart';

import '../../services/assignment_service.dart';
import '../../services/course_service.dart';
import '../../services/quiz_service.dart';

import 'assignment_details_page.dart';
import 'general_quiz_page.dart';
import 'module_content_page.dart';

class SubjectOverviewScreen extends StatefulWidget {
  final String courseId;
  final String subjectCode;
  final String section;
  final String title;
  final String instructor;

  const SubjectOverviewScreen({
    super.key,
    this.courseId = '',
    this.subjectCode = 'IT301',
    this.section = '',
    this.title = 'Mobile Development',
    this.instructor = 'Instructor',
  });

  @override
  State<SubjectOverviewScreen> createState() =>
      _SubjectOverviewScreenState();
}

class _SubjectOverviewScreenState
    extends State<SubjectOverviewScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color green =
      Color(0xFF26A65B);

  // ============================================================
  // SERVICES
  // ============================================================

  final CourseService _courseService =
      CourseService();

  final AssignmentService _assignmentService =
      AssignmentService();

  final QuizService _quizService =
      QuizService();

  // ============================================================
  // TAB
  // ============================================================

  int _selectedTabIndex = 0;

  // ============================================================
  // MODULE STATE
  // ============================================================

  List<Map<String, dynamic>> _modules = [];

  bool _isLoadingModules = true;

  String? _moduleError;

  // ============================================================
  // TASK STATE
  // ============================================================

  List<Map<String, dynamic>> _assignments = [];

  List<Map<String, dynamic>> _quizzes = [];

  bool _isLoadingTasks = true;

  String? _taskError;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadModules();
    _loadTasks();
  }

  // ============================================================
  // LOAD MODULES
  // ============================================================

  Future<void> _loadModules() async {
    if (widget.courseId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoadingModules = false;
        _moduleError =
            'Course information is missing.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingModules = true;
        _moduleError = null;
      });
    }

    try {
      final List<Map<String, dynamic>> modules =
          await _courseService.getCourseModules(
        widget.courseId,
      );

      if (!mounted) return;

      setState(() {
        _modules = modules;
        _isLoadingModules = false;
        _moduleError = null;
      });
    } on CourseServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingModules = false;
        _moduleError = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingModules = false;
        _moduleError =
            'Unable to load course modules.';
      });
    }
  }

  // ============================================================
  // LOAD ASSIGNMENTS + QUIZZES
  // ============================================================

  Future<void> _loadTasks() async {
    if (widget.courseId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoadingTasks = false;
        _taskError =
            'Course information is missing.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingTasks = true;
        _taskError = null;
      });
    }

    try {
      final List<Map<String, dynamic>> assignments =
          await _assignmentService
              .getCourseAssignments(
        widget.courseId,
      );

      final List<Map<String, dynamic>> quizzes =
          await _quizService.getCourseQuizzes(
        widget.courseId,
      );

      // Student should only see published assignments.
      final List<Map<String, dynamic>>
          publishedAssignments =
          assignments.where(
        (assignment) {
          return (assignment['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              'published';
        },
      ).toList();

      if (!mounted) return;

      setState(() {
        _assignments =
            publishedAssignments;

        _quizzes =
            quizzes;

        _isLoadingTasks = false;
        _taskError = null;
      });
    } on AssignmentServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingTasks = false;
        _taskError = e.message;
      });
    } on QuizServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingTasks = false;
        _taskError = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingTasks = false;
        _taskError =
            'Unable to load course tasks.';
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,

      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    28,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons
                                .arrow_back_ios_new_rounded,
                            color:
                                Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withValues(
                            alpha: 0.18,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .laptop_chromebook_rounded,
                          color:
                              Colors.white,
                          size: 40,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Text(
                        widget.section.trim().isEmpty
                            ? widget.subjectCode
                            : '${widget.subjectCode} • ${widget.section}',
                        style: const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
                          letterSpacing:
                              0.4,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        widget.title,
                        textAlign:
                            TextAlign.center,
                        style: const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 26,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing:
                              -0.5,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'Instructor: ${widget.instructor}',
                        style: TextStyle(
                          color:
                              Colors.white.withValues(
                            alpha: 0.82,
                          ),
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // WHITE BODY
                // ==================================================

                Expanded(
                  child: Container(
                    width:
                        double.infinity,
                    decoration:
                        const BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius.only(
                        topLeft:
                            Radius.circular(
                          32,
                        ),
                        topRight:
                            Radius.circular(
                          32,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          height: 20,
                        ),

                        // ==========================================
                        // TABS
                        // ==========================================

                        SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal,
                          physics:
                              const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          child: Row(
                            children: [
                              _buildTab(
                                'Lessons',
                                0,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              _buildTab(
                                'Tasks',
                                1,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              _buildTab(
                                'Resources',
                                2,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              _buildTab(
                                'Grades',
                                3,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Expanded(
                          child:
                              _buildSelectedTabContent(),
                        ),
                      ],
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

  // ============================================================
  // TAB BUTTON
  // ============================================================

  Widget _buildTab(
    String title,
    int index,
  ) {
    final bool isActive =
        _selectedTabIndex ==
            index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex =
              index;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        decoration:
            BoxDecoration(
          color: isActive
              ? primaryBlue.withValues(
                  alpha: 0.10,
                )
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
        child: Text(
          title,
          style:
              TextStyle(
            color: isActive
                ? primaryBlue
                : textGrey,
            fontWeight: isActive
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB ROUTER
  // ============================================================

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildLessonsTab();

      case 1:
        return _buildTasksTab();

      case 2:
        return const Center(
          child: Text(
            'Resources will be connected later.',
            style: TextStyle(
              color: textGrey,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        );

      case 3:
        return const Center(
          child: Text(
            'Grades will be connected later.',
            style: TextStyle(
              color: textGrey,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        );

      default:
        return _buildLessonsTab();
    }
  }

  // ============================================================
  // LESSONS
  // ============================================================

  Widget _buildLessonsTab() {
    if (_isLoadingModules) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              primaryBlue,
        ),
      );
    }

    if (_moduleError != null) {
      return _buildErrorState(
        message:
            _moduleError!,
        onRetry:
            _loadModules,
      );
    }

    if (_modules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .menu_book_outlined,
              color:
                  primaryBlue,
              size: 48,
            ),

            SizedBox(
              height: 12,
            ),

            Text(
              'No modules available',
              style: TextStyle(
                color: textDark,
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryBlue,
      onRefresh:
          _loadModules,
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        padding:
            const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          30,
        ),
        itemCount:
            _modules.length,
        itemBuilder:
            (
          context,
          index,
        ) {
          final Map<String, dynamic> module =
              _modules[index];

          return _buildModuleCard(
            module,
          );
        },
      ),
    );
  }

  // ============================================================
  // MODULE CARD
  // ============================================================

  Widget _buildModuleCard(
    Map<String, dynamic> module,
  ) {
    final String title =
        (module['title'] ??
                'Untitled Module')
            .toString();

    final String description =
        (module['description'] ?? '')
            .toString();

    final int order =
        module['order'] is num
            ? (module['order']
                    as num)
                .toInt()
            : 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (
              context,
            ) =>
                ModuleContentScreen(
              title:
                  title,
              moduleName:
                  order > 0
                      ? 'Module $order'
                      : 'Module',
            ),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius
                  .circular(
            16,
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
                  Colors.black
                      .withValues(
                alpha:
                    0.02,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(
                0,
                4,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    primaryBlue
                        .withValues(
                  alpha:
                      0.10,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child: const Icon(
                Icons
                    .menu_book_rounded,
                color:
                    primaryBlue,
                size:
                    24,
              ),
            ),

            const SizedBox(
              width: 16,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  if (order > 0) ...[
                    Text(
                      'MODULE $order',
                      style:
                          const TextStyle(
                        color:
                            primaryBlue,
                        fontSize:
                            9.5,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            0.7,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),
                  ],

                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          textDark,
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  if (description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      description,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
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
                  ],
                ],
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  Color(
                0xFF9BA4B4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TASKS
  // ============================================================

  Widget _buildTasksTab() {
    if (_isLoadingTasks) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              primaryBlue,
        ),
      );
    }

    if (_taskError != null) {
      return _buildErrorState(
        message:
            _taskError!,
        onRetry:
            _loadTasks,
      );
    }

    if (_assignments.isEmpty &&
        _quizzes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .task_alt_rounded,
              size: 48,
              color:
                  primaryBlue,
            ),

            SizedBox(
              height: 12,
            ),

            Text(
              'No tasks available',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
                color:
                    textDark,
              ),
            ),

            SizedBox(
              height: 5,
            ),

            Text(
              'Assignments and quizzes will appear here.',
              style: TextStyle(
                color:
                    textGrey,
                fontSize:
                    12,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color:
          primaryBlue,
      onRefresh:
          _loadTasks,
      child:
          ListView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal:
              24,
          vertical:
              12,
        ),
        children: [
          // ======================================================
          // ASSIGNMENTS
          // ======================================================

          const Text(
            'Assignments',
            style: TextStyle(
              fontSize:
                  16,
              fontWeight:
                  FontWeight
                      .w800,
              color:
                  textDark,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          if (_assignments.isEmpty)
            const Text(
              'No assignments.',
              style: TextStyle(
                color:
                    textGrey,
              ),
            )
          else
            ..._assignments.map(
              (
                assignment,
              ) {
                final String assignmentId =
                    (assignment['id'] ??
                            '')
                        .toString();

                final String title =
                    (assignment['title'] ??
                            'Assignment')
                        .toString();

                final int points =
                    assignment['points']
                            is num
                        ? (assignment[
                                    'points']
                                as num)
                            .toInt()
                        : 0;

                return _buildTaskCard(
                  title:
                      title,
                  subtitle:
                      '$points points • Assignment',
                  icon:
                      Icons.assignment_outlined,
                  iconColor:
                      Colors.orange,
                  iconBg:
                      Colors.orange.withValues(
                    alpha:
                        0.10,
                  ),
                  onTap:
                      () async {
                    if (assignmentId
                        .isEmpty) {
                      return;
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (
                          context,
                        ) =>
                                AssignmentDetailsScreen(
                          assignmentId:
                              assignmentId,
                        ),
                      ),
                    );

                    if (!mounted) return;

                    await _loadTasks();
                  },
                );
              },
            ),

          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical:
                  18,
            ),
            child:
                Divider(
              height:
                  1,
              color:
                  Color(
                0xFFF0F2F5,
              ),
            ),
          ),

          // ======================================================
          // QUIZZES
          // ======================================================

          const Text(
            'Quizzes',
            style: TextStyle(
              fontSize:
                  16,
              fontWeight:
                  FontWeight
                      .w800,
              color:
                  textDark,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          if (_quizzes.isEmpty)
            const Text(
              'No quizzes.',
              style: TextStyle(
                color:
                    textGrey,
              ),
            )
          else
            ..._quizzes.map(
              (
                quiz,
              ) {
                final String quizId =
                    (quiz['id'] ??
                            '')
                        .toString();

                final String title =
                    (quiz['title'] ??
                            'Quiz')
                        .toString();

                final int totalPoints =
                    quiz['totalPoints']
                            is num
                        ? (quiz[
                                    'totalPoints']
                                as num)
                            .toInt()
                        : 0;

                final int timeLimit =
                    quiz['timeLimit']
                            is num
                        ? (quiz[
                                    'timeLimit']
                                as num)
                            .toInt()
                        : 0;

                final String subtitle =
                    timeLimit > 0
                        ? '$totalPoints points • $timeLimit min'
                        : '$totalPoints points • Online Quiz';

                return _buildTaskCard(
                  title:
                      title,
                  subtitle:
                      subtitle,
                  icon:
                      Icons.quiz_rounded,
                  iconColor:
                      primaryBlue,
                  iconBg:
                      primaryBlue.withValues(
                    alpha:
                        0.10,
                  ),
                  onTap:
                      () async {
                    if (quizId.isEmpty) {
                      return;
                    }

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (
                          context,
                        ) =>
                                GeneralQuizScreen(
                          quizId:
                              quizId,
                          quizTitle:
                              title,
                        ),
                      ),
                    );

                    if (!mounted) return;

                    await _loadTasks();
                  },
                );
              },
            ),

          const SizedBox(
            height:
                30,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TASK CARD
  // ============================================================

  Widget _buildTaskCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap,
      child:
          Container(
        margin:
            const EdgeInsets
                .only(
          bottom:
              12,
        ),
        padding:
            const EdgeInsets
                .all(
          16,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius
                  .circular(
            16,
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
                  Colors.black
                      .withValues(
                alpha:
                    0.015,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(
                0,
                4,
              ),
            ),
          ],
        ),
        child:
            Row(
          children: [
            Container(
              padding:
                  const EdgeInsets
                      .all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    iconBg,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child:
                  Icon(
                icon,
                color:
                    iconColor,
                size:
                    24,
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
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w800,
                      fontSize:
                          15,
                      color:
                          textDark,
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
                          12,
                      fontWeight:
                          FontWeight
                              .w500,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  Color(
                0xFF9BA4B4,
              ),
              size:
                  20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          24,
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
                  42,
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    textGrey,
                fontWeight:
                    FontWeight
                        .w600,
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            TextButton.icon(
              onPressed:
                  onRetry,
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
}