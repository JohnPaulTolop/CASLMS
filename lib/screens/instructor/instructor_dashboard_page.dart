import 'dart:async';

import '../shared/notification_inbox.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../shared/caslms_help_page.dart';
import 'instructor_ui.dart';

import '../../services/assignment_service.dart';
import '../../services/instructor_course_service.dart';

import 'instructor_announcements_page.dart';
import 'instructor_course_sections_page.dart';
import 'instructor_create_course_page.dart';

class InstructorDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const InstructorDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color blue = Color(0xFF1769FF);
  static const Color orange = Color(0xFFFF9418);
  static const Color purple = Color(0xFF7B4DFF);
  static const Color borderColor = Color(0xFFE6EAF0);

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
  String _searchQuery = '';

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
        builder: (context) =>
            InstructorCourseSectionsScreen(courseId: courseId),
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
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),

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
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: primaryTeal,
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER & WELCOME
            // ==================================================
            _buildHeader(),
            const SizedBox(height: 24),
            _buildWelcomeBanner(),
            const SizedBox(height: 24),

            _buildActiveClassesHeader(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildActiveClasses(),
            const SizedBox(height: 24),
            _buildStatistics(),
            const SizedBox(height: 24),
            const Text(
              'Teaching tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $_instructorName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a course, choose a section, then manage students, learning materials and grades.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundImage: AssetImage('assets/images/CASlogo.jpg'),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CASLMS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryTeal,
                ),
              ),
              Text(
                'Instructor portal',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: textGrey),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },

      decoration: InputDecoration(
        hintText: 'Search your courses...',

        hintStyle: const TextStyle(
          color: Color(0xFF8A93A5),

          fontSize: 14,

          fontWeight: FontWeight.w500,
        ),

        prefixIcon: const Icon(Icons.search_rounded, color: textGrey, size: 24),

        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });

                  FocusScope.of(context).unfocus();
                },

                icon: const Icon(Icons.close_rounded, color: textGrey),
              )
            : null,

        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,

          vertical: 17,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),

          borderSide: const BorderSide(color: Color(0xFFE2E6ED)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),

          borderSide: const BorderSide(color: Color(0xFFE2E6ED)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),

          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // REAL STATISTICS (Grouped Container)
  // ============================================================

  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInnerStat(
              title: 'Enrollments',
              value: '$_activeStudentCount',
              icon: Icons.groups_rounded,
              color: blue,
            ),
          ),
          Container(width: 1, height: 45, color: borderColor),
          Expanded(
            child: _buildInnerStat(
              title: 'To Grade',
              value: '$_pendingGradingCount',
              icon: Icons.grading_rounded,
              color: orange,
            ),
          ),
          Container(width: 1, height: 45, color: borderColor),
          Expanded(
            child: _buildInnerStat(
              title: 'Courses',
              value: '$_activeCourseCount',
              icon: Icons.class_rounded,
              color: primaryTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COURSE BUILDER BANNER
  // ============================================================

  Future<void> _openHelpGuide() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CaslmsHelpPage(role: 'instructor'),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 130,
          child: _buildQuickActionItem(
            icon: Icons.campaign_rounded,
            label: 'Announcements',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InstructorAnnouncementsScreen(),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: _buildQuickActionItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & guide',
            onTap: _openHelpGuide,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(15),

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(icon, color: primaryTeal, size: 26),

            const SizedBox(height: 8),

            Text(
              label,

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: textGrey,

                fontSize: 11.5,

                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClassesHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        const Text(
          'My Courses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        Wrap(
          spacing: 10,
          children: [
            if (_courses.isNotEmpty)
              TextButton(
                onPressed: () => widget.onNavigateToTab?.call(1),
                child: const Text('View all'),
              ),
            if (_courses.isNotEmpty)
              FilledButton.icon(
                onPressed: _openCreateCourse,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create course'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveClasses() {
    if (_courses.isEmpty) {
      return _buildNoCourses();
    }

    if (_filteredCourses.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(28),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: borderColor),
        ),

        child: const Column(
          children: [
            Icon(Icons.search_off_rounded, color: textGrey, size: 38),

            SizedBox(height: 10),

            Text(
              'No matching courses found.',

              style: TextStyle(color: textGrey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List<Widget>.generate(_dashboardCourses.length, (index) {
        final Map<String, dynamic> course = _dashboardCourses[index];

        return _buildClassCard(course, index);
      }),
    );
  }

  // ============================================================
  // NO COURSES
  // ============================================================

  Widget _buildNoCourses() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: borderColor),
      ),

      child: Column(
        children: [
          Container(
            width: 58,

            height: 58,

            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(17),
            ),

            child: const Icon(
              Icons.class_outlined,

              color: primaryTeal,

              size: 30,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'No active courses yet',

            style: TextStyle(
              color: textDark,

              fontSize: 16,

              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Create your first course to organize sections, assessments, and learning materials.',

            textAlign: TextAlign.center,

            style: TextStyle(color: textGrey, fontSize: 11.5, height: 1.5),
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _openCreateCourse,

            icon: const Icon(Icons.add_rounded, color: Colors.white),

            label: const Text(
              'Create Course',

              style: TextStyle(
                color: Colors.white,

                fontWeight: FontWeight.w700,
              ),
            ),

            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,

              elevation: 0,

              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CLASS CARD
  // ============================================================

  Widget _buildClassCard(Map<String, dynamic> course, int index) {
    final String title = (course['title'] ?? 'Course').toString();

    final String code = (course['code'] ?? '').toString();

    final String semester = (course['semester'] ?? '').toString();

    final String academicYear = (course['academicYear'] ?? '').toString();

    final int studentCount = (course['studentCount'] as num?)?.toInt() ?? 0;

    final List<Color> colors = [primaryTeal, blue, purple, orange];

    final Color color = colors[index % colors.length];

    final List<String> periodParts = [
      semester,
      academicYear,
    ].where((value) => value.trim().isNotEmpty).toList();

    final String period = periodParts.join(' \u2022 ');

    return InkWell(
      onTap: () {
        _openCourse(course);
      },

      borderRadius: BorderRadius.circular(20),

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: borderColor),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),

              blurRadius: 15,

              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 56,

              height: 56,

              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(16),
              ),

              child: Icon(Icons.menu_book_rounded, color: color, size: 28),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 15.5,

                      fontWeight: FontWeight.w800,

                      color: textDark,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      if (code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,

                            vertical: 3,
                          ),

                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),

                            borderRadius: BorderRadius.circular(6),
                          ),

                          child: Text(
                            code,

                            style: TextStyle(
                              color: color,

                              fontSize: 10.5,

                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                      if (code.isNotEmpty) const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          '$studentCount ${studentCount == 1 ? 'Student' : 'Students'}',

                          style: const TextStyle(
                            color: textGrey,

                            fontSize: 11.5,

                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (period.isNotEmpty) ...[
                    const SizedBox(height: 5),

                    Text(
                      period,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(color: textGrey, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right_rounded,

              color: Color(0xFF9BA4B4),

              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: primaryTeal,

      onRefresh: _loadDashboard,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(30),

        children: [
          const SizedBox(height: 100),

          const Icon(
            Icons.cloud_off_rounded,

            color: Colors.redAccent,

            size: 52,
          ),

          const SizedBox(height: 14),

          Text(
            _errorMessage ?? 'Unable to load dashboard.',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: textGrey,

              fontWeight: FontWeight.w600,

              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          Center(
            child: ElevatedButton.icon(
              onPressed: _loadDashboard,

              icon: const Icon(Icons.refresh_rounded, color: Colors.white),

              label: const Text(
                'Try Again',

                style: TextStyle(color: Colors.white),
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,

                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
