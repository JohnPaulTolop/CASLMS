import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'student_module_detail_page.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({
    super.key,
  });

  @override
  State<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState
    extends State<StudentAssignmentsScreen> {
  // ============================================================
  // DESIGN
  // ============================================================

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color orange = Color(0xFFFF9418);
  static const Color green = Color(0xFF26A65B);
  static const Color red = Color(0xFFFF4B4B);
  static const Color purple = Color(0xFF7B4DFF);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  int _selectedTab = 0;

  bool _isLoading = true;

  String? _errorMessage;

  DateTime? _selectedDate;

  List<Map<String, dynamic>> _tasks = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadTasks();
  }

  // ============================================================
  // LOAD REAL TASKS
  // ============================================================

  Future<void> _loadTasks() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String? studentId =
          _auth.currentUser?.uid;

      if (studentId == null ||
          studentId.isEmpty) {
        throw Exception(
          'You must be logged in to view your tasks.',
        );
      }

      // ========================================================
      // VERIFY STUDENT
      // ========================================================

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await _firestore
              .collection('users')
              .doc(studentId)
              .get();

      if (!userDocument.exists ||
          userDocument.data() == null) {
        throw Exception(
          'Student profile could not be found.',
        );
      }

      final Map<String, dynamic> userData =
          userDocument.data()!;

      final String role =
          (userData['role'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (role != 'student') {
        throw Exception(
          'Only students can access My Tasks.',
        );
      }

      final String userStatus =
          (userData['status'] ?? 'active')
              .toString()
              .trim()
              .toLowerCase();

      if (userStatus != 'active') {
        throw Exception(
          'Your student account is not active.',
        );
      }

      // ========================================================
      // ACTIVE ENROLLMENTS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>>
          enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where(
                'studentId',
                isEqualTo: studentId,
              )
              .get();

      final List<Map<String, dynamic>>
          activeEnrollments = [];

      for (final document
          in enrollmentSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (status != 'active') {
          continue;
        }

        activeEnrollments.add({
          ...data,
          'id': document.id,
        });
      }

      // ========================================================
      // CURRENT STUDENT ASSESSMENT SUBMISSIONS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>>
          submissionSnapshot =
          await _firestore
              .collection(
                'assessmentSubmissions',
              )
              .where(
                'studentId',
                isEqualTo: studentId,
              )
              .get();

      final Map<String, Map<String, dynamic>>
          submissionByAssessment = {};

      for (final document
          in submissionSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String assessmentId =
            (data['assessmentId'] ?? '')
                .toString()
                .trim();

        if (assessmentId.isEmpty) {
          continue;
        }

        submissionByAssessment[assessmentId] = {
          ...data,
          'id': document.id,
          'submissionId': document.id,
        };
      }

      // ========================================================
      // BUILD TASK LIST FROM ENROLLED COURSES
      // ========================================================

      final List<Map<String, dynamic>>
          loadedTasks = [];

      for (final enrollment
          in activeEnrollments) {
        final String courseId =
            (enrollment['courseId'] ?? '')
                .toString()
                .trim();

        if (courseId.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // COURSE
        // --------------------------------------------------------

        final DocumentSnapshot<Map<String, dynamic>>
            courseDocument =
            await _firestore
                .collection('courses')
                .doc(courseId)
                .get();

        if (!courseDocument.exists ||
            courseDocument.data() == null) {
          continue;
        }

        final Map<String, dynamic> course =
            courseDocument.data()!;

        final String courseStatus =
            (course['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        if (courseStatus != 'active') {
          continue;
        }

        // --------------------------------------------------------
        // PUBLISHED MODULES
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>>
            moduleSnapshot =
            await _firestore
                .collection('modules')
                .where(
                  'courseId',
                  isEqualTo: courseId,
                )
                .get();

        final Map<String, Map<String, dynamic>>
            publishedModules = {};

        for (final moduleDocument
            in moduleSnapshot.docs) {
          final Map<String, dynamic> module =
              moduleDocument.data();

          final String status =
              (module['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          if (status != 'published') {
            continue;
          }

          publishedModules[moduleDocument.id] = {
            ...module,
            'id': moduleDocument.id,
            'moduleId': moduleDocument.id,
          };
        }

        if (publishedModules.isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // ASSESSMENTS
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>>
            assessmentSnapshot =
            await _firestore
                .collection('assessments')
                .where(
                  'courseId',
                  isEqualTo: courseId,
                )
                .get();

        for (final assessmentDocument
            in assessmentSnapshot.docs) {
          final Map<String, dynamic> assessment =
              assessmentDocument.data();

          final String assessmentId =
              assessmentDocument.id;

          final String moduleId =
              (assessment['moduleId'] ?? '')
                  .toString()
                  .trim();

          final String status =
              (assessment['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          // Students must never see drafts.
          if (status == 'draft') {
            continue;
          }

          // Only assessments attached to a published module.
          if (!publishedModules.containsKey(
            moduleId,
          )) {
            continue;
          }

          final Map<String, dynamic>? submission =
              submissionByAssessment[
                  assessmentId];

          final String submissionStatus =
              (submission?['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          // A closed assessment with no existing submission
          // does not need to remain in the student's active
          // global task list.
          if (status == 'closed' &&
              submission == null) {
            continue;
          }

          loadedTasks.add({
            ...assessment,

            'id': assessmentId,
            'assessmentId':
                assessmentId,

            'courseId': courseId,

            'courseCode':
                (course['code'] ?? '')
                    .toString(),

            'courseTitle':
                (course['title'] ?? '')
                    .toString(),

            'classCode':
                (course['classCode'] ?? '')
                    .toString(),

            'moduleId': moduleId,

            'moduleTitle':
                (publishedModules[moduleId]
                            ?['title'] ??
                        '')
                    .toString(),

            'submission':
                submission,

            'submissionStatus':
                submissionStatus,
          });
        }
      }

      // ========================================================
      // SORT BY DUE DATE
      // ========================================================

      loadedTasks.sort(
        (a, b) {
          final DateTime? aDue =
              _dateFrom(
            a['dueAt'],
          );

          final DateTime? bDue =
              _dateFrom(
            b['dueAt'],
          );

          if (aDue == null &&
              bDue == null) {
            return 0;
          }

          if (aDue == null) {
            return 1;
          }

          if (bDue == null) {
            return -1;
          }

          return aDue.compareTo(
            bDue,
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _tasks = loadedTasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _todoCount {
    return _tasks.where(
      (task) {
        final String status =
            (task['submissionStatus'] ?? '')
                .toString()
                .toLowerCase();

        final String assessmentStatus =
            (task['status'] ?? '')
                .toString()
                .toLowerCase();

        return status.isEmpty &&
            assessmentStatus == 'published';
      },
    ).length;
  }

  int get _submittedCount {
    return _tasks.where(
      (task) {
        return (task['submissionStatus'] ?? '')
                .toString()
                .toLowerCase() ==
            'submitted';
      },
    ).length;
  }

  int get _completedCount {
    return _tasks.where(
      (task) {
        return (task['submissionStatus'] ?? '')
                .toString()
                .toLowerCase() ==
            'graded';
      },
    ).length;
  }

  // ============================================================
  // FILTERED TASKS
  // ============================================================

  List<Map<String, dynamic>>
      get _visibleTasks {
    Iterable<Map<String, dynamic>>
        result = _tasks;

    if (_selectedTab == 0) {
      result = result.where(
        (task) {
          final String submissionStatus =
              (task['submissionStatus'] ?? '')
                  .toString()
                  .toLowerCase();

          final String assessmentStatus =
              (task['status'] ?? '')
                  .toString()
                  .toLowerCase();

          return submissionStatus.isEmpty &&
              assessmentStatus ==
                  'published';
        },
      );
    } else if (_selectedTab == 1) {
      result = result.where(
        (task) {
          return (task['submissionStatus'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'submitted';
        },
      );
    } else {
      result = result.where(
        (task) {
          return (task['submissionStatus'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'graded';
        },
      );
    }

    if (_selectedDate != null) {
      result = result.where(
        (task) {
          final DateTime? dueAt =
              _dateFrom(
            task['dueAt'],
          );

          if (dueAt == null) {
            return false;
          }

          final DateTime local =
              dueAt.toLocal();

          return local.year ==
                  _selectedDate!.year &&
              local.month ==
                  _selectedDate!.month &&
              local.day ==
                  _selectedDate!.day;
        },
      );
    }

    return result.toList();
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  Future<void> _openCalendar() async {
    final DateTime now =
        DateTime.now();

    final DateTime? selected =
        await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? now,
      firstDate:
          DateTime(
        now.year - 2,
      ),
      lastDate:
          DateTime(
        now.year + 5,
        12,
        31,
      ),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data:
              Theme.of(context)
                  .copyWith(
            colorScheme:
                const ColorScheme.light(
              primary:
                  primaryBlue,
              onPrimary:
                  Colors.white,
              onSurface:
                  textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _selectedDate =
          selected;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  // ============================================================
  // OPEN MODULE
  // ============================================================

  Future<void> _openTask(
    Map<String, dynamic> task,
  ) async {
    final String courseId =
        (task['courseId'] ?? '')
            .toString()
            .trim();

    final String moduleId =
        (task['moduleId'] ?? '')
            .toString()
            .trim();

    if (courseId.isEmpty ||
        moduleId.isEmpty) {
      _showError(
        'Course or module information is missing.',
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentModuleDetailScreen(
          courseId: courseId,
          courseCode:
              (task['courseCode'] ?? '')
                  .toString(),
          courseTitle:
              (task['courseTitle'] ?? '')
                  .toString(),
          moduleId: moduleId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadTasks();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _dateFrom(
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
    dynamic value,
  ) {
    final DateTime? date =
        _dateFrom(value);

    if (date == null) {
      return 'No due date';
    }

    final DateTime local =
        date.toLocal();

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

    final String period =
        hour >= 12
            ? 'PM'
            : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final String minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${months[local.month - 1]} '
        '${local.day}, ${local.year} • '
        '$hour:$minute $period';
  }

  String _formatShortDate(
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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  bool _isPastDue(
    Map<String, dynamic> task,
  ) {
    final DateTime? dueAt =
        _dateFrom(
      task['dueAt'],
    );

    if (dueAt == null) {
      return false;
    }

    return DateTime.now()
        .isAfter(
      dueAt,
    );
  }

  bool _isDueToday(
    Map<String, dynamic> task,
  ) {
    final DateTime? dueAt =
        _dateFrom(
      task['dueAt'],
    );

    if (dueAt == null) {
      return false;
    }

    final DateTime now =
        DateTime.now();

    final DateTime local =
        dueAt.toLocal();

    return now.year ==
            local.year &&
        now.month ==
            local.month &&
        now.day ==
            local.day;
  }

  // ============================================================
  // ASSESSMENT UI HELPERS
  // ============================================================

  IconData _assessmentIcon(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return Icons.quiz_outlined;

      case 'activity':
        return Icons.task_alt_outlined;

      case 'assignment':
        return Icons.assignment_outlined;

      case 'exam':
        return Icons.fact_check_outlined;

      default:
        return Icons.description_outlined;
    }
  }

  Color _assessmentColor(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return primaryBlue;

      case 'activity':
        return orange;

      case 'assignment':
        return purple;

      case 'exam':
        return red;

      default:
        return primaryBlue;
    }
  }

  String _capitalize(
    String value,
  ) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }

  // ============================================================
  // BADGE
  // ============================================================

  ({
    String text,
    Color color,
  }) _badgeFor(
    Map<String, dynamic> task,
  ) {
    final String submissionStatus =
        (task['submissionStatus'] ?? '')
            .toString()
            .toLowerCase();

    if (submissionStatus ==
        'graded') {
      final Map<String, dynamic>?
          submission =
          task['submission']
              as Map<String, dynamic>?;

      final dynamic score =
          submission?['score'];

      final num totalPoints =
          (task['totalPoints'] as num?) ??
              0;

      if (score is num) {
        return (
          text:
              '$score / $totalPoints',
          color: green,
        );
      }

      return (
        text: 'Graded',
        color: green,
      );
    }

    if (submissionStatus ==
        'submitted') {
      return (
        text: 'Submitted',
        color: purple,
      );
    }

    if (_isPastDue(task)) {
      return (
        text:
            'Deadline Passed',
        color: red,
      );
    }

    if (_isDueToday(task)) {
      return (
        text: 'Due Today',
        color: orange,
      );
    }

    return (
      text: 'To Do',
      color: primaryBlue,
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
        backgroundColor: red,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,

        backgroundColor: background,

        elevation: 0,

        centerTitle: true,

        title: const Text(
          'My Tasks',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Filter by due date',

            onPressed:
                _openCalendar,

            icon: Icon(
              Icons
                  .calendar_month_outlined,

              color:
                  _selectedDate ==
                          null
                      ? textDark
                      : primaryBlue,
            ),
          ),

          if (_selectedDate != null)
            IconButton(
              tooltip:
                  'Clear date filter',

              onPressed:
                  _clearDateFilter,

              icon: const Icon(
                Icons
                    .close_rounded,

                color: red,
              ),
            ),

          IconButton(
            tooltip:
                'Refresh',

            onPressed:
                _loadTasks,

            icon: const Icon(
              Icons.refresh_rounded,
              color: textDark,
            ),
          ),

          const SizedBox(
            width: 5,
          ),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment:
              Alignment.topCenter,

          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),

            child: _buildBody(),
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
          color: primaryBlue,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // ======================================================
        // DATE FILTER
        // ======================================================

        if (_selectedDate != null)
          Container(
            margin:
                const EdgeInsets.fromLTRB(
              22,
              8,
              22,
              0,
            ),

            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),

            decoration:
                BoxDecoration(
              color: primaryBlue
                  .withValues(
                alpha: 0.08,
              ),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons
                      .event_rounded,
                  color:
                      primaryBlue,
                  size: 18,
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: Text(
                    'Showing tasks due ${_formatShortDate(_selectedDate!)}',

                    style:
                        const TextStyle(
                      color:
                          primaryBlue,
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap:
                      _clearDateFilter,

                  child: const Text(
                    'Clear',

                    style:
                        TextStyle(
                      color:
                          primaryBlue,
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ======================================================
        // TABS
        // ======================================================

        Container(
          margin:
              const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 12,
          ),

          padding:
              const EdgeInsets.all(
            4,
          ),

          constraints:
              const BoxConstraints(
            maxWidth: 620,
          ),

          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFEEEFF3,
            ),

            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),

          child: Row(
            children: [
              Expanded(
                child:
                    _buildTab(
                  'To Do ($_todoCount)',
                  0,
                ),
              ),

              Expanded(
                child:
                    _buildTab(
                  'Submitted ($_submittedCount)',
                  1,
                ),
              ),

              Expanded(
                child:
                    _buildTab(
                  'Completed ($_completedCount)',
                  2,
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // TASK LIST
        // ======================================================

        Expanded(
          child: RefreshIndicator(
            onRefresh:
                _loadTasks,

            color:
                primaryBlue,

            child: _visibleTasks
                    .isEmpty
                ? _buildEmptyList()
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),

                    padding:
                        const EdgeInsets.fromLTRB(
                      22,
                      8,
                      22,
                      40,
                    ),

                    itemCount:
                        _visibleTasks.length,

                    itemBuilder: (
                      context,
                      index,
                    ) {
                      return _buildTaskCard(
                        _visibleTasks[
                            index],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB
  // ============================================================

  Widget _buildTab(
    String title,
    int index,
  ) {
    final bool selected =
        _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),

        padding:
            const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 3,
        ),

        alignment:
            Alignment.center,

        decoration:
            BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,

          borderRadius:
              BorderRadius.circular(
            10,
          ),

          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        Colors.black
                            .withValues(
                      alpha: 0.04,
                    ),

                    blurRadius: 8,

                    offset:
                        const Offset(
                      0,
                      2,
                    ),
                  ),
                ]
              : [],
        ),

        child: FittedBox(
          fit: BoxFit.scaleDown,

          child: Text(
            title,

            maxLines: 1,

            style:
                TextStyle(
              color: selected
                  ? primaryBlue
                  : textGrey,

              fontSize: 11.5,

              fontWeight:
                  selected
                      ? FontWeight
                          .w800
                      : FontWeight
                          .w600,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TASK CARD
  // ============================================================

  Widget _buildTaskCard(
    Map<String, dynamic> task,
  ) {
    final String title =
        (task['title'] ??
                'Assessment')
            .toString();

    final String type =
        (task['assessmentType'] ??
                'assessment')
            .toString()
            .toLowerCase();

    final String courseCode =
        (task['courseCode'] ?? '')
            .toString();

    final String courseTitle =
        (task['courseTitle'] ?? '')
            .toString();

    final String moduleTitle =
        (task['moduleTitle'] ?? '')
            .toString();

    final num points =
        (task['totalPoints'] as num?) ??
            0;

    final ({
      String text,
      Color color,
    }) badge =
        _badgeFor(
      task,
    );

    final Color typeColor =
        _assessmentColor(
      type,
    );

    final String subtitle =
        [
          if (courseCode.isNotEmpty)
            courseCode,
          if (courseTitle.isNotEmpty)
            courseTitle,
        ].join(' • ');

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 13,
      ),

      child: Material(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        child: InkWell(
          onTap: () {
            _openTask(
              task,
            );
          },

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          child: Container(
            padding:
                const EdgeInsets.all(
              16,
            ),

            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius
                      .circular(
                18,
              ),

              border: Border.all(
                color:
                    borderColor,
              ),
            ),

            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Container(
                  width: 49,
                  height: 49,

                  decoration:
                      BoxDecoration(
                    color: typeColor
                        .withValues(
                      alpha: 0.10,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),

                  child: Icon(
                    _assessmentIcon(
                      type,
                    ),

                    color:
                        typeColor,

                    size: 24,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,

                              style:
                                  const TextStyle(
                                color:
                                    textDark,

                                fontSize:
                                    14,

                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  8,
                              vertical:
                                  5,
                            ),

                            decoration:
                                BoxDecoration(
                              color: badge
                                  .color
                                  .withValues(
                                alpha:
                                    0.10,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                8,
                              ),
                            ),

                            child: Text(
                              badge.text,

                              style:
                                  TextStyle(
                                color:
                                    badge.color,

                                fontSize:
                                    8.5,

                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        '${_capitalize(type)} • $points points',

                        style:
                            TextStyle(
                          color:
                              typeColor,

                          fontSize:
                              10.5,

                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      if (subtitle
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          subtitle,

                          maxLines: 1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            color:
                                textGrey,

                            fontSize:
                                10.5,

                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],

                      if (moduleTitle
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          moduleTitle,

                          maxLines: 1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            color:
                                textGrey,

                            fontSize:
                                10,
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 9,
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons
                                .schedule_rounded,

                            color:
                                _isPastDue(
                                      task,
                                    ) &&
                                    (task['submissionStatus'] ??
                                            '')
                                        .toString()
                                        .isEmpty
                                ? red
                                : textGrey,

                            size: 15,
                          ),

                          const SizedBox(
                            width: 5,
                          ),

                          Expanded(
                            child: Text(
                              'Due ${_formatDate(task['dueAt'])}',

                              style:
                                  TextStyle(
                                color:
                                    _isPastDue(
                                              task,
                                            ) &&
                                            (task['submissionStatus'] ??
                                                    '')
                                                .toString()
                                                .isEmpty
                                        ? red
                                        : textGrey,

                                fontSize:
                                    10.5,

                                fontWeight:
                                    FontWeight
                                        .w500,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons
                                .chevron_right_rounded,

                            color:
                                Color(
                              0xFF9BA4B4,
                            ),

                            size: 21,
                          ),
                        ],
                      ),
                    ],
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
  // EMPTY LIST
  // ============================================================

  Widget _buildEmptyList() {
    String title;
    String message;
    IconData icon;

    if (_selectedDate != null) {
      title =
          'No tasks on this date';

      message =
          'There are no assessments due on ${_formatShortDate(_selectedDate!)}.';

      icon =
          Icons.event_available_outlined;
    } else if (_selectedTab == 0) {
      title =
          'You are all caught up';

      message =
          'You currently have no pending assessments.';

      icon =
          Icons.check_circle_outline_rounded;
    } else if (_selectedTab == 1) {
      title =
          'No submitted assessments';

      message =
          'Assessments waiting for instructor grading will appear here.';

      icon =
          Icons.upload_file_outlined;
    } else {
      title =
          'No completed assessments';

      message =
          'Your graded assessments will appear here.';

      icon =
          Icons.grade_outlined;
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.fromLTRB(
        22,
        65,
        22,
        40,
      ),

      children: [
        Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.all(
            30,
          ),

          decoration:
              BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border: Border.all(
              color:
                  borderColor,
            ),
          ),

          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,

                decoration:
                    BoxDecoration(
                  color: primaryBlue
                      .withValues(
                    alpha: 0.09,
                  ),

                  shape:
                      BoxShape.circle,
                ),

                child: Icon(
                  icon,
                  color:
                      primaryBlue,
                  size: 29,
                ),
              ),

              const SizedBox(
                height: 13,
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
                      15,

                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),

              const SizedBox(
                height: 5,
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
                      11,

                  height:
                      1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh:
          _loadTasks,

      color:
          primaryBlue,

      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          30,
        ),

        children: [
          const SizedBox(
            height: 120,
          ),

          const Icon(
            Icons
                .error_outline_rounded,

            color: red,

            size: 50,
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            _errorMessage ??
                'Unable to load your tasks.',

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color: textGrey,

              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Center(
            child:
                ElevatedButton.icon(
              onPressed:
                  _loadTasks,

              icon: const Icon(
                Icons
                    .refresh_rounded,

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
              ),
            ),
          ),
        ],
      ),
    );
  }
}