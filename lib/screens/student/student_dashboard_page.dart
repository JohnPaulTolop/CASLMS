import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/student_assessment_query_service.dart';

import 'notifications_page.dart';
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

  static const Color primaryBlue = Color(0xFF1769FF);

  static const Color background = Color(0xFFF8FAFD);

  static const Color textDark = Color(0xFF111827);

  static const Color textGrey = Color(0xFF6B7280);

  static const Color orange = Color(0xFFFFA800);

  static const Color green = Color(0xFF25A55F);

  static const Color purple = Color(0xFF7B4DFF);

  static const Color red = Color(0xFFFF4B4B);

  static const Color lightBlue = Color(0xFFEAF3FF);

  static const Color borderColor = Color(0xFFE5EAF0);

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

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _student;

  List<Map<String, dynamic>> _courses = [];

  List<Map<String, dynamic>> _upcomingAssessments = [];

  int _pendingTaskCount = 0;

  int _announcementCount = 0;

  int _unreadNotificationCount = 0;

  // If two dashboard loads happen close together,
  // only the newest one may update the State.
  int _loadGeneration = 0;

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

  Future<void> _loadDashboard({bool showLoading = true}) async {
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

      // --------------------------------------------------------
      // REAL ACTIVE COURSES
      // --------------------------------------------------------

      final List<Map<String, dynamic>> courses = await _enrollmentService
          .getMyActiveCourses();

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

      final QuerySnapshot<Map<String, dynamic>> notificationSnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: studentId)
              .get();

      int unreadNotifications = 0;

      for (final document in notificationSnapshot.docs) {
        if (document.data()['isRead'] != true) {
          unreadNotifications++;
        }
      }

      // A newer request already started.
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _student = student;

        _courses = courses;

        _pendingTaskCount = pendingAssessments.length;

        _upcomingAssessments = upcomingAssessments;

        _announcementCount = announcementCount;

        _unreadNotificationCount = unreadNotifications;

        _isLoading = false;

        _errorMessage = null;
      });
    } on EnrollmentServiceException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = e.message;
      });
    } on FirebaseException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = e.message ?? 'Unable to load dashboard.';
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = 'Unable to load student dashboard.';
      });
    }
  }

  // ============================================================
  // STUDENT NAME
  // ============================================================

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

  String get _studentInitial {
    final String name = _studentName.trim();

    if (name.isEmpty) {
      return '?';
    }

    return name[0].toUpperCase();
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
  // JOIN SECTION BY CODE
  // ============================================================

  Future<void> _openJoinSection() async {
    final joined = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JoinClassSheet(enrollmentService: _enrollmentService),
    );

    if (!mounted || joined == null) {
      return;
    }

    await _loadDashboard(showLoading: false);
  }
  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard(showLoading: false);
  }

  // ============================================================
  // ASSESSMENT ICON
  // ============================================================

  IconData _assessmentIcon(String type) {
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

  Color _assessmentColor(String type) {
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: RefreshIndicator(
          color: primaryBlue,

          onRefresh: () {
            return _loadDashboard(showLoading: false);
          },

          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool desktop = constraints.maxWidth >= 850;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: EdgeInsets.symmetric(
                  horizontal: desktop ? 50 : 20,

                  vertical: desktop ? 30 : 18,
                ),

                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1150),

                      child: _buildContent(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 500,

        child: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildHeader(),

        const SizedBox(height: 24),

        _buildWelcomeBanner(),

        const SizedBox(height: 20),

        _buildStatistics(),

        const SizedBox(height: 28),

        _buildSectionHeader(
          title: 'My Classes',

          action: 'View all',

          onTap: () {
            widget.onNavigateToTab?.call(1);
          },
        ),

        const SizedBox(height: 12),

        _buildClasses(),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _openJoinSection,
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text(
              'Join Section with Code',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,

          height: 52,

          child: OutlinedButton.icon(
            onPressed: _openCourseInvitations,

            icon: const Icon(Icons.mark_email_unread_outlined),

            label: const Text(
              'View Course Invitations',

              style: TextStyle(fontWeight: FontWeight.w800),
            ),

            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,

              side: const BorderSide(color: primaryBlue),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        _buildSectionHeader(
          title: 'Upcoming',

          action: 'View Tasks',

          onTap: () {
            widget.onNavigateToTab?.call(2);
          },
        ),

        const SizedBox(height: 12),

        _buildUpcoming(),

        const SizedBox(height: 30),
      ],
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
          colors: [Color(0xFF1769FF), Color(0xFF5B8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -45,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 44,
            bottom: -64,
            child: Container(
              width: 100,
              height: 100,
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
                          'Hello, $_firstName!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pendingTaskCount == 0
                              ? 'You are all caught up. Keep learning!'
                              : 'You have $_pendingTaskCount ${_pendingTaskCount == 1 ? 'task' : 'tasks'} waiting for you.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
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
                      Icons.school_rounded,
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
                    Icons.menu_book_rounded,
                    '${_courses.length} ${_courses.length == 1 ? 'class' : 'classes'}',
                  ),
                  _buildWelcomeChip(
                    Icons.notifications_active_rounded,
                    '$_announcementCount updates',
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
                            'View tasks',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryBlue,
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
          width: 46,

          height: 46,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: borderColor),

            image: const DecorationImage(
              image: AssetImage('assets/images/CASlogo.jpg'),

              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(width: 12),

        const Text(
          'CASLMS',

          style: TextStyle(
            color: primaryBlue,

            fontSize: 23,

            fontWeight: FontWeight.w900,
          ),
        ),

        const Spacer(),

        Stack(
          clipBehavior: Clip.none,

          children: [
            IconButton(
              onPressed: _openNotifications,

              icon: const Icon(
                Icons.notifications_none_rounded,

                color: textDark,

                size: 27,
              ),
            ),

            if (_unreadNotificationCount > 0)
              Positioned(
                right: 2,

                top: 2,

                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,

                    minHeight: 18,
                  ),

                  padding: const EdgeInsets.symmetric(horizontal: 4),

                  alignment: Alignment.center,

                  decoration: const BoxDecoration(
                    color: red,

                    shape: BoxShape.circle,
                  ),

                  child: Text(
                    _unreadNotificationCount > 9
                        ? '9+'
                        : '$_unreadNotificationCount',

                    style: const TextStyle(
                      color: Colors.white,

                      fontSize: 9,

                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: 6),

        GestureDetector(
          onTap: () {
            widget.onNavigateToTab?.call(4);
          },

          child: CircleAvatar(
            radius: 21,

            backgroundColor: lightBlue,

            child: Text(
              _studentInitial,

              style: const TextStyle(
                color: primaryBlue,

                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '${_courses.length}',

            label: 'Classes',

            color: primaryBlue,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildStatCard(
            value: '$_pendingTaskCount',

            label: 'Tasks',

            color: orange,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildStatCard(
            value: '$_announcementCount',

            label: 'Announcements',

            color: green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    final IconData icon = label == 'Classes'
        ? Icons.auto_stories_rounded
        : label == 'Tasks'
        ? Icons.task_alt_rounded
        : Icons.campaign_rounded;

    return Container(
      height: 105,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          Text(
            label,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: textGrey,

              fontSize: 10.5,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({
    required String title,
    required String action,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Text(
          title,

          style: const TextStyle(
            color: textDark,

            fontSize: 19,

            fontWeight: FontWeight.w800,
          ),
        ),

        const Spacer(),

        TextButton(
          onPressed: onTap,

          child: Text(
            action,

            style: const TextStyle(
              color: primaryBlue,

              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CLASSES
  // ============================================================

  Widget _buildClasses() {
    if (_courses.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: borderColor),
        ),

        child: const Column(
          children: [
            Icon(Icons.school_outlined, color: primaryBlue, size: 35),

            SizedBox(height: 10),

            Text(
              'You have not joined a class yet.',

              textAlign: TextAlign.center,

              style: TextStyle(color: textDark, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final int visibleCount = _courses.length > 4 ? 4 : _courses.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: borderColor),
      ),

      child: Column(
        children: List.generate(visibleCount, (index) {
          final Map<String, dynamic> course = _courses[index];

          final String courseCode = (course['code'] ?? 'Course').toString();

          final String courseTitle = (course['title'] ?? '').toString();

          final String instructor = (course['instructorName'] ?? '').toString();

          return Column(
            children: [
              ListTile(
                onTap: () {
                  widget.onNavigateToTab?.call(1);
                },

                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,

                  vertical: 5,
                ),

                leading: Container(
                  width: 46,

                  height: 46,

                  decoration: BoxDecoration(
                    color: lightBlue,

                    borderRadius: BorderRadius.circular(13),
                  ),

                  child: const Icon(
                    Icons.menu_book_rounded,

                    color: primaryBlue,
                  ),
                ),

                title: Text(
                  courseCode,

                  style: const TextStyle(
                    color: textDark,

                    fontWeight: FontWeight.w800,
                  ),
                ),

                subtitle: Text(
                  [
                    courseTitle,

                    if (instructor.trim().isNotEmpty) instructor,
                  ].where((value) => value.trim().isNotEmpty).join(' \u2022 '),

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,
                ),

                trailing: const Icon(Icons.chevron_right_rounded),
              ),

              if (index < visibleCount - 1)
                const Divider(height: 1, indent: 76),
            ],
          );
        }),
      ),
    );
  }

  // ============================================================
  // UPCOMING
  // ============================================================

  Widget _buildUpcoming() {
    if (_upcomingAssessments.isEmpty) {
      return Container(
        width: double.infinity,

        padding: const EdgeInsets.all(24),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: borderColor),
        ),

        child: const Column(
          children: [
            Icon(Icons.event_available_outlined, color: green, size: 35),

            SizedBox(height: 10),

            Text(
              'No upcoming assessments.',

              style: TextStyle(color: textDark, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _upcomingAssessments.map((assessment) {
        final String type = (assessment['assessmentType'] ?? 'assessment')
            .toString();

        final DateTime? dueAt = _dateFrom(assessment['dueAt']);

        final Color typeColor = _assessmentColor(type);

        return Container(
          width: double.infinity,

          margin: const EdgeInsets.only(bottom: 10),

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(17),

            border: Border.all(color: borderColor),
          ),

          child: Row(
            children: [
              Container(
                width: 44,

                height: 44,

                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(_assessmentIcon(type), color: typeColor),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      (assessment['title'] ?? 'Assessment').toString(),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        color: textDark,

                        fontSize: 13,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      [
                            (assessment['courseCode'] ?? '').toString(),

                            if (dueAt != null)
                              '${_formatDate(dueAt)} \u2022 ${_formatTime(dueAt)}',
                          ]
                          .where((value) => value.trim().isNotEmpty)
                          .join('  \u2022  '),

                      style: const TextStyle(color: textGrey, fontSize: 10.5),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded, color: textGrey),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return SizedBox(
      height: 500,

      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 48),

              const SizedBox(height: 12),

              Text(
                _errorMessage ?? 'Unable to load dashboard.',

                textAlign: TextAlign.center,

                style: const TextStyle(color: textGrey),
              ),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: _loadDashboard,

                icon: const Icon(Icons.refresh_rounded, color: Colors.white),

                label: const Text(
                  'Try Again',

                  style: TextStyle(color: Colors.white),
                ),

                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION-CODE ENROLLMENT
//
// This is deliberately its OWN StatefulWidget.
//
// We do NOT use StatefulBuilder for the Firestore operation.
// ============================================================

// Kept temporarily for compatibility with older compiled routes. New
// enrollment is handled exclusively by StudentCourseInvitationsScreen.
// ignore: unused_element
class _JoinClassSheet extends StatefulWidget {
  final EnrollmentService enrollmentService;

  const _JoinClassSheet({required this.enrollmentService});

  @override
  State<_JoinClassSheet> createState() => _JoinClassSheetState();
}

class _JoinClassSheetState extends State<_JoinClassSheet> {
  static const Color primaryBlue = Color(0xFF1769FF);

  static const Color background = Color(0xFFF8FAFD);

  static const Color textDark = Color(0xFF111827);

  static const Color textGrey = Color(0xFF6B7280);

  final TextEditingController _codeController = TextEditingController();

  bool _isSubmitting = false;

  String? _error;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _codeController.dispose();

    super.dispose();
  }

  // ============================================================
  // JOIN
  // ============================================================

  Future<void> _join() async {
    if (_isSubmitting) {
      return;
    }

    final String classCode = _codeController.text.trim();

    if (classCode.isEmpty) {
      setState(() {
        _error = 'Enter the class code provided by your instructor.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;

      _error = null;
    });

    try {
      final Map<String, dynamic> course = await widget.enrollmentService
          .joinClass(classCode: classCode);

      if (!mounted) {
        return;
      }

      // IMPORTANT:
      // Return the course only.
      //
      // The dashboard refresh happens outside this widget.
      Navigator.of(context).pop(course);
    } on EnrollmentServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;

        _error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;

        _error = 'Unable to join this class.';
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,

      child: Container(
        padding: EdgeInsets.only(
          left: 22,

          right: 22,

          top: 12,

          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
        ),

        decoration: const BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),

            topRight: Radius.circular(28),
          ),
        ),

        child: SafeArea(
          top: false,

          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Center(
                  child: Container(
                    width: 42,

                    height: 5,

                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DEE7),

                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Join a Class',

                        style: TextStyle(
                          color: textDark,

                          fontSize: 21,

                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },

                      icon: const Icon(Icons.close_rounded, color: textDark),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Enter the class code provided by your instructor.',

                  style: TextStyle(color: textGrey, fontSize: 13, height: 1.5),
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: _codeController,

                  enabled: !_isSubmitting,

                  textCapitalization: TextCapitalization.characters,

                  textInputAction: TextInputAction.done,

                  onSubmitted: (_) {
                    if (!_isSubmitting) {
                      _join();
                    }
                  },

                  decoration: InputDecoration(
                    labelText: 'Class Code',

                    hintText: 'Enter instructor class code',

                    prefixIcon: const Icon(
                      Icons.vpn_key_outlined,

                      color: primaryBlue,
                    ),

                    errorText: _error,

                    filled: true,

                    fillColor: background,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 17,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(color: Color(0xFFE1E5EC)),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(
                        color: primaryBlue,

                        width: 1.5,
                      ),
                    ),

                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),

                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(
                        color: Colors.redAccent,

                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,

                  height: 54,

                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _join,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,

                      disabledBackgroundColor: primaryBlue.withValues(
                        alpha: 0.55,
                      ),

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,

                            height: 22,

                            child: CircularProgressIndicator(
                              color: Colors.white,

                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Join Class',

                            style: TextStyle(
                              color: Colors.white,

                              fontWeight: FontWeight.w800,

                              fontSize: 15,
                            ),
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
}
