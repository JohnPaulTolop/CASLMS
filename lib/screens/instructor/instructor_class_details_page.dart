import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/course_invitation_service.dart';
import 'instructor_ui.dart';

import 'instructor_chat_page.dart';
import 'instructor_module_builder_page.dart';
import 'instructor_module_detail_page.dart';

class InstructorClassDetailsScreen extends StatefulWidget {
  // ============================================================
  // DYNAMIC COURSE PARAMETERS
  // ============================================================

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String classCode;
  final String instructorName;

  // ============================================================
  // LEGACY PARAMETERS
  // ============================================================

  final String title;
  final String section;
  final int? studentCount;
  final Map<String, dynamic>? course;

  const InstructorClassDetailsScreen({
    super.key,
    this.courseId = '',
    this.courseCode = '',
    this.courseTitle = '',
    this.classCode = '',
    this.instructorName = '',
    this.title = '',
    this.section = '',
    this.studentCount,
    this.course,
  });

  @override
  State<InstructorClassDetailsScreen> createState() =>
      _InstructorClassDetailsScreenState();
}

class _InstructorClassDetailsScreenState
    extends State<InstructorClassDetailsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color teal = Color(0xFF00897B);
  static const Color darkTeal = Color(0xFF00695C);
  static const Color background = Color(0xFFF5F8FC);
  static const Color heading = Color(0xFF172B4D);
  static const Color secondaryText = Color(0xFF6B7C93);
  static const Color borderColor = Color(0xFFE5ECF3);

  static const Color red = Color(0xFFFF4B4B);
  static const Color orange = Color(0xFFFF9418);
  static const Color green = Color(0xFF26A65B);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CourseInvitationService _invitationService = CourseInvitationService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  String? _errorMessage;

  bool _overviewExpanded = false;

  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _courseInvitations = [];
  final Set<String> _busyInvitationIds = {};
  bool _isSendingInvitation = false;
  List<Map<String, dynamic>> _assessments = [];
  List<Map<String, dynamic>> _assessmentSubmissions = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  // ============================================================
  // RESOLVE REAL COURSE ID
  // ============================================================

  Future<String> _resolveCourseId() async {
    final String directId = widget.courseId.trim();
    if (directId.isNotEmpty) return directId;

    final String mapId =
        (widget.course?['courseId'] ?? widget.course?['id'] ?? '')
            .toString()
            .trim();
    if (mapId.isNotEmpty) return mapId;

    final String? instructorId = _auth.currentUser?.uid;
    if (instructorId == null || instructorId.isEmpty) {
      throw Exception('You must be logged in as an instructor.');
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('courses')
        .where('instructorId', isEqualTo: instructorId)
        .get();

    final String requestedCode = widget.courseCode.trim().toLowerCase();
    final String requestedTitle =
        (widget.courseTitle.trim().isNotEmpty
                ? widget.courseTitle
                : widget.title)
            .trim()
            .toLowerCase();

    for (final document in snapshot.docs) {
      final Map<String, dynamic> data = document.data();
      final String code = (data['code'] ?? '').toString().trim().toLowerCase();
      final String title = (data['title'] ?? '').toString().trim().toLowerCase();

      if (requestedCode.isNotEmpty && code == requestedCode) return document.id;
      if (requestedTitle.isNotEmpty && title == requestedTitle) return document.id;
    }

    throw Exception('The selected course could not be found in Firestore.');
  }

  // ============================================================
  // LOAD COURSE
  // ============================================================

  Future<void> _loadCourseData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String? instructorId = _auth.currentUser?.uid;

      if (instructorId == null || instructorId.isEmpty) {
        throw Exception('No instructor is currently logged in.');
      }

      final String courseId = await _resolveCourseId();

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await _firestore.collection('courses').doc(courseId).get();

      if (!courseDocument.exists || courseDocument.data() == null) {
        throw Exception('Course could not be found.');
      }

      final Map<String, dynamic> courseData = courseDocument.data()!;
      final String ownerId = (courseData['instructorId'] ?? '').toString().trim();

      if (ownerId != instructorId) {
        throw Exception('You can only manage your own courses.');
      }

      final QuerySnapshot<Map<String, dynamic>> moduleSnapshot =
          await _firestore
              .collection('modules')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> modules = moduleSnapshot.docs
          .map((document) => {
                ...document.data(),
                'id': document.id,
                'moduleId': document.id,
              })
          .toList();

      modules.sort((a, b) {
        final int aOrder = (a['order'] as num?)?.toInt() ?? 0;
        final int bOrder = (b['order'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> students = [];

      for (final enrollmentDocument in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollment = enrollmentDocument.data();
        final String enrollmentStatus =
            (enrollment['status'] ?? '').toString().trim().toLowerCase();

        if (enrollmentStatus != 'active') continue;

        final String studentId =
            (enrollment['studentId'] ?? '').toString().trim();

        if (studentId.isEmpty) continue;

        Map<String, dynamic>? userData;
        try {
          final DocumentSnapshot<Map<String, dynamic>> userDocument =
              await _firestore.collection('users').doc(studentId).get();
          userData = userDocument.data();
        } catch (_) {
          userData = null;
        }

        students.add({
          ...enrollment,
          if (userData != null) ...userData,
          'studentId': studentId,
          'enrollmentId': enrollmentDocument.id,
        });
      }

      students.sort((a, b) {
        final String aName = (a['name'] ?? a['studentName'] ?? '')
            .toString()
            .toLowerCase();
        final String bName = (b['name'] ?? b['studentName'] ?? '')
            .toString()
            .toLowerCase();
        return aName.compareTo(bName);
      });

      final List<Map<String, dynamic>> courseInvitations =
          await _invitationService.getCourseInvitations(courseId: courseId);

      final QuerySnapshot<Map<String, dynamic>> assessmentSnapshot =
          await _firestore
              .collection('assessments')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> assessments = assessmentSnapshot.docs
          .map((document) => {
                ...document.data(),
                'id': document.id,
                'assessmentId': document.id,
              })
          .toList();

      final QuerySnapshot<Map<String, dynamic>> submissionSnapshot =
          await _firestore
              .collection('assessmentSubmissions')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> assessmentSubmissions =
          submissionSnapshot.docs
              .map((document) => {
                    ...document.data(),
                    'id': document.id,
                    'submissionId': document.id,
                  })
              .toList();

      if (!mounted) return;

      setState(() {
        _course = {
          ...courseData,
          'id': courseDocument.id,
          'courseId': courseDocument.id,
        };
        _modules = modules;
        _students = students;
        _courseInvitations = courseInvitations;
        _assessments = assessments;
        _assessmentSubmissions = assessmentSubmissions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // DYNAMIC VALUES
  // ============================================================

  String get _courseId =>
      (_course?['courseId'] ?? _course?['id'] ?? widget.courseId)
          .toString()
          .trim();

  String get _courseCode =>
      (_course?['code'] ?? widget.courseCode).toString().trim();

  String get _courseTitle => (_course?['title'] ??
          (widget.courseTitle.isNotEmpty ? widget.courseTitle : widget.title))
      .toString()
      .trim();

  String get _classCode => (_course?['classCode'] ??
          (widget.classCode.isNotEmpty ? widget.classCode : widget.section))
      .toString()
      .trim();

  String get _semester => (_course?['semester'] ?? '').toString().trim();

  String get _academicYear => (_course?['academicYear'] ?? '').toString().trim();

  String get _courseDescription =>
      (_course?['description'] ?? '').toString().trim();

  String get _instructorName =>
      (_course?['instructorName'] ?? widget.instructorName).toString().trim();

  String get _courseStatus =>
      (_course?['status'] ?? '').toString().trim().toLowerCase();

  // ============================================================
  // COURSE ACTIONS
  // ============================================================

  Future<void> _createModule() async {
    if (_courseId.isEmpty) {
      _showError('Course information is missing.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorModuleBuilderScreen(
          courseId: _courseId,
          courseCode: _courseCode,
          courseTitle: _courseTitle,
        ),
      ),
    );

    if (mounted) await _loadCourseData();
  }

  Future<void> _openModule(Map<String, dynamic> module) async {
    final String moduleId =
        (module['moduleId'] ?? module['id'] ?? '').toString().trim();

    if (moduleId.isEmpty || _courseId.isEmpty) {
      _showError('Unable to open this module because its ID information is missing.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorModuleDetailScreen(
          courseId: _courseId,
          moduleId: moduleId,
          courseCode: _courseCode,
          courseTitle: _courseTitle,
          moduleTitle: (module['title'] ?? '').toString(),
        ),
      ),
    );

    if (mounted) await _loadCourseData();
  }

  Future<void> _openStudentChat(Map<String, dynamic> student) async {
    final String studentId =
        (student['studentId'] ?? student['uid'] ?? '').toString().trim();
    final String studentName =
        (student['name'] ?? student['studentName'] ?? '').toString().trim();
    final String studentEmail = (student['email'] ?? '').toString().trim();
    final String? instructorId = _auth.currentUser?.uid;

    if (studentId.isEmpty) {
      _showError('Student ID is missing.');
      return;
    }

    if (instructorId == null || instructorId.isEmpty) {
      _showError('Instructor account information is missing.');
      return;
    }

    if (_courseId.isEmpty) {
      _showError('Course information is missing.');
      return;
    }

    if (_instructorName.isEmpty) {
      _showError('Instructor name is missing.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorChatScreen(
          courseId: _courseId,
          instructorId: instructorId,
          instructorName: _instructorName,
          studentId: studentId,
          studentName: studentName.isEmpty ? studentEmail : studentName,
          studentEmail: studentEmail,
        ),
      ),
    );
  }

  Future<void> _inviteStudent() async {
    if (_isSendingInvitation || _courseId.isEmpty) return;

    final String? campusId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _InviteStudentDialog(),
    );

    if (!mounted || campusId == null || campusId.trim().isEmpty) return;

    setState(() => _isSendingInvitation = true);

    try {
      final invitation = await _invitationService.inviteStudentByCampusId(
        courseId: _courseId,
        campusId: campusId,
      );

      if (!mounted) return;

      final String studentName =
          (invitation['studentName'] ?? invitation['studentCampusId'] ?? '')
              .toString()
              .trim();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              studentName.isEmpty
                  ? 'Course invitation sent.'
                  : 'Invitation sent to $studentName.',
            ),
            backgroundColor: green,
            behavior: SnackBarBehavior.floating,
          ),
        );

      await _loadCourseData();
    } on CourseInvitationException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to send the course invitation.');
    } finally {
      if (mounted) setState(() => _isSendingInvitation = false);
    }
  }

  Future<void> _cancelInvitation(Map<String, dynamic> invitation) async {
    final String invitationId =
        (invitation['invitationId'] ?? invitation['id'] ?? '').toString().trim();
    if (invitationId.isEmpty || _busyInvitationIds.contains(invitationId)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel invitation?'),
        content: Text(
          'Cancel the invitation for '
          '${(invitation['studentName'] ?? invitation['studentCampusId'] ?? 'this student').toString()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Invitation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: red),
            child: const Text('Cancel Invitation'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    setState(() => _busyInvitationIds.add(invitationId));

    try {
      await _invitationService.cancelInvitation(invitationId);
      if (!mounted) return;
      await _loadCourseData();
    } on CourseInvitationException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Unable to cancel the invitation.');
    } finally {
      if (mounted) {
        setState(() => _busyInvitationIds.remove(invitationId));
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // SHARED DESIGN COMPONENTS
  // ============================================================

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }

  Widget _pill(
    String label, {
    Color color = teal,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: darkTeal, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadingAvatar(String name, IconData fallbackIcon, {Color color = teal}) {
    final displayName = name.trim();

    if (displayName.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(fallbackIcon, color: color, size: 22),
      );
    }

    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _contentCard({
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: teal),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COLLAPSIBLE OVERVIEW
  // ============================================================

  Widget _buildCollapsibleOverview() {
    final bool isActive = _courseStatus == 'active';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _overviewExpanded = !_overviewExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00796B), Color(0xFF26A69A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.co_present_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _courseTitle.isEmpty ? 'Class workspace' : _courseTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: heading,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_students.length} students'
                          '${_courseCode.isNotEmpty ? ' • $_courseCode' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFE3F6EF)
                          : const Color(0xFFFFF1DB),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _courseStatus.isEmpty ? 'Unknown' : _courseStatus.toUpperCase(),
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF13805D)
                            : const Color(0xFF9A6B13),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _overviewExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: secondaryText,
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _overviewExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: borderColor, height: 1),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_classCode.isNotEmpty)
                        _overviewChip(Icons.key_rounded, _classCode),
                      if (_semester.isNotEmpty)
                        _overviewChip(Icons.calendar_today_outlined, _semester),
                      if (_academicYear.isNotEmpty)
                        _overviewChip(Icons.school_outlined, _academicYear),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _compactStat(
                          'Students',
                          '${_students.length}',
                          Icons.people_alt_outlined,
                          teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactStat(
                          'Modules',
                          '${_modules.length}',
                          Icons.menu_book_outlined,
                          teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactStat(
                          'Assessments',
                          '${_assessments.length}',
                          Icons.assignment_outlined,
                          teal,
                        ),
                      ),
                    ],
                  ),
                  if (_courseDescription.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _courseDescription,
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox(
              width: double.infinity,
              height: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: instructorScaffold(
        context: context,
        backgroundColor: background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: heading,
            ),
          ),
          title: const Text(
            'Course Details',
            style: TextStyle(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh course',
              onPressed: _loadCourseData,
              icon: const Icon(Icons.refresh_rounded, color: teal),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: borderColor),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: teal));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _buildCollapsibleOverview(),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: const TabBar(
                  isScrollable: false,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Color(0xFFE4F5F1),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                  labelColor: darkTeal,
                  unselectedLabelColor: secondaryText,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(height: 36, text: 'Roster'),
                    Tab(height: 36, text: 'Modules'),
                    Tab(height: 36, text: 'Grades'),
                    Tab(height: 36, text: 'Settings'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRosterTab(),
                    _buildModulesTab(),
                    _buildGradesTab(),
                    _buildSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB CONTENTS
  // ============================================================

  Widget _buildRosterTab() {
    final List<Map<String, dynamic>> pendingInvitations = _courseInvitations
        .where((invitation) =>
            (invitation['status'] ?? '').toString().toLowerCase() == 'pending')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        if (pendingInvitations.isNotEmpty) ...[
          _buildPendingInvitations(pendingInvitations),
          const SizedBox(height: 18),
        ],
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Student Roster',
                'Students currently enrolled in this course.',
                trailing: FilledButton.icon(
                  onPressed: _isSendingInvitation ? null : _inviteStudent,
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSendingInvitation
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: Text(_isSendingInvitation ? 'Sending...' : 'Invite'),
                ),
              ),
              const SizedBox(height: 18),
              if (_students.isEmpty)
                _emptyState(
                  icon: Icons.group_outlined,
                  title: 'No students enrolled',
                  message:
                      'Invite students using their registered Campus ID. They will appear here after accepting.',
                )
              else
                ..._students.map((student) {
                  final String name =
                      (student['name'] ?? student['studentName'] ?? '').toString().trim();
                  final String email = (student['email'] ?? '').toString().trim();
                  final String universityId =
                      (student['universityId'] ?? '').toString().trim();
                  final String displayName = name.isNotEmpty ? name : universityId;

                  return _contentCard(
                    leading: _leadingAvatar(displayName, Icons.person_outline),
                    title: displayName.isNotEmpty ? displayName : email,
                    subtitle: [
                      if (email.isNotEmpty) email,
                      if (universityId.isNotEmpty) 'Campus ID: $universityId'
                    ].join('\n'),
                    trailing: IconButton(
                      tooltip: 'Message student',
                      onPressed: () => _openStudentChat(student),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: teal,
                        size: 20,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingInvitations(List<Map<String, dynamic>> invitations) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outgoing_mail, color: orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '${invitations.length} pending '
                '${invitations.length == 1 ? 'invitation' : 'invitations'}',
                style: const TextStyle(
                  color: heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...invitations.map((invitation) {
            final String invitationId =
                (invitation['invitationId'] ?? invitation['id'] ?? '').toString().trim();
            final String studentName =
                (invitation['studentName'] ?? 'Student').toString().trim();
            final String campusId =
                (invitation['studentCampusId'] ?? '').toString().trim();
            final bool busy = _busyInvitationIds.contains(invitationId);

            return _contentCard(
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFFFF2DF),
                child: Icon(Icons.schedule_rounded, color: orange, size: 17),
              ),
              title: studentName.isEmpty ? campusId : studentName,
              subtitle: campusId.isNotEmpty ? 'Campus ID: $campusId' : 'Pending response',
              trailing: TextButton(
                onPressed: busy ? null : () => _cancelInvitation(invitation),
                child: Text(busy ? 'Cancelling...' : 'Cancel', style: const TextStyle(color: red)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModulesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Course Modules',
                'Open a module to manage its assessments.',
                trailing: FilledButton.icon(
                  onPressed: _createModule,
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Module'),
                ),
              ),
              const SizedBox(height: 18),
              if (_modules.isEmpty)
                _emptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No modules yet',
                  message: 'Create the first module for this course.',
                )
              else
                ..._modules.map((module) {
                  final String title = (module['title'] ?? '').toString().trim();
                  final String description =
                      (module['description'] ?? '').toString().trim();
                  final String status =
                      (module['status'] ?? 'draft').toString().trim().toLowerCase();
                  final int order = (module['order'] as num?)?.toInt() ?? 0;
                  final String moduleId =
                      (module['moduleId'] ?? module['id'] ?? '').toString();

                  final int assessmentCount = _assessments.where((assessment) {
                    return (assessment['moduleId'] ?? '').toString() == moduleId;
                  }).length;

                  final bool published = status == 'published';
                  final Color statusColor = published ? green : orange;

                  return _contentCard(
                    leading: _leadingAvatar('', Icons.menu_book_rounded),
                    title: order > 0
                        ? 'MODULE $order: ${title.isEmpty ? 'Untitled' : title}'
                        : (title.isEmpty ? 'Untitled' : title),
                    subtitle: [
                      if (description.isNotEmpty) description,
                      'Assessments: $assessmentCount • Status: ${status.toUpperCase()}'
                    ].join('\n'),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: secondaryText,
                    ),
                    onTap: () => _openModule(module),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradesTab() {
    final int submitted = _assessmentSubmissions.where((submission) {
      final String status = (submission['status'] ?? '').toString().toLowerCase();
      return status == 'submitted';
    }).length;

    final int graded = _assessmentSubmissions.where((submission) {
      return (submission['status'] ?? '').toString().toLowerCase() == 'graded';
    }).length;

    final int published = _assessments.where((assessment) {
      return (assessment['status'] ?? '').toString().toLowerCase() == 'published';
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _compactStat(
                'Published',
                '$published',
                Icons.assignment_turned_in_outlined,
                teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactStat(
                'To Grade',
                '$submitted',
                Icons.pending_actions_rounded,
                orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _compactStat(
                'Graded',
                '$graded',
                Icons.verified_outlined,
                green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Assessment Grading',
                'External assessment submissions and grades.',
              ),
              const SizedBox(height: 14),
              if (_assessmentSubmissions.isEmpty)
                _emptyState(
                  icon: Icons.grade_outlined,
                  title: 'No assessment submissions yet',
                  message:
                      'Student submissions will appear here after the student external-assessment workflow is connected.',
                )
              else
                ..._assessmentSubmissions.map((submission) {
                  final String studentName =
                      (submission['studentName'] ?? '').toString();
                  final String status =
                      (submission['status'] ?? 'submitted').toString().toLowerCase();
                  final dynamic score = submission['score'];
                  final bool isGraded = status == 'graded';

                  return _contentCard(
                    leading: _leadingAvatar(
                        studentName,
                        isGraded
                            ? Icons.check_circle_outline_rounded
                            : Icons.pending_actions_rounded,
                        color: isGraded ? green : orange),
                    title: studentName,
                    subtitle: 'Status: ${status.toUpperCase()}',
                    trailing: Text(
                      score is num ? '$score' : status.toUpperCase(),
                      style: TextStyle(
                        color: isGraded ? green : orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Course Information',
                'Current information stored in Firestore.',
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.tag_rounded,
                      title: 'Course Code',
                      value: _courseCode,
                    ),
                    const Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.key_rounded,
                      title: 'Class Code',
                      value: _classCode,
                    ),
                    const Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Instructor',
                      value: _instructorName,
                    ),
                    const Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Semester',
                      value: _semester,
                    ),
                    const Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.school_outlined,
                      title: 'Academic Year',
                      value: _academicYear,
                    ),
                    const Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.visibility_outlined,
                      title: 'Status',
                      value: _courseStatus.toUpperCase(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
      leading: Icon(icon, color: teal, size: 21),
      title: Text(
        title,
        style: const TextStyle(
          color: heading,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: SizedBox(
        width: 160,
        child: Text(
          value.isEmpty ? '—' : value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _loadCourseData,
      color: teal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 110),
          const Icon(Icons.error_outline_rounded, color: red, size: 50),
          const SizedBox(height: 13),
          Text(
            _errorMessage ?? 'Unable to load course information.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadCourseData,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: teal),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteStudentDialog extends StatefulWidget {
  const _InviteStudentDialog();

  @override
  State<_InviteStudentDialog> createState() => _InviteStudentDialogState();
}

class _InviteStudentDialogState extends State<_InviteStudentDialog> {
  static const Color teal = Color(0xFF00897B);

  final TextEditingController _campusIdController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _campusIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context)
        .pop(_campusIdController.text.trim().replaceAll(RegExp(r'\s+'), ''));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: teal),
          SizedBox(width: 10),
          Expanded(child: Text('Invite Student')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Campus ID registered to the student’s CASLMS account.',
              ),
              const SizedBox(height: 17),
              TextFormField(
                controller: _campusIdController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Student Campus ID',
                  hintText: 'Enter 5–12 digits',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  final campusId = (value ?? '').trim().replaceAll(
                    RegExp(r'\s+'),
                    '',
                  );
                  if (campusId.isEmpty) return 'Enter the student Campus ID.';
                  if (!RegExp(r'^\d{5,12}$').hasMatch(campusId)) {
                    return 'Campus ID must contain 5–12 numeric digits.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'The student must accept the invitation before enrollment becomes active.',
                style: TextStyle(color: Color(0xFF6B7C93), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Send Invitation'),
          style: FilledButton.styleFrom(backgroundColor: teal),
        ),
      ],
    );
  }
}