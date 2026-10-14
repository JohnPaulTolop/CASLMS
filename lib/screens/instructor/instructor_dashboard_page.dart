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

    _loadDashboard();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        _courseService.getCurrentInstructorProfile(),

        _courseService.getInstructorCourses(),

        _assignmentService.getInstructorPendingSubmissions(),
      ]);

      final Map<String, dynamic> instructor =
          results[0] as Map<String, dynamic>;

      final List<Map<String, dynamic>> courses =
          results[1] as List<Map<String, dynamic>>;

      final List<Map<String, dynamic>> pendingSubmissions =
          results[2] as List<Map<String, dynamic>>;

      if (!mounted) {
        return;
      }

      setState(() {
        _instructor = instructor;

        _courses = courses;

        _pendingSubmissions = pendingSubmissions;

        _isLoading = false;
      });
    } on InstructorCourseServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } on AssignmentServiceException catch (e) {
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

        _errorMessage = 'Unable to load instructor dashboard.';
      });
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

  int get _pendingGradingCount => _pendingSubmissions.length;

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
            // HEADER
            // ==================================================

            _buildHeader(),

            const SizedBox(height: 24),

            _buildWelcomeBanner(),

            const SizedBox(height: 20),

            // ==================================================
            // SEARCH
            // ==================================================
            _buildSearchBar(),

            const SizedBox(height: 24),

            // ==================================================
            // RECENT COURSES
            // ==================================================
            _buildActiveClassesHeader(),

            const SizedBox(height: 14),

            _buildActiveClasses(),

            const SizedBox(height: 20),

            // ==================================================
            // REAL STATISTICS
            // ==================================================
            _buildStatistics(),

            const SizedBox(height: 28),

            // ==================================================
            // COURSE WORKFLOW
            // ==================================================
            _buildCourseBuilderBanner(),

            const SizedBox(height: 28),

            // ==================================================
            // TOOLS
            // ==================================================
            const Text(
              'Quick Actions',

              style: TextStyle(
                fontSize: 18,

                fontWeight: FontWeight.w800,

                color: textDark,

                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 14),

            _buildQuickActions(),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Open step-by-step CASLMS instructions',
                child: TextButton.icon(
                  onPressed: _openHelpGuide,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help & User Guide'),
                ),
              ),
            ),

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
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -52,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 62,
            bottom: -74,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $_instructorName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pendingGradingCount == 0
                              ? 'Your classes are organized and up to date.'
                              : '$_pendingGradingCount ${_pendingGradingCount == 1 ? 'submission needs' : 'submissions need'} your review.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.87),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.co_present_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildWelcomeChip(
                    Icons.class_rounded,
                    '$_activeCourseCount ${_activeCourseCount == 1 ? 'course' : 'courses'}',
                  ),
                  _buildWelcomeChip(
                    Icons.groups_rounded,
                    '$_activeStudentCount students',
                  ),
                  InkWell(
                    onTap: () => widget.onNavigateToTab?.call(2),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Review work',
                            style: TextStyle(
                              color: primaryTeal,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryTeal,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            border: Border.all(color: const Color(0xFFE2E6ED), width: 1),

            image: const DecorationImage(
              image: AssetImage('assets/images/CASlogo.jpg'),

              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'CASLMS',

              style: TextStyle(
                fontSize: 22,

                fontWeight: FontWeight.w800,

                color: primaryTeal,

                letterSpacing: -0.8,
              ),
            ),

            Text(
              'INSTRUCTOR PORTAL',

              style: TextStyle(
                fontSize: 9.5,

                fontWeight: FontWeight.w800,

                color: primaryTeal.withValues(alpha: 0.7),

                letterSpacing: 0.8,
              ),
            ),
          ],
        ),

        const Spacer(),

        // --------------------------------------------------------
        // REFRESH
        // --------------------------------------------------------
        _buildHeaderIcon(
          icon: Icons.refresh_rounded,

          tooltip: 'Refresh',

          onTap: _loadDashboard,
        ),

        const SizedBox(width: 10),

        // --------------------------------------------------------
        // PROFILE
        // --------------------------------------------------------
        GestureDetector(
          onTap: () {
            widget.onNavigateToTab?.call(4);
          },

          child: Container(
            width: 44,

            height: 44,

            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.10),

              shape: BoxShape.circle,

              border: Border.all(color: Colors.white, width: 3),
            ),

            alignment: Alignment.center,

            child: Text(
              _instructorName.trim().isEmpty
                  ? '?'
                  : _instructorName.trim()[0].toUpperCase(),

              style: const TextStyle(
                color: primaryTeal,

                fontSize: 17,

                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,

      child: GestureDetector(
        onTap: onTap,

        child: Container(
          width: 44,

          height: 44,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: const Color(0xFFE7EAF0)),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),

                blurRadius: 12,

                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Icon(icon, color: textDark, size: 23),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

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
  // REAL STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 650;

        final List<Widget> cards = [
          _buildStatCard(
            title: 'Active Students',

            value: '$_activeStudentCount',

            subtitle: _activeCourseCount == 1
                ? 'Across 1 class'
                : 'Across $_activeCourseCount classes',

            icon: Icons.groups_rounded,

            color: blue,
          ),

          _buildStatCard(
            title: 'Pending Grading',

            value: '$_pendingGradingCount',

            subtitle: _pendingGradingCount == 1
                ? 'Submission to review'
                : 'Submissions to review',

            icon: Icons.grading_rounded,

            color: orange,
          ),

          _buildStatCard(
            title: 'Active Courses',

            value: '$_activeCourseCount',

            subtitle: _activeCourseCount == 1
                ? 'Course you manage'
                : 'Courses you manage',

            icon: Icons.class_rounded,

            color: primaryTeal,
          ),
        ];

        if (narrow) {
          return Column(
            children: [
              cards[0],

              const SizedBox(height: 12),

              cards[1],

              const SizedBox(height: 12),

              cards[2],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),

            const SizedBox(width: 16),

            Expanded(child: cards[1]),

            const SizedBox(width: 16),

            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

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
            width: 46,

            height: 46,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(icon, color: color, size: 23),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 11.5,

                    color: textGrey,

                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 24,

                    fontWeight: FontWeight.w800,

                    color: color,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 10,

                    color: textGrey,

                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COURSE BUILDER BANNER
  // ============================================================

  Widget _buildCourseBuilderBanner() {
    return GestureDetector(
      onTap: () {
        if (_courses.isEmpty) {
          _openCreateCourse();

          return;
        }

        widget.onNavigateToTab?.call(1);
      },

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF26A69A)],

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,
          ),

          borderRadius: BorderRadius.circular(20),

          boxShadow: [
            BoxShadow(
              color: primaryTeal.withValues(alpha: 0.25),

              blurRadius: 18,

              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.menu_book_rounded,

                color: Colors.white,

                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _courses.isEmpty
                        ? 'Create Your First Course'
                        : 'Build Modules & Assessments',

                    style: const TextStyle(
                      fontSize: 15.5,

                      fontWeight: FontWeight.w800,

                      color: Colors.white,

                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _courses.isEmpty
                        ? 'Create a course first, then add modules and quizzes.'
                        : 'Open a class to manage modules, learning materials, and quizzes.',

                    style: TextStyle(
                      fontSize: 12,

                      color: Colors.white.withValues(alpha: 0.85),

                      height: 1.4,

                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,

              color: Colors.white,

              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),

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
          Expanded(
            child: _buildQuickActionItem(
              icon: Icons.add_box_rounded,

              label: 'Create Course',

              onTap: _openCreateCourse,
            ),
          ),

          _buildDivider(),

          Expanded(
            child: _buildQuickActionItem(
              icon: Icons.campaign_rounded,

              label: 'Announce',

              onTap: () async {
                await Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder: (context) => const InstructorAnnouncementsScreen(),
                  ),
                );

                if (!mounted) {
                  return;
                }

                await _loadDashboard();
              },
            ),
          ),

          _buildDivider(),

          Expanded(
            child: _buildQuickActionItem(
              icon: Icons.library_add_check_rounded,

              label: 'Grade Tasks',

              onTap: () {
                widget.onNavigateToTab?.call(2);
              },
            ),
          ),

          _buildDivider(),

          Expanded(
            child: _buildQuickActionItem(
              icon: Icons.auto_awesome_outlined,
              label: 'AI Help',
              onTap: () {
                widget.onNavigateToTab?.call(6);
              },
            ),
          ),
        ],
      ),
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

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: const Color(0xFFE9EDF3));
  }

  // ============================================================
  // ACTIVE CLASSES HEADER
  // ============================================================

  Widget _buildActiveClassesHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Recently Added Courses',

            style: TextStyle(
              fontSize: 18,

              fontWeight: FontWeight.w800,

              color: textDark,

              letterSpacing: -0.3,
            ),
          ),
        ),

        if (_courses.isNotEmpty)
          GestureDetector(
            onTap: () {
              widget.onNavigateToTab?.call(1);
            },

            child: const Text(
              'View all',

              style: TextStyle(
                fontSize: 13,

                fontWeight: FontWeight.w700,

                color: primaryTeal,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ACTIVE CLASSES
  // ============================================================

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

    final String classCode = (course['classCode'] ?? '').toString();

    final String semester = (course['semester'] ?? '').toString();

    final String academicYear = (course['academicYear'] ?? '').toString();

    final int studentCount = (course['studentCount'] as num?)?.toInt() ?? 0;

    final List<Color> colors = [primaryTeal, blue, purple, orange];

    final Color color = colors[index % colors.length];

    final List<String> periodParts = [
      semester,
      academicYear,
    ].where((value) => value.trim().isNotEmpty).toList();

    final String period = periodParts.join(
      ' ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢ ',
    );

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

                  if (classCode.isNotEmpty) ...[
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons.vpn_key_outlined,

                          color: primaryTeal,

                          size: 13,
                        ),

                        const SizedBox(width: 4),

                        Flexible(
                          child: Text(
                            'Class Code: $classCode',

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: primaryTeal,

                              fontSize: 10.5,

                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
