import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/student_assessment_query_service.dart';

import '../instructor/notifications_page.dart';
import 'student_course_invitations_page.dart';
import 'student_notes.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const StudentDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // Clean blue / glass visual system.
  static const Color primaryBlue = Color(0xFF2864F0);
  static const Color background = Color(0xFFEAF1FF);
  static const Color textDark = Color(0xFF101B42);
  static const Color textGrey = Color(0xFF64719A);
  static const Color orange = Color(0xFFF49A36);
  static const Color green = Color(0xFF20A878);
  static const Color purple = Color(0xFF8065E8);
  static const Color red = Color(0xFFEF535B);

  final EnrollmentService _enrollmentService = EnrollmentService();
  final StudentAssessmentQueryService _assessmentQuery =
      StudentAssessmentQueryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _upcomingAssessments = [];
  int _pendingTaskCount = 0;
  int _announcementCount = 0;
  int _unreadNotificationCount = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    final int generation = ++_loadGeneration;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> student = await _enrollmentService
          .getCurrentStudentProfile();
      final List<Map<String, dynamic>> courses = await _enrollmentService
          .getMyActiveCourses();
      final String studentId = _auth.currentUser?.uid ?? '';
      if (studentId.isEmpty) {
        throw EnrollmentServiceException('No student is currently logged in.');
      }

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
        if (assessmentId.isEmpty) continue;
        submissionByAssessmentId[assessmentId] = {
          ...data,
          'id': document.id,
          'submissionId': document.id,
        };
      }

      final List<Map<String, dynamic>> pendingAssessments = [];
      for (final course in courses) {
        final String courseId = (course['courseId'] ?? course['id'] ?? '')
            .toString()
            .trim();
        if (courseId.isEmpty) continue;
        final assessmentDocuments = await _assessmentQuery
            .getVisibleAssessments(courseId: courseId);
        for (final document in assessmentDocuments) {
          final Map<String, dynamic> assessment = document.data();
          final String status = (assessment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (status != 'published') continue;
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

      pendingAssessments.sort((a, b) {
        final DateTime? first = _dateFrom(a['dueAt']);
        final DateTime? second = _dateFrom(b['dueAt']);
        if (first == null && second == null) return 0;
        if (first == null) return 1;
        if (second == null) return -1;
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

      final announcementIds = <String>{};
      final allClassAnnouncements = await _firestore
          .collection('announcements')
          .where('status', isEqualTo: 'published')
          .where('targetType', isEqualTo: 'all_classes')
          .where('targetRole', isEqualTo: 'student')
          .where('createdByRole', isEqualTo: 'admin')
          .get();
      announcementIds.addAll(allClassAnnouncements.docs.map((doc) => doc.id));
      for (final course in courses) {
        final String courseId = (course['courseId'] ?? course['id'] ?? '')
            .toString()
            .trim();
        if (courseId.isEmpty) continue;
        final QuerySnapshot<Map<String, dynamic>> announcementSnapshot =
            await _firestore
                .collection('announcements')
                .where('status', isEqualTo: 'published')
                .where('targetType', isEqualTo: 'course')
                .where('targetRole', isEqualTo: 'student')
                .where('courseId', isEqualTo: courseId)
                .get();
        announcementIds.addAll(announcementSnapshot.docs.map((doc) => doc.id));
      }
      final int announcementCount = announcementIds.length;

      final QuerySnapshot<Map<String, dynamic>> notificationSnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: studentId)
              .get();
      int unreadNotifications = 0;
      for (final document in notificationSnapshot.docs) {
        if (document.data()['isRead'] != true) unreadNotifications++;
      }

      if (!mounted || generation != _loadGeneration) return;
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
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } on FirebaseException catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load dashboard.';
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load student dashboard.';
      });
    }
  }

  String get _studentName {
    final String name = (_student?['name'] ?? _student?['displayName'] ?? '')
        .toString()
        .trim();
    return name.isNotEmpty ? name : 'Student';
  }

  String get _firstName => _studentName.split(RegExp(r'\s+')).first;
  String get _studentInitial =>
      _studentName.isEmpty ? '?' : _studentName.trim()[0].toUpperCase();

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(DateTime value) {
    const months = [
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
    final date = value.toLocal();
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime value) {
    final date = value.toLocal();
    int hour = date.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _openCourseInvitations() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StudentCourseInvitationsScreen(),
      ),
    );
    if (!mounted) return;
    await _loadDashboard(showLoading: false);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    if (!mounted) return;
    await _loadDashboard(showLoading: false);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const _DashboardBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              color: primaryBlue,
              onRefresh: () => _loadDashboard(showLoading: false),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool desktop = constraints.maxWidth >= 850;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 42 : 18,
                      desktop ? 28 : 16,
                      desktop ? 42 : 18,
                      32,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _buildContent(desktop: desktop),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({required bool desktop}) {
    if (_isLoading) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: CircularProgressIndicator(
            color: primaryBlue,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_errorMessage != null) return _buildError();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        SizedBox(height: desktop ? 30 : 22),
        _buildWelcomeBanner(),
        SizedBox(height: desktop ? 22 : 16),
        _buildStatistics(desktop: desktop),
        SizedBox(height: desktop ? 30 : 24),
        StudentNotesDashboardSection(
          onOpenNotes: () => widget.onNavigateToTab?.call(9),
        ),
        SizedBox(height: desktop ? 30 : 24),
        _buildSectionHeader(
          title: 'Upcoming Assessments',
          action: 'View All',
          onTap: () => widget.onNavigateToTab?.call(2),
          icon: Icons.calendar_month_rounded,
        ),
        const SizedBox(height: 12),
        _buildUpcoming(),
        SizedBox(height: desktop ? 26 : 22),
        _buildSectionHeader(
          title: 'My Courses',
          action: 'View All',
          onTap: () => widget.onNavigateToTab?.call(1),
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: 12),
        _buildClasses(desktop: desktop),
        const SizedBox(height: 16),
        _buildActionButtons(desktop: desktop),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .64),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4776D9).withValues(alpha: .12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: primaryBlue, size: 30),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Text(
            'CASLMS',
            style: TextStyle(
              color: textDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),
        ),
        _GlassIconButton(
          icon: Icons.notifications_none_rounded,
          badge: _unreadNotificationCount,
          onTap: _openNotifications,
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => widget.onNavigateToTab?.call(4),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .68),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .9)),
            ),
            child: Text(
              _studentInitial,
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeBanner() {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF70A4FF).withValues(alpha: .12),
              ),
            ),
          ),
          Row(
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
                        color: textDark,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _pendingTaskCount == 0
                          ? 'You are all caught up. Keep learning! ✨'
                          : 'You have $_pendingTaskCount ${_pendingTaskCount == 1 ? 'task' : 'tasks'} waiting for you.',
                      style: const TextStyle(
                        color: textGrey,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E8BFF), Color(0xFF2864F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: .22),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics({required bool desktop}) {
    final items = [
      _StatData(
        'Active Courses',
        '${_courses.length}',
        Icons.menu_book_rounded,
        primaryBlue,
      ),
      _StatData(
        'Upcoming Assessments',
        '${_upcomingAssessments.length}',
        Icons.calendar_month_rounded,
        orange,
      ),
      _StatData(
        'Pending Tasks',
        '$_pendingTaskCount',
        Icons.check_circle_rounded,
        green,
      ),
      _StatData(
        'Announcements',
        '$_announcementCount',
        Icons.campaign_rounded,
        purple,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 480
            ? 2
            : 2;
        final double spacing = 12;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(width: width, child: _buildStatCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(_StatData item) {
    return _GlassPanel(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 28),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: const TextStyle(
              color: textDark,
              fontSize: 27,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textGrey,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String action,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
          iconAlignment: IconAlignment.end,
          label: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        ),
      ],
    );
  }

  Widget _buildUpcoming() {
    if (_upcomingAssessments.isEmpty) {
      return _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: const Row(
          children: [
            Icon(Icons.event_available_rounded, color: green, size: 28),
            SizedBox(width: 13),
            Expanded(
              child: Text(
                'No upcoming assessments.',
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _GlassPanel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: List.generate(_upcomingAssessments.length, (index) {
          final assessment = _upcomingAssessments[index];
          final String type = (assessment['assessmentType'] ?? 'assessment')
              .toString();
          final DateTime? dueAt = _dateFrom(assessment['dueAt']);
          final Color typeColor = _assessmentColor(type);
          final String courseCode = (assessment['courseCode'] ?? '')
              .toString()
              .trim();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_assessmentIcon(type), color: typeColor),
                    ),
                    const SizedBox(width: 13),
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
                          const SizedBox(height: 5),
                          Text(
                            [
                              courseCode,
                              if (dueAt != null)
                                '${_formatDate(dueAt)} · ${_formatTime(dueAt)}',
                            ].where((value) => value.isNotEmpty).join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textGrey,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .62),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: textGrey,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              if (index != _upcomingAssessments.length - 1)
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: .85),
                  indent: 60,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildClasses({required bool desktop}) {
    if (_courses.isEmpty) {
      return _GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(24),
        child: const Column(
          children: [
            Icon(Icons.school_outlined, color: primaryBlue, size: 34),
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

    final visibleCount = _courses.length > 6 ? 6 : _courses.length;
    final palettes = [
      const [Color(0xFF174B9A), Color(0xFF2864C8)],
      const [Color(0xFF49308C), Color(0xFF7356C6)],
      const [Color(0xFF075D60), Color(0xFF168D83)],
      const [Color(0xFF334C83), Color(0xFF5579B9)],
    ];
    final courseCards = List.generate(visibleCount, (index) {
      final course = _courses[index];
      final String courseCode = (course['code'] ?? 'Course').toString();
      final String courseTitle = (course['title'] ?? '').toString();
      final String instructor = (course['instructorName'] ?? '').toString();
      final colors = palettes[index % palettes.length];
      return InkWell(
        onTap: () => widget.onNavigateToTab?.call(1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 176,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -36,
                top: -43,
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .10),
                      width: 22,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          index % 3 == 0
                              ? Icons.code_rounded
                              : index % 3 == 1
                              ? Icons.language_rounded
                              : Icons.phone_android_rounded,
                          color: Colors.white.withValues(alpha: .88),
                          size: 25,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              color: Color(0xFF7DE4B0),
                              size: 7,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    courseTitle.isNotEmpty ? courseTitle : courseCode,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xBFFFFFFF),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            courseCode,
                            if (instructor.trim().isNotEmpty) instructor,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xDFFFFFFF),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });

    if (desktop) {
      return _GlassPanel(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: courseCards,
        ),
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: courseCards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) =>
            SizedBox(width: 245, child: courseCards[index]),
      ),
    );
  }

  Widget _buildActionButtons({required bool desktop}) {
    final actions = [
      _ActionButton(
        label: 'Course Invitations',
        icon: Icons.mail_outline_rounded,
        primary: true,
        onTap: _openCourseInvitations,
      ),
      _ActionButton(
        label: 'My Notes',
        icon: Icons.sticky_note_2_outlined,
        primary: false,
        onTap: () => widget.onNavigateToTab?.call(9),
      ),
    ];
    return Flex(
      direction: desktop ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < actions.length; index++) ...[
          if (desktop) Expanded(child: actions[index]) else actions[index],
          if (index != actions.length - 1)
            SizedBox(width: desktop ? 12 : 0, height: desktop ? 0 : 10),
        ],
      ],
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 500,
      child: Center(
        child: _GlassPanel(
          radius: 24,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 44),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to load dashboard.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGrey, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(backgroundColor: primaryBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFDCE8FF), Color(0xFFF5F7FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -170,
              right: -100,
              child: _GlowOrb(size: 430, color: Color(0x665C94FF)),
            ),
            Positioned(
              top: 260,
              left: -210,
              child: _GlowOrb(size: 430, color: Color(0x557EAFFF)),
            ),
            Positioned(
              bottom: -250,
              right: -100,
              child: _GlowOrb(size: 500, color: Color(0x447B8BFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .56),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .78)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D7DBA).withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _GlassIconButton({
    required this.icon,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, color: const Color(0xFF101B42), size: 23),
            if (badge > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF535B),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
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
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: primary
            ? const Color(0xFF2864F0)
            : Colors.white.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: primary
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: .9),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: primary ? Colors.white : const Color(0xFF2864F0),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? Colors.white : const Color(0xFF2864F0),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
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
