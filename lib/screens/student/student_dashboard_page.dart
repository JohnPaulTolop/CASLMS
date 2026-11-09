import '../../core/app_colors.dart';
import '../../services/progress_service.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';
import 'student_dashboard_view.dart';
import 'student_course_modules_page.dart';

import 'dart:async';

import '../../services/course_invitation_service.dart';
import '../shared/notification_inbox.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/student_assessment_query_service.dart';

import 'student_course_invitations_page.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const StudentDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  // ============================================================
  // SERVICES
  // ============================================================

  final EnrollmentService _enrollmentService = EnrollmentService();

  final StudentAssessmentQueryService _assessmentQuery =
      StudentAssessmentQueryService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  StreamSubscription<List<Map<String, dynamic>>>? _classesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _invitationsSubscription;
  int _pendingInvitations = 0;
  bool _isLoading = true;

  String? _errorMessage;
  String? _summaryError;

  Map<String, dynamic>? _student;

  List<Map<String, dynamic>> _courses = [];

  List<Map<String, dynamic>> _upcomingAssessments = [];

  int _pendingTaskCount = 0;

  int _announcementCount = 0;
  int _assessmentCount = 0;
  bool _summaryLoaded = false;
  Map<String, double> _courseProgress = {};
  StreamSubscription<Map<String, dynamic>>? _progressSubscription;

  void _watchProgress() {
    _progressSubscription?.cancel();
    _progressSubscription = ProgressService().watchStudentProgress().listen(
      (report) {
        if (!mounted) return;
        setState(
          () => _courseProgress = {
            for (final row
                in (report['courses'] as List? ?? []).whereType<Map>())
              (row['courseId'] ?? row['id']).toString():
                  ((row['moduleProgress'] as num?)?.toDouble() ?? 0).clamp(
                    0.0,
                    1.0,
                  ),
          },
        );
      },
      onError: (Object error) {
        // Unknown progress stays unknown instead of claiming zero completion.
        if (mounted) setState(() => _courseProgress = {});
      },
    );
  }

  // If two dashboard loads happen close together,
  // only the newest one may update the State.
  int _loadGeneration = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _watchProgress();

    _classesSubscription = _enrollmentService.watchMyActiveCourses().listen(
      (courses) {
        if (!mounted) return;
        setState(() {
          _courses = courses;
          _errorMessage = null;
        });
        _loadDashboard(showLoading: _student == null, activeCourses: courses);
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Unable to sync classes. Check your connection and retry.';
          });
        }
      },
    );
    _invitationsSubscription = CourseInvitationService()
        .watchMyPendingInvitations()
        .listen(
          (items) {
            if (mounted) setState(() => _pendingInvitations = items.length);
          },
          onError: (Object error) {
            /* The invitations screen provides retry and error details. */
          },
        );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _classesSubscription?.cancel();
    _invitationsSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({
    bool showLoading = true,
    List<Map<String, dynamic>>? activeCourses,
  }) async {
    final int generation = ++_loadGeneration;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // --------------------------------------------------------
      // CURRENT STUDENT
      // --------------------------------------------------------

      final Map<String, dynamic> student = await _enrollmentService
          .getCurrentStudentProfile();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _student = student;
        _isLoading = false;
      });

      // --------------------------------------------------------
      // REAL ACTIVE COURSES
      // --------------------------------------------------------

      final List<Map<String, dynamic>> courses =
          activeCourses ?? await _enrollmentService.getMyActiveCourses();

      final String studentId = _auth.currentUser?.uid ?? '';

      if (studentId.isEmpty) {
        throw EnrollmentServiceException('No student is currently logged in.');
      }

      // --------------------------------------------------------
      // ASSESSMENT SUBMISSIONS
      // --------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> submissionSnapshot =
          await _firestore
              .collection('assessmentSubmissions')
              .where('studentId', isEqualTo: studentId)
              .get();

      final Map<String, Map<String, dynamic>> submissionByAssessmentId = {};

      for (final document in submissionSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String assessmentId = (data['assessmentId'] ?? '')
            .toString()
            .trim();

        if (assessmentId.isEmpty) {
          continue;
        }

        submissionByAssessmentId[assessmentId] = {
          ...data,
          'id': document.id,
          'submissionId': document.id,
        };
      }

      // --------------------------------------------------------
      // PENDING ASSESSMENTS
      // --------------------------------------------------------

      final List<Map<String, dynamic>> pendingAssessments = [];
      var assessmentCount = 0;

      for (final course in courses) {
        final String courseId = (course['courseId'] ?? course['id'] ?? '')
            .toString()
            .trim();

        if (courseId.isEmpty) {
          continue;
        }

        final assessmentDocuments = await _assessmentQuery
            .getVisibleAssessments(courseId: courseId);

        for (final document in assessmentDocuments) {
          final Map<String, dynamic> assessment = document.data();

          final String status = (assessment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (status != 'published') {
            continue;
          }
          assessmentCount++;

          final Map<String, dynamic>? submission =
              submissionByAssessmentId[document.id];

          final String submissionStatus = (submission?['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (submissionStatus == 'submitted' || submissionStatus == 'graded') {
            continue;
          }

          pendingAssessments.add({
            ...assessment,

            'id': document.id,

            'assessmentId': document.id,

            'courseId': courseId,

            'courseCode': (course['code'] ?? '').toString(),

            'courseTitle': (course['title'] ?? '').toString(),
          });
        }
      }

      // --------------------------------------------------------
      // SORT BY DUE DATE
      // --------------------------------------------------------

      pendingAssessments.sort((a, b) {
        final DateTime? first = _dateFrom(a['dueAt']);

        final DateTime? second = _dateFrom(b['dueAt']);

        if (first == null && second == null) {
          return 0;
        }

        if (first == null) {
          return 1;
        }

        if (second == null) {
          return -1;
        }

        return first.compareTo(second);
      });

      final DateTime now = DateTime.now();

      final List<Map<String, dynamic>> upcomingAssessments = pendingAssessments
          .where((assessment) {
            final DateTime? dueAt = _dateFrom(assessment['dueAt']);

            return dueAt != null && dueAt.isAfter(now);
          })
          .take(5)
          .toList();

      // --------------------------------------------------------
      // ANNOUNCEMENTS
      // --------------------------------------------------------

      int announcementCount = 0;

      for (final course in courses) {
        final String courseId = (course['courseId'] ?? course['id'] ?? '')
            .toString()
            .trim();

        if (courseId.isEmpty) {
          continue;
        }

        final QuerySnapshot<Map<String, dynamic>> announcementSnapshot =
            await _firestore
                .collection('announcements')
                .where('courseId', isEqualTo: courseId)
                .get();

        announcementCount += announcementSnapshot.docs.length;
      }

      // --------------------------------------------------------
      // NOTIFICATIONS
      // --------------------------------------------------------

      // A newer request already started.
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _student = student;
        _summaryError = null;
        _courses = courses;

        _pendingTaskCount = pendingAssessments.length;
        _assessmentCount = assessmentCount;
        _summaryLoaded = true;

        _upcomingAssessments = upcomingAssessments;

        _announcementCount = announcementCount;

        _isLoading = false;

        _errorMessage = null;
      });
    } on EnrollmentServiceException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _recordLoadError(e.message);
      });
    } on FirebaseException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _recordLoadError(e.message ?? 'Unable to load dashboard.');
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _recordLoadError('Unable to load student dashboard.');
      });
    }
  }

  // ============================================================
  // STUDENT NAME
  // ============================================================

  void _recordLoadError(String message) {
    if (_student == null) {
      _errorMessage = message;
    } else {
      _summaryError =
          'Some dashboard totals could not be updated. Pull to refresh.';
    }
  }

  String get _studentName {
    final String name = (_student?['name'] ?? _student?['displayName'] ?? '')
        .toString()
        .trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'Student';
  }

  String get _firstName {
    final String name = _studentName.trim();

    if (name.isEmpty) {
      return 'Student';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(DateTime value) {
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

    final DateTime date = value.toLocal();

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  String _formatTime(DateTime value) {
    final DateTime date = value.toLocal();

    int hour = date.hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  // ============================================================
  // COURSE INVITATIONS
  // ============================================================

  Future<void> _openCourseInvitations() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StudentCourseInvitationsScreen(),
      ),
    );

    if (!mounted) return;
    await _loadDashboard(showLoading: false);
  }

  // ============================================================
  // ASSESSMENT HELPERS
  // ============================================================

  Future<void> _refresh() async {
    _watchProgress();
    await _loadDashboard(showLoading: false);
  }

  Future<void> _openCourse(int index) async {
    final course = _courses[index];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentCourseModulesScreen(
          courseId: (course['courseId'] ?? course['id'] ?? '').toString(),
          courseTitle: (course['title'] ?? '').toString(),
          courseCode: (course['code'] ?? '').toString(),
          instructorName: (course['instructorName'] ?? '').toString(),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openAssessment(int index) async {
    final item = _upcomingAssessments[index];
    final moduleId = (item['moduleId'] ?? '').toString();
    if (moduleId.isEmpty) {
      widget.onNavigateToTab?.call(2);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentCourseModulesScreen(
          courseId: (item['courseId'] ?? '').toString(),
          courseCode: (item['courseCode'] ?? '').toString(),
          courseTitle: (item['courseTitle'] ?? '').toString(),
          instructorName: '',
          initialModuleId: moduleId,
          initialAssessmentId: (item['assessmentId'] ?? '').toString(),
          initialView: 1,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  void _inbox() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(9);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const NotificationInboxScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inset = workspaceInset(box.maxWidth);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const PageStorageKey('student-dashboard-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            inset,
            0,
            inset,
            MediaQuery.paddingOf(context).bottom + 28,
          ),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              WorkspaceSurface(
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.secondaryText,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loadDashboard,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else
              StudentDashboardView(
                firstName: _firstName,
                courses: [
                  for (var i = 0; i < _courses.take(4).length; i++)
                    courseSummary(
                      _courses[i],
                      i,
                      progress:
                          _courseProgress[(_courses[i]['courseId'] ??
                                  _courses[i]['id'])
                              .toString()],
                    ),
                ],
                assessments: _upcomingAssessments.map((item) {
                  final date = _dateFrom(item['dueAt'])!.toLocal();
                  final type = (item['assessmentType'] ?? 'Assessment')
                      .toString();
                  final color = type.toLowerCase() == 'activity'
                      ? AppColors.green
                      : type.toLowerCase() == 'assignment'
                      ? AppColors.purple
                      : AppColors.primaryBlue;
                  final tint = type.toLowerCase() == 'activity'
                      ? AppColors.greenTint
                      : type.toLowerCase() == 'assignment'
                      ? AppColors.purpleTint
                      : AppColors.blueTint;
                  return AssessmentSummary(
                    title: (item['title'] ?? 'Assessment').toString(),
                    course: (item['courseCode'] ?? '').toString(),
                    day: '${date.day}',
                    month: const [
                      'JAN',
                      'FEB',
                      'MAR',
                      'APR',
                      'MAY',
                      'JUN',
                      'JUL',
                      'AUG',
                      'SEP',
                      'OCT',
                      'NOV',
                      'DEC',
                    ][date.month - 1],
                    due: _formatDate(date),
                    time: _formatTime(date),
                    type: type.isEmpty
                        ? 'Assessment'
                        : type[0].toUpperCase() + type.substring(1),
                    color: color,
                    tint: tint,
                  );
                }).toList(),
                activeCourseCount: _courses.length,
                assessmentCount: _summaryLoaded ? _assessmentCount : null,
                pendingCount: _summaryLoaded ? _pendingTaskCount : null,
                announcementCount: _summaryLoaded ? _announcementCount : null,
                pendingInvitations: _pendingInvitations,
                summaryError: _summaryError,
                onRetry: _refresh,
                onCourse: _openCourse,
                onAssessment: _openAssessment,
                onCourses: () => widget.onNavigateToTab?.call(1),
                onTasks: () => widget.onNavigateToTab?.call(2),
                onInbox: _inbox,
                onAssistant: () => widget.onNavigateToTab?.call(6),
                onInvitations: _openCourseInvitations,
                onNotes: () => widget.onNavigateToTab?.call(11),
              ),
          ],
        ),
      );
    },
  );
}
