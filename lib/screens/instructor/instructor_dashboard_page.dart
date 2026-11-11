import '../../core/app_colors.dart';
import 'instructor_workspace_widgets.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/caslms_help_page.dart';
import 'instructor_ui.dart';

import '../../services/assignment_service.dart';
import '../../services/instructor_course_service.dart';

import 'instructor_announcements_page.dart';
import 'instructor_class_details_page.dart';
import 'instructor_create_course_page.dart';
import 'instructor_quick_create_page.dart';

class InstructorDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const InstructorDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  // ============================================================
  // SERVICES
  // ============================================================

  final InstructorCourseService _courseService = InstructorCourseService();
  final AssignmentService _assignmentService = AssignmentService();

  // ============================================================
  // STATE
  // ============================================================

  StreamSubscription<List<Map<String, dynamic>>>? _coursesSubscription;
  int _loadGeneration = 0;
  final Map<String, StreamSubscription> _submissionChanges = {};
  final Map<String, int> _pendingAssessmentCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _instructor;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _pendingSubmissions = [];
  final String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _coursesSubscription = _courseService.watchInstructorCourses().listen(
      (courses) {
        if (!mounted) return;
        _watchAssessmentCounts(courses);
        setState(() {
          _courses = courses;
          _errorMessage = null;
        });
        if (_instructor == null) {
          _loadDashboard(showLoading: true);
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to sync courses. Please retry.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _coursesSubscription?.cancel();
    for (final subscription in _submissionChanges.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        _courseService.getCurrentInstructorProfile(),
        _assignmentService.getInstructorPendingSubmissions(),
      ]);

      final Map<String, dynamic> instructor =
          results[0] as Map<String, dynamic>;
      final List<Map<String, dynamic>> pendingSubmissions =
          results[1] as List<Map<String, dynamic>>;

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _instructor = instructor;
        _pendingSubmissions = pendingSubmissions;
        _isLoading = false;
      });
    } on InstructorCourseServiceException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } on AssignmentServiceException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load instructor dashboard.';
      });
    }
  }

  void _watchAssessmentCounts(List<Map<String, dynamic>> courses) {
    final ids = courses.map((course) => course['courseId'].toString()).toSet();
    for (final id in _submissionChanges.keys.toList()) {
      if (!ids.contains(id)) {
        _submissionChanges.remove(id)?.cancel();
        _pendingAssessmentCounts.remove(id);
      }
    }
    for (final id in ids) {
      if (_submissionChanges.containsKey(id)) continue;
      _submissionChanges[id] = FirebaseFirestore.instance
          .collection('assessmentSubmissions')
          .where('courseId', isEqualTo: id)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted || !_courses.any((c) => c['courseId'] == id)) return;
              setState(
                () => _pendingAssessmentCounts[id] = snapshot.docs
                    .where(
                      (doc) => [
                        'submitted',
                        'under_review',
                        'late',
                      ].contains(doc.data()['status']),
                    )
                    .length,
              );
            },
            onError: (Object error) {
              /* Course navigation remains usable if this summary is unavailable. */
            },
          );
    }
  }

  // ============================================================
  // INSTRUCTOR INFORMATION
  // ============================================================

  String get _instructorName {
    final String name =
        (_instructor?['name'] ?? _instructor?['displayName'] ?? '')
            .toString()
            .trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'Instructor';
  }

  // ============================================================
  // REAL STATISTICS
  // ============================================================

  int get _activeCourseCount => _courses.length;

  int get _activeStudentCount {
    int count = 0;
    for (final Map<String, dynamic> course in _courses) {
      count += (course['studentCount'] as num?)?.toInt() ?? 0;
    }
    return count;
  }

  int get _pendingGradingCount =>
      _pendingSubmissions.length +
      _pendingAssessmentCounts.values.fold<int>(
        0,
        (int total, int value) => total + value,
      );

  // ============================================================
  // FILTERED COURSES
  // ============================================================

  List<Map<String, dynamic>> get _filteredCourses {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _courses;
    }

    return _courses.where((course) {
      final String title = (course['title'] ?? '').toString().toLowerCase();
      final String code = (course['code'] ?? '').toString().toLowerCase();
      final String classCode = (course['classCode'] ?? '')
          .toString()
          .toLowerCase();
      final String semester = (course['semester'] ?? '')
          .toString()
          .toLowerCase();
      final String academicYear = (course['academicYear'] ?? '')
          .toString()
          .toLowerCase();

      return title.contains(query) ||
          code.contains(query) ||
          classCode.contains(query) ||
          semester.contains(query) ||
          academicYear.contains(query);
    }).toList();
  }

  // ============================================================
  // DASHBOARD PREVIEW COURSES
  // ============================================================

  int _courseCreatedAt(Map<String, dynamic> course) {
    final value = course['createdAt'] ?? course['updatedAt'];

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  List<Map<String, dynamic>> get _dashboardCourses {
    final courses = List<Map<String, dynamic>>.from(_filteredCourses);

    courses.sort((a, b) {
      final byDate = _courseCreatedAt(b).compareTo(_courseCreatedAt(a));

      if (byDate != 0) return byDate;

      return (a['code'] ?? '').toString().compareTo(
        (b['code'] ?? '').toString(),
      );
    });

    return courses.take(4).toList();
  }

  // ============================================================
  // CREATE COURSE
  // ============================================================

  Future<void> _openCreateCourse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InstructorCreateCourseScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _quickCreate(InstructorCreateKind kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstructorQuickCreateScreen(kind: kind),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  // ============================================================
  // OPEN COURSE
  // ============================================================

  Future<void> _openCourse(Map<String, dynamic> course) async {
    final String courseId = (course['courseId'] ?? course['id'] ?? '')
        .toString()
        .trim();

    if (courseId.isEmpty) {
      _showMessage(
        'This course does not have a valid Firestore ID.',
        isError: true,
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorClassDetailsScreen(courseId: courseId),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : primaryTeal,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => instructorScaffold(
    loading: _isLoading,
    context: context,
    title: '',
    showHeading: false,
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadDashboard,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
              child: InstructorDashboardContent(
                name: _instructorName,
                onRefresh: _loadDashboard,
                enrollments: _activeStudentCount,
                pending: _pendingGradingCount,
                courseCount: _activeCourseCount,
                courses: _dashboardCourses,
                onCourse: _openCourse,
                onCreate: _openCreateCourse,
                onCreateModule: () => _quickCreate(InstructorCreateKind.module),
                onCreateAssessment: () =>
                    _quickCreate(InstructorCreateKind.assessment),
                onCreateMaterial: () =>
                    _quickCreate(InstructorCreateKind.material),
                onCourses: () => widget.onNavigateToTab?.call(1),
                onGrade: () => widget.onNavigateToTab?.call(2),
                onAi: () => widget.onNavigateToTab?.call(6),
                onCalendar: () => widget.onNavigateToTab?.call(7),
                onAnnouncements: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InstructorAnnouncementsScreen(),
                  ),
                ),
                onHelp: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CaslmsHelpPage(role: 'instructor'),
                  ),
                ),
              ),
            ),
          ),
  );
}
