import '../shared/page_loading_state.dart';
import '../../services/instructor_workspace_context.dart';
import '../../services/course_section_service.dart';
import '../../services/section_audience_service.dart';
import '../../models/course_order.dart';
import '../shared/course_workspace_layout.dart';
import '../shared/workspace_widgets.dart';
import '../shared/live_classes_page.dart';
import '../shared/learner_assistant_page.dart';
import 'instructor_course_sections_page.dart';
import 'instructor_course_content.dart';
import 'instructor_create_assessment_page.dart';
import 'instructor_assessment_grading_page.dart';
import 'instructor_semester_grades_page.dart';
import '../../core/app_colors.dart';

import 'dart:async';

import 'invite_student_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/course_invitation_service.dart';

import 'instructor_chat_page.dart';
import 'instructor_module_builder_page.dart';
import 'instructor_module_detail_page.dart';

class InstructorClassDetailsScreen extends StatefulWidget {
  // ============================================================
  // DYNAMIC COURSE PARAMETERS
  // ============================================================

  final String courseId;
  final String? sectionId;
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
    this.sectionId,
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

  Color get teal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get heading => AppColors.resolve(context, AppColors.darkText);
  Color get secondaryText =>
      AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  Color get red => AppColors.resolve(context, AppColors.error);
  Color get orange => AppColors.resolve(context, AppColors.amber);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CourseInvitationService _invitationService = CourseInvitationService();

  // ============================================================
  // STATE
  // ============================================================

  final List<StreamSubscription> _changes = [];
  String? _watchedCourseId;
  final _context = InstructorWorkspaceContext.instance;
  List<Map<String, dynamic>> _sections = [];
  String? _resolvedCourseId;
  bool _initialSectionApplied = false;
  bool _changingSection = false;
  String? get _sectionId =>
      _context.courseId == _courseId ? _context.sectionId : null;
  Timer? _refreshTimer;
  int _loadGeneration = 0;
  bool _isLoading = true;
  String? _errorMessage;

  final List<Map<String, dynamic>> _materials = [];

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
      final String title = (data['title'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (requestedCode.isNotEmpty && code == requestedCode) return document.id;
      if (requestedTitle.isNotEmpty && title == requestedTitle) {
        return document.id;
      }
    }

    throw Exception('The selected course could not be found in Firestore.');
  }

  // ============================================================
  // LOAD COURSE
  // ============================================================

  Future<void> _loadCourseData({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (mounted && showLoading) {
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
      if (!mounted || generation != _loadGeneration) return;

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await _firestore.collection('courses').doc(courseId).get();

      if (!courseDocument.exists || courseDocument.data() == null) {
        throw Exception('Course could not be found.');
      }

      final Map<String, dynamic> courseData = courseDocument.data()!;
      final String ownerId = (courseData['instructorId'] ?? '')
          .toString()
          .trim();

      if (ownerId != instructorId) {
        throw Exception('You can only manage your own courses.');
      }
      if (!mounted || generation != _loadGeneration) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _resolvedCourseId = courseId;
      final selectionRevision = _context.beginCourse(instructorId, courseId);
      final sections = await CourseSectionService().getSections(courseId);
      if (!mounted ||
          generation != _loadGeneration ||
          _auth.currentUser?.uid != instructorId) {
        return;
      }
      if (!_context.commitSections(
        selectionRevision,
        instructorId,
        courseId,
        sections,
        requested: _initialSectionApplied ? null : widget.sectionId,
      )) {
        return;
      }
      _initialSectionApplied = true;
      _sections = sections.where((row) => row['status'] == 'active').toList();
      _watchChanges(courseId);
      final workspaceSnapshots = await Future.wait([
        _firestore
            .collection('modules')
            .where('courseId', isEqualTo: courseId)
            .get(),
        _firestore
            .collection('enrollments')
            .where('courseId', isEqualTo: courseId)
            .get(),
        _firestore
            .collection('assessments')
            .where('courseId', isEqualTo: courseId)
            .get(),
        _firestore
            .collection('assessmentSubmissions')
            .where('courseId', isEqualTo: courseId)
            .get(),
        _firestore
            .collection('moduleResources')
            .where('courseId', isEqualTo: courseId)
            .get(),
      ]);
      final materialSnapshot = workspaceSnapshots[4];

      final moduleSnapshot = workspaceSnapshots[0];

      final List<Map<String, dynamic>> modules = moduleSnapshot.docs
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'moduleId': document.id,
            },
          )
          .toList();

      modules.sort((a, b) {
        final int aOrder = (a['order'] as num?)?.toInt() ?? 0;
        final int bOrder = (b['order'] as num?)?.toInt() ?? 0;
        return aOrder.compareTo(bOrder);
      });

      final enrollmentSnapshot = workspaceSnapshots[1];

      final List<Map<String, dynamic>> students = [];

      await Future.wait(
        enrollmentSnapshot.docs.map((enrollmentDocument) async {
          final Map<String, dynamic> enrollment = enrollmentDocument.data();
          final String enrollmentStatus = (enrollment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (enrollmentStatus != 'active') return;
          if (_sectionId != null &&
              _sectionId!.isNotEmpty &&
              (enrollment['sectionId'] ?? courseData['classCode'] ?? '') !=
                  _sectionId) {
            return;
          }

          final String studentId = (enrollment['studentId'] ?? '')
              .toString()
              .trim();

          if (studentId.isEmpty) return;

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
            ...?userData,
            'studentId': studentId,
            'enrollmentId': enrollmentDocument.id,
          });
        }),
      );

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

      final assessmentSnapshot = workspaceSnapshots[2];

      final List<Map<String, dynamic>> assessments = assessmentSnapshot.docs
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'assessmentId': document.id,
            },
          )
          .toList();

      final submissionSnapshot = workspaceSnapshots[3];

      final List<Map<String, dynamic>> assessmentSubmissions =
          submissionSnapshot.docs
              .map(
                (document) => {
                  ...document.data(),
                  'id': document.id,
                  'submissionId': document.id,
                },
              )
              .toList();

      if (!mounted || generation != _loadGeneration) return;

      if (_auth.currentUser?.uid != instructorId ||
          _context.courseId != courseId) {
        return;
      }
      setState(() {
        _errorMessage = null;
        _course = {
          ...courseData,
          'id': courseDocument.id,
          'courseId': courseDocument.id,
        };
        _materials
          ..clear()
          ..addAll(
            materialSnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}),
          );
        _materials.sort(
          (a, b) =>
              courseDate(b['createdAt']).compareTo(courseDate(a['createdAt'])),
        );
        _modules = modules;
        _students = students;
        _courseInvitations = courseInvitations
            .where(
              (invitation) =>
                  _sectionId == null ||
                  _sectionId!.isEmpty ||
                  (invitation['sectionId'] ?? courseData['classCode'] ?? '') ==
                      _sectionId,
            )
            .toList();
        _assessments = assessments
            .where(
              (assessment) =>
                  _sectionId == null ||
                  _sectionId!.isEmpty ||
                  (assessment['sectionId'] ?? '').toString().isEmpty ||
                  assessment['sectionId'] == _sectionId,
            )
            .toList();
        _assessmentSubmissions = assessmentSubmissions
            .where(
              (submission) =>
                  _sectionId == null ||
                  _sectionId!.isEmpty ||
                  ((submission['sectionId'] ?? '').toString().isNotEmpty
                      ? submission['sectionId'] == _sectionId
                      : enrollmentSnapshot.docs.any((document) {
                          final enrollment = document.data();
                          return enrollment['studentId'] ==
                                  submission['studentId'] &&
                              (enrollment['sectionId'] ??
                                      courseData['classCode'] ??
                                      '') ==
                                  _sectionId;
                        })),
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _context.clearCourse(_courseId);
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // DYNAMIC VALUES
  // ============================================================

  String get _courseId =>
      (_resolvedCourseId ??
              _course?['courseId'] ??
              _course?['id'] ??
              widget.courseId)
          .toString()
          .trim();

  String get _courseCode =>
      (_course?['code'] ?? widget.courseCode).toString().trim();

  String get _courseTitle =>
      (_course?['title'] ??
              (widget.courseTitle.isNotEmpty
                  ? widget.courseTitle
                  : widget.title))
          .toString()
          .trim();

  String get _semester => (_course?['semester'] ?? '').toString().trim();

  String get _academicYear =>
      (_course?['academicYear'] ?? '').toString().trim();

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
          initialSectionId: _sectionId,
          sections: _sections,
        ),
      ),
    );

    if (mounted) await _loadCourseData(showLoading: false);
  }

  Future<void> _openModule(
    Map<String, dynamic> module, {
    String focusResourceId = '',
    int initialTab = 0,
    String focusAssessmentId = '',
  }) async {
    final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
        .toString()
        .trim();

    if (moduleId.isEmpty || _courseId.isEmpty) {
      _showError(
        'Unable to open this module because its ID information is missing.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorModuleDetailScreen(
          focusResourceId: focusResourceId,
          initialTab: initialTab,
          focusAssessmentId: focusAssessmentId,
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
    final String studentId = (student['studentId'] ?? student['uid'] ?? '')
        .toString()
        .trim();
    final String studentName = (student['name'] ?? student['studentName'] ?? '')
        .toString()
        .trim();
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
    setState(() => _isSendingInvitation = true);
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          InviteStudentDialog(courseId: _courseId, sectionId: _sectionId),
    );
    if (!mounted) return;
    setState(() => _isSendingInvitation = false);
    if (sent == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitation sent. The roster updates when the student accepts.',
          ),
        ),
      );
    }
  }

  void _watchChanges(String courseId) {
    if (_watchedCourseId == courseId) return;
    _watchedCourseId = courseId;
    for (final change in _changes) {
      change.cancel();
    }
    _changes.clear();
    for (final collection in [
      'enrollments',
      'courseInvitations',
      'courseSections',
    ]) {
      _changes.add(
        _firestore
            .collection(collection)
            .where('courseId', isEqualTo: courseId)
            .snapshots()
            .listen(
              (_) {
                _refreshTimer?.cancel();
                _refreshTimer = Timer(const Duration(milliseconds: 180), () {
                  if (mounted && ModalRoute.of(context)?.isCurrent != false) {
                    _loadCourseData(showLoading: false);
                  }
                });
              },
              onError: (Object error) {
                if (mounted) {
                  _showError('Unable to sync the roster. Please refresh.');
                }
              },
            ),
      );
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _refreshTimer?.cancel();
    for (final change in _changes) {
      change.cancel();
    }
    super.dispose();
  }

  Future<void> _cancelInvitation(Map<String, dynamic> invitation) async {
    final String invitationId =
        (invitation['invitationId'] ?? invitation['id'] ?? '')
            .toString()
            .trim();
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _leadingAvatar(
    String name,
    IconData fallbackIcon, {
    Color color = AppColors.primaryBlue,
  }) {
    final displayName = name.trim();

    if (displayName.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          fallbackIcon,
          color: AppColors.resolve(context, color),
          size: 22,
        ),
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
          color: AppColors.resolve(context, color),
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
        color: Theme.of(context).colorScheme.surface,
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
                        style: TextStyle(
                          color: heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
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
              color: AppColors.resolve(context, AppColors.greenTint),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: teal),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COLLAPSIBLE OVERVIEW
  // ============================================================

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course')),
        body: _buildErrorState(),
      );
    }
    return AbsorbPointer(
      absorbing: _changingSection,
      child: CourseWorkspaceLayout(
        title: _courseTitle,
        subtitle: [
          _courseCode,
          _semester,
          _academicYear,
          if (_sectionId?.isNotEmpty == true) 'Section workspace',
        ].where((value) => value.isNotEmpty).join(' • '),
        onRefresh: () => _loadCourseData(showLoading: false),
        toolbarActions: [
          IconButton(
            tooltip: 'Course information',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        const Expanded(child: Text('Course information')),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (_courseDescription.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_courseDescription),
                      ),
                    Expanded(child: _buildSettingsTab()),
                  ],
                ),
              ),
            ),
          ),
        ],
        actions: [
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_sectionId),
              initialValue: _sectionId ?? '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Viewing section',
                filled: true,
                fillColor: AppColors.resolve(
                  context,
                  AppColors.link,
                ).withValues(alpha: .08),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All sections')),
                for (final row in _sections)
                  DropdownMenuItem(
                    value: row['id'].toString(),
                    child: Text(
                      row['name']?.toString() ?? 'Section',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _changingSection
                  ? null
                  : (value) async {
                      final uid = _auth.currentUser?.uid;
                      if (uid == null) return;
                      final revision = _context.beginCourse(uid, _courseId);
                      _context.commitSections(
                        revision,
                        uid,
                        _courseId,
                        _sections,
                        requested: value,
                      );
                      setState(() => _changingSection = true);
                      await _loadCourseData(showLoading: false);
                      if (mounted) setState(() => _changingSection = false);
                    },
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      InstructorCourseSectionsScreen(courseId: _courseId),
                ),
              );
              if (mounted) await _loadCourseData(showLoading: false);
            },
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Sections'),
          ),
          OutlinedButton.icon(
            onPressed: _openLiveClass,
            icon: const Icon(Icons.video_call_outlined),
            label: const Text('Live classroom'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Back to course')),
                  body: LearnerAssistantScreen(
                    role: 'instructor',
                    initialPrompt:
                        'Help me plan a lesson for "$_courseTitle" ($_courseCode).',
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Ask AI'),
          ),
        ],
        labels: const ['Content', 'Activities', 'Grades', 'Students'],
        pages: [
          InstructorCourseContent(
            sectionScoped: _sectionId?.isNotEmpty == true,
            modules: _modules,
            materials: _materials,
            assessments: _assessments,
            onCreate: _createModule,
            onManage: _openModule,
            onMaterial: (module, material) =>
                _openModule(module, focusResourceId: material['id'].toString()),
            onAssessment: _openAssessment,
          ),
          _buildActivitiesTab(),
          _buildGradesTab(),
          _buildRosterTab(),
        ],
      ),
    );
  }

  Future<void> _openLiveClass() async {
    try {
      var sectionId = _sectionId;
      if (sectionId == null || sectionId.isEmpty) {
        final sections = (await CourseSectionService().getSections(_courseId))
            .where((section) => section['status'] != 'archived')
            .toList();
        if (!mounted) return;
        if (sections.isEmpty) {
          _showError(
            'Add an active section before opening the live classroom.',
          );
          return;
        }
        final section = sections.length == 1
            ? sections.first
            : await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Choose a class section',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final section in sections)
                        ListTile(
                          title: Text(
                            (section['name'] ?? 'Section').toString(),
                          ),
                          subtitle: Text(
                            (section['identifier'] ?? '').toString(),
                          ),
                          onTap: () => Navigator.pop(context, section),
                        ),
                    ],
                  ),
                ),
              );
        if (section == null || !mounted) return;
        sectionId = section['id'].toString();
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;
        final revision = _context.beginCourse(uid, _courseId);
        _context.commitSections(
          revision,
          uid,
          _courseId,
          sections,
          requested: sectionId,
        );
        await _loadCourseData(showLoading: false);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              LiveClassesScreen(courseId: _courseId, sectionId: sectionId),
        ),
      );
    } catch (_) {
      _showError('Unable to open the live classroom. Please try again.');
    }
  }

  Future<void> _openAssessment(Map<String, dynamic> assessment) async {
    final id = (assessment['assessmentId'] ?? assessment['id'] ?? '')
        .toString();
    if (id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstructorAssessmentGradingScreen(assessmentId: id),
      ),
    );
    if (mounted) await _loadCourseData(showLoading: false);
  }

  Future<void> _newAssessment() async {
    if (_modules.isEmpty) return;
    final module = _modules.length == 1
        ? _modules.first
        : await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Choose a module',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final module in _modules)
                    ListTile(
                      title: Text((module['title'] ?? 'Module').toString()),
                      onTap: () => Navigator.pop(context, module),
                    ),
                ],
              ),
            ),
          );
    if (module == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstructorCreateAssessmentScreen(
          courseId: _courseId,
          moduleId: (module['moduleId'] ?? module['id']).toString(),
          courseCode: _courseCode,
          courseTitle: _courseTitle,
          moduleTitle: (module['title'] ?? '').toString(),
          sections: _sections,
          moduleSectionIds: SectionAudienceService.stored(module),
          initialSectionId: _sectionId,
        ),
      ),
    );
    if (mounted) await _loadCourseData(showLoading: false);
  }

  Widget _buildActivitiesTab() => ListView(
    padding: CourseWorkspaceLayout.pagePadding(context),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _modules.isEmpty ? null : _newAssessment,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create assessment'),
        ),
      ),
      const SizedBox(height: 16),
      if (_assessments.isEmpty)
        const WorkspaceEmptyState(
          icon: Icons.assignment_outlined,
          title: 'No activities yet',
          message: 'Add a module in Content, then create an assessment.',
        ),
      for (final assessment in _assessments)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WorkspaceSurface(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(
                (assessment['title'] ?? 'Untitled assessment').toString(),
              ),
              subtitle: Text(
                [
                  (assessment['assessmentType'] ?? 'Assessment').toString(),
                  (assessment['status'] ?? 'draft').toString(),
                ].join(' • '),
              ),
              onTap: () => _openAssessment(assessment),
              trailing: PopupMenuButton<String>(
                tooltip: 'Assessment actions',
                onSelected: (action) {
                  if (action == 'grade') {
                    _openAssessment(assessment);
                    return;
                  }
                  final index = _modules.indexWhere(
                    (module) =>
                        (module['moduleId'] ?? module['id']) ==
                        assessment['moduleId'],
                  );
                  if (index >= 0) {
                    _openModule(
                      _modules[index],
                      initialTab: 1,
                      focusAssessmentId: (assessment['id'] ?? '').toString(),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'manage',
                    child: Text('Manage assessment'),
                  ),
                  PopupMenuItem(
                    value: 'grade',
                    child: Text('View submissions'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  // ============================================================
  // TAB CONTENTS
  // ============================================================

  Widget _buildRosterTab() {
    final List<Map<String, dynamic>> pendingInvitations = _courseInvitations
        .where(
          (invitation) =>
              (invitation['status'] ?? '').toString().toLowerCase() ==
              'pending',
        )
        .toList();

    return ListView(
      padding: CourseWorkspaceLayout.pagePadding(context, top: 18, bottom: 24),
      children: [
        if (pendingInvitations.isNotEmpty) ...[
          _buildPendingInvitations(pendingInvitations),
          const SizedBox(height: 18),
        ],
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSendingInvitation ? null : _inviteStudent,
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  message: 'Invite students using their registered Campus ID. They will appear here after accepting.',
                )
              else
                ..._students.map((student) {
                  final String name =
                      (student['name'] ?? student['studentName'] ?? '')
                          .toString()
                          .trim();
                  final String email = (student['email'] ?? '')
                      .toString()
                      .trim();
                  final String universityId = (student['universityId'] ?? '')
                      .toString()
                      .trim();
                  final String displayName = name.isNotEmpty
                      ? name
                      : universityId;

                  return _contentCard(
                    leading: _leadingAvatar(displayName, Icons.person_outline),
                    title: displayName.isNotEmpty ? displayName : email,
                    subtitle: [
                      if (email.isNotEmpty) email,
                      if (universityId.isNotEmpty) 'Campus ID: $universityId',
                    ].join('\n'),
                    trailing: IconButton(
                      tooltip: 'Message student',
                      onPressed: () => _openStudentChat(student),
                      icon: Icon(
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
              Icon(Icons.outgoing_mail, color: orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '${invitations.length} pending '
                '${invitations.length == 1 ? 'invitation' : 'invitations'}',
                style: TextStyle(
                  color: heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...invitations.map((invitation) {
            final String invitationId =
                (invitation['invitationId'] ?? invitation['id'] ?? '')
                    .toString()
                    .trim();
            final String studentName = (invitation['studentName'] ?? 'Student')
                .toString()
                .trim();
            final String campusId = (invitation['studentCampusId'] ?? '')
                .toString()
                .trim();
            final bool busy = _busyInvitationIds.contains(invitationId);

            return _contentCard(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFFFF2DF),
                child: Icon(Icons.schedule_rounded, color: orange, size: 17),
              ),
              title: studentName.isEmpty ? campusId : studentName,
              subtitle: campusId.isNotEmpty
                  ? 'Campus ID: $campusId'
                  : 'Pending response',
              trailing: TextButton(
                onPressed: busy ? null : () => _cancelInvitation(invitation),
                child: Text(
                  busy ? 'Cancelling...' : 'Cancel',
                  style: TextStyle(color: red),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGradesTab() => ListView(
    padding: CourseWorkspaceLayout.pagePadding(context),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InstructorSemesterGradesScreen(
                  courseId: _courseId,
                  sectionId: _sectionId,
                ),
              ),
            );
            if (mounted) await _loadCourseData(showLoading: false);
          },
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Semester grades'),
        ),
      ),
      const SizedBox(height: 16),
      if (_assessments.isEmpty)
        const WorkspaceEmptyState(
          icon: Icons.grade_outlined,
          title: 'No assessments to grade',
          message:
              'Published activities and student submissions will appear here.',
        ),
      for (final assessment in _assessments)
        Builder(
          builder: (context) {
            final id = (assessment['assessmentId'] ?? assessment['id'])
                .toString();
            final submissions = _assessmentSubmissions
                .where((row) => row['assessmentId'] == id)
                .toList();
            final pending = submissions
                .where((row) => row['status'] == 'submitted')
                .length;
            final graded = submissions
                .where((row) => row['status'] == 'graded')
                .length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkspaceSurface(
                padding: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.grading_outlined),
                  title: Text((assessment['title'] ?? 'Assessment').toString()),
                  subtitle: Text('$pending to grade • $graded graded'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openAssessment(assessment),
                ),
              ),
            );
          },
        ),
    ],
  );

  Widget _buildSettingsTab() {
    return ListView(
      padding: CourseWorkspaceLayout.pagePadding(context, top: 18, bottom: 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
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
                    Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Enrollment',
                      value: 'By instructor invitation',
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Instructor',
                      value: _instructorName,
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Semester',
                      value: _semester,
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildSettingTile(
                      icon: Icons.school_outlined,
                      title: 'Academic Year',
                      value: _academicYear,
                    ),
                    Divider(height: 1, color: borderColor),
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
        style: TextStyle(
          color: heading,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? '—' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
          Icon(Icons.error_outline_rounded, color: red, size: 50),
          const SizedBox(height: 13),
          Text(
            _errorMessage ?? 'Unable to load course information.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
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
