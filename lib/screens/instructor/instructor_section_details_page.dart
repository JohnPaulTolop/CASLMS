import '../../services/course_invitation_service.dart';
import 'invite_student_dialog.dart';
import '../shared/grading_ui.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import '../../services/enrollment_membership.dart';
import '../shared/live_classes_page.dart';
import 'instructor_assessment_grading_page.dart';
import 'instructor_semester_grades_page.dart';
import 'instructor_class_details_page.dart';

class InstructorSectionDetailsScreen extends StatefulWidget {
  const InstructorSectionDetailsScreen({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final String courseId;
  final String sectionId;

  @override
  State<InstructorSectionDetailsScreen> createState() =>
      _InstructorSectionDetailsScreenState();
}

class _SectionViewData {
  const _SectionViewData({
    required this.course,
    required this.section,
    required this.allStudents,
    required this.students,
    required this.modules,
    required this.assessments,
    required this.submissions,
    required this.courseWideCount,
  });

  final Map<String, dynamic> course;
  final Map<String, dynamic> section;
  final List<Map<String, dynamic>> allStudents;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> modules;
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> submissions;
  final int courseWideCount;
}

class _InstructorSectionDetailsScreenState
    extends State<InstructorSectionDetailsScreen> {
  static const Color teal = Color(0xFF00897B);
  static const Color darkTeal = Color(0xFF00695C);
  static const Color background = Color(0xFFF5F8FC);
  static const Color heading = Color(0xFF172B4D);
  static const Color secondaryText = Color(0xFF6B7C93);
  static const Color borderColor = Color(0xFFE5ECF3);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CourseSectionService _sections = CourseSectionService();

  late Future<_SectionViewData> _future;

  late final _invitationStream = _db
      .collection('courseInvitations')
      .where('courseId', isEqualTo: widget.courseId)
      .snapshots();
  final Set<String> _cancellingInvitations = {};
  bool _transferring = false;
  bool _overviewExpanded = false;
  final List<StreamSubscription> _changes = [];
  Timer? _refreshTimer;

  String _text(Object? value) => (value ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _future = _load();
    for (final collection in ['enrollments', 'assessmentSubmissions']) {
      _changes.add(
        _db
            .collection(collection)
            .where('courseId', isEqualTo: widget.courseId)
            .snapshots()
            .listen(
              (_) {
                _refreshTimer?.cancel();
                _refreshTimer = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) _refresh();
                });
              },
              onError: (Object error) =>
                  _notice('Unable to refresh section data. Please refresh.'),
            ),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final change in _changes) {
      change.cancel();
    }
    super.dispose();
  }

  Future<_SectionViewData> _load() async {
    final section = await _sections.getSection(
      courseId: widget.courseId,
      sectionId: widget.sectionId,
    );

    final courseDocument = await _db
        .collection('courses')
        .doc(widget.courseId)
        .get();

    final course = courseDocument.data();

    if (course == null) {
      throw StateError('Course no longer exists.');
    }

    final enrollmentDocuments = await _db
        .collection('enrollments')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    final moduleDocuments = await _db
        .collection('modules')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    final assessmentDocuments = await _db
        .collection('assessments')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    final submissionDocuments = await _db
        .collection('assessmentSubmissions')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    final originalCode = _text(course['classCode']);

    String enrollmentSection(Map<String, dynamic> enrollment) {
      return EnrollmentMembership.sectionId(enrollment, originalCode);
    }

    final allStudents = EnrollmentMembership.uniqueActive(
      enrollmentDocuments.docs.map(
        (doc) => <String, dynamic>{...doc.data(), 'id': doc.id},
      ),
    );

    final students = allStudents
        .where((data) => enrollmentSection(data) == widget.sectionId)
        .toList();

    students.sort(
      (a, b) =>
          _text(a['studentName'])
              .toLowerCase()
              .compareTo(_text(b['studentName']).toLowerCase()),
    );

    final modules = moduleDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();

    modules.sort(
      (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
        (b['order'] as num?)?.toInt() ?? 0,
      ),
    );

    final allAssessments = assessmentDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();

    final assessments = allAssessments
        .where((data) => _text(data['sectionId']) == widget.sectionId)
        .toList();

    final courseWideCount = allAssessments
        .where((data) => _text(data['sectionId']).isEmpty)
        .length;

    final sectionAssessmentIds = assessments
        .map((data) => _text(data['id']))
        .toSet();

    final submissions = submissionDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .where(
          (data) => sectionAssessmentIds.contains(_text(data['assessmentId'])),
        )
        .toList();

    return _SectionViewData(
      course: {...course, 'id': courseDocument.id},
      section: section,
      allStudents: allStudents,
      students: students,
      modules: modules,
      assessments: assessments,
      submissions: submissions,
      courseWideCount: courseWideCount,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    final nextLoad = _load();
    setState(() => _future = nextLoad);

    try {
      await nextLoad;
    } catch (_) {
      // FutureBuilder displays the error and retry action.
    }
  }

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: heading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // STUDENT TRANSFER
  // ============================================================

  Future<void> _transferStudent(_SectionViewData data) async {
    if (_transferring ||
        _text(data.section['status']).toLowerCase() != 'active') {
      return;
    }

    final originalCode = _text(data.course['classCode']);

    final candidates = data.allStudents.where((student) {
      final assignedSection = _text(student['sectionId']);
      final effectiveSection = assignedSection.isEmpty
          ? originalCode
          : assignedSection;

      return effectiveSection != widget.sectionId &&
          _text(student['studentId']).isNotEmpty;
    }).toList();

    if (candidates.isEmpty) {
      _notice('No students from other sections are available to transfer.');
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Transfer enrolled student'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: candidates.map((student) {
              final name = _text(student['studentName']);
              final id = _text(student['studentId']);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2F1),
                  foregroundColor: darkTeal,
                  child: Text(
                    (name.isNotEmpty ? name : id).substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(name.isEmpty ? id : name),
                subtitle: Text('Student ID: $id'),
                onTap: () => Navigator.of(dialog).pop(id),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedId == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm section transfer'),
        content: Text(
          'Move this student to ${_text(data.section['name'])}? '
          'Their course enrollment will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _transferring = true);

    try {
      await _sections.assignStudent(
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        studentId: selectedId,
      );

      _notice('Student transferred successfully.');
      await _refresh();
    } catch (error) {
      _notice('Unable to transfer student: $error');
    } finally {
      if (mounted) {
        setState(() => _transferring = false);
      }
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openGrading(Map<String, dynamic> assessment) async {
    final assessmentId = _text(assessment['id']);
    if (assessmentId.isEmpty) return;

    await Navigator.of(context).push(
      GradeRoute<void>(
        builder: (_) =>
            InstructorAssessmentGradingScreen(assessmentId: assessmentId),
      ),
    );

    if (mounted) await _refresh();
  }

  Future<void> _openCourseTools(_SectionViewData data) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstructorClassDetailsScreen(
          courseId: widget.courseId,
          sectionId: widget.sectionId,
          courseCode: _text(data.course['code']),
          courseTitle: _text(data.course['title']),
        ),
      ),
    );

    if (mounted) await _refresh();
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

  Widget _sectionHeading(String title, String subtitle, {Widget? trailing}) {
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
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
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

  Widget _compactStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: teal, size: 19),
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

  Widget _leadingAvatar(String name, IconData fallbackIcon) {
    final displayName = name.trim();

    if (displayName.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F6F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(fallbackIcon, color: teal, size: 22),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDDF5F0), Color(0xFFB9E9DF)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: darkTeal,
          fontSize: 13,
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

  Widget _collapsibleOverview(_SectionViewData data) {
    final sectionName = _text(data.section['name']);
    final identifier = _text(data.section['identifier']);
    final status = _text(data.section['status']);
    final isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                      Icons.groups_rounded,
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
                          sectionName.isEmpty
                              ? 'Section overview'
                              : sectionName,
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
                          '${data.students.length} students'
                          '${identifier.isNotEmpty ? ' • $identifier' : ''}',
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
                      status.isEmpty ? 'Unknown' : status,
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
                      _overviewChip(
                        Icons.people_alt_outlined,
                        '${data.students.length} students',
                      ),
                      _overviewChip(
                        Icons.menu_book_outlined,
                        '${data.modules.length} modules',
                      ),
                      _overviewChip(
                        Icons.assignment_outlined,
                        '${data.assessments.length} assessments',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _compactStat(
                          'Students',
                          '${data.students.length}',
                          Icons.people_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactStat(
                          'Modules',
                          '${data.modules.length}',
                          Icons.menu_book_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactStat(
                          'Assessments',
                          '${data.assessments.length}',
                          Icons.assignment_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENTS TAB
  // ============================================================

  Widget _pendingInvitations(_SectionViewData data) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _invitationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to sync pending invitations. Reopen this section to retry.',
          );
        }
        final pending =
            snapshot.data?.docs
                .where(
                  (d) =>
                      d.data()['status'] == 'pending' &&
                      (d.data()['sectionId'] ?? data.course['classCode']) ==
                          widget.sectionId,
                )
                .toList() ??
            [];
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending invitations (${pending.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...pending.map(
              (invitation) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: teal,
                ),
                title: Text(
                  (invitation.data()['studentName'] ?? 'Student').toString(),
                ),
                subtitle: Text(
                  'Campus ID: ${invitation.data()['studentCampusId'] ?? ''}',
                ),
                trailing: TextButton(
                  onPressed: _cancellingInvitations.contains(invitation.id)
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Cancel invitation?'),
                              content: const Text(
                                'The student will no longer be able to accept this invitation.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Keep'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Cancel invitation'),
                                ),
                              ],
                            ),
                          );
                          if (!mounted || confirmed != true) return;
                          setState(
                            () => _cancellingInvitations.add(invitation.id),
                          );
                          try {
                            await CourseInvitationService().cancelInvitation(
                              invitation.id,
                            );
                          } on CourseInvitationException catch (error) {
                            _notice(error.message);
                          } finally {
                            if (mounted) {
                              setState(
                                () => _cancellingInvitations.remove(
                                  invitation.id,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    _cancellingInvitations.contains(invitation.id)
                        ? 'Cancelling…'
                        : 'Cancel',
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
          ],
        );
      },
    );
  }

  Widget _studentsTab(_SectionViewData data) {
    final isActive = _text(data.section['status']).toLowerCase() == 'active';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Class roster',
                'Manage the students enrolled in this section.',
                trailing: FilledButton.icon(
                  onPressed: _transferring || !isActive
                      ? null
                      : () => _transferStudent(data),
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
                  icon: _transferring
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1, size: 17),
                  label: Text(_transferring ? 'Transferring' : 'Transfer'),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: !isActive
                    ? null
                    : () async {
                        final sent = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => InviteStudentDialog(
                            courseId: widget.courseId,
                            sectionId: widget.sectionId,
                          ),
                        );
                        if (!mounted || sent != true) return;
                        _notice(
                          'Invitation sent. This roster updates when the student accepts.',
                        );
                      },
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Invite student'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Invitation-only enrollment. Accepted students appear here automatically.',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ),
              const SizedBox(height: 18),
              _pendingInvitations(data),
              if (data.students.isEmpty)
                _emptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No students yet',
                  message: 'Active students assigned to this section will appear here.',
                )
              else
                ...data.students.map((student) {
                  final name = _text(student['studentName']);
                  final id = _text(student['studentId']);
                  final campusId = _text(student['studentCampusId']);

                  return _contentCard(
                    leading: _leadingAvatar(name, Icons.person_outline),
                    title: name.isEmpty ? id : name,
                    subtitle: campusId.isNotEmpty
                        ? 'Campus ID: $campusId'
                        : 'Student ID: $id',
                    trailing: _pill('Active'),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MODULES TAB
  // ============================================================

  Widget _modulesTab(_SectionViewData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Learning modules',
                'Course materials shared across all sections.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDEBFA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2472B8),
                      size: 21,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modules belong to the course rather than an individual section. Changes to shared course modules may affect other sections.',
                        style: TextStyle(
                          color: Color(0xFF385B7A),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (data.modules.isEmpty)
                _emptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No modules available',
                  message: 'Modules created for this course will appear here.',
                )
              else
                ...data.modules.map((module) {
                  final title = _text(module['title']);
                  final status = _text(module['status']);

                  return _contentCard(
                    leading: _leadingAvatar('', Icons.menu_book_rounded),
                    title: title.isEmpty ? 'Untitled module' : title,
                    subtitle:
                        'Status: ${status.isEmpty ? 'Not specified' : status}',
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: secondaryText,
                    ),
                  );
                }),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCourseTools(data),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFB9DFD8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_outlined, size: 19),
                  label: const Text('Open course-wide tools'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ASSESSMENTS TAB
  // ============================================================

  Widget _assessmentsTab(_SectionViewData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Assessments',
                'Review and grade assessments assigned to this section.',
                trailing: _pill('${data.assessments.length} total'),
              ),
              const SizedBox(height: 10),
              if (data.assessments.isEmpty)
                _emptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No section assessments',
                  message: 'Assessments assigned specifically to this section will appear here.',
                )
              else
                ...data.assessments.map((assessment) {
                  final title = _text(assessment['title']);
                  final status = _text(assessment['status']);
                  final type = _text(assessment['assessmentType']);

                  return _contentCard(
                    leading: _leadingAvatar('', Icons.assignment_rounded),
                    title: title.isEmpty ? 'Untitled assessment' : title,
                    subtitle:
                        'Status: ${status.isEmpty ? 'Not specified' : status}'
                        '${type.isNotEmpty ? ' • Type: $type' : ''}',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: secondaryText,
                    ),
                    onTap: () => _openGrading(assessment),
                  );
                }),
              if (data.courseWideCount > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFF5E6BD)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF9A6B13),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data.courseWideCount} course-wide assessment(s)',
                              style: const TextStyle(
                                color: Color(0xFF765211),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'These assessments are shared across sections and are not included in the section-specific assessment list.',
                              style: TextStyle(
                                color: Color(0xFF8A713D),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 9),
                            TextButton(
                              onPressed: () => _openCourseTools(data),
                              child: const Text('Open course tools'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GRADES TAB
  // ============================================================

  Widget _gradesTab(_SectionViewData data) {
    final titles = <String, String>{
      for (final assessment in data.assessments)
        _text(assessment['id']): _text(assessment['title']),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        GradeShortcut(
          icon: Icons.calculate_outlined,
          title: 'Semester Grades',
          subtitle:
              'Set weights, preview results, and post grades for this section.',
          onTap: () => Navigator.of(context).push(
            GradeRoute<void>(
              builder: (_) => InstructorSemesterGradesScreen(
                courseId: widget.courseId,
                sectionId: widget.sectionId,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading(
                'Grades & submissions',
                'Track submissions for section-specific assessments.',
                trailing: _pill('${data.submissions.length} submissions'),
              ),
              for (final assessment in data.assessments.where(
                (item) =>
                    item['deliveryType'] == 'external_link' &&
                    ['published', 'closed'].contains(item['status']),
              ))
                TextButton.icon(
                  onPressed: () => _openGrading(assessment),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    'Manual Grade Input: ${_text(assessment['title'])}',
                  ),
                ),
              const SizedBox(height: 10),
              if (data.submissions.isEmpty)
                _emptyState(
                  icon: Icons.grade_outlined,
                  title: 'Nothing to grade yet',
                  message: 'Submissions for section-specific assessments will appear here.',
                )
              else
                ...data.submissions.map((submission) {
                  final assessmentId = _text(submission['assessmentId']);
                  final studentName = _text(submission['studentName']);
                  final studentId = _text(submission['studentId']);
                  final score = submission['score'];
                  final status = _text(submission['status']);

                  final displayStudent = studentName.isEmpty
                      ? studentId
                      : studentName;

                  return _contentCard(
                    leading: _leadingAvatar(
                      displayStudent,
                      Icons.grade_outlined,
                    ),
                    title: titles[assessmentId]?.isNotEmpty == true
                        ? titles[assessmentId]!
                        : 'Assessment',
                    subtitle:
                        'Student: ${displayStudent.isEmpty ? 'Unknown student' : displayStudent}'
                        '\nStatus: ${status.isEmpty ? 'Not specified' : status}'
                        '${score is num ? '\nScore: $score' : ''}',
                    trailing: const Icon(
                      Icons.description_outlined,
                      color: teal,
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: heading),
          ),
          title: const Text(
            'Section Details',
            style: TextStyle(
              color: heading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Live Classes',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LiveClassesScreen(
                    courseId: widget.courseId,
                    sectionId: widget.sectionId,
                  ),
                ),
              ),
              icon: const Icon(Icons.video_call_outlined, color: teal),
            ),
            RoundGradeAction(
              label: 'Compute & Finalize Semester Grades',
              icon: Icons.calculate_outlined,
              onTap: () => Navigator.of(context).push(
                GradeRoute<void>(
                  builder: (_) => InstructorSemesterGradesScreen(
                    courseId: widget.courseId,
                    sectionId: widget.sectionId,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh section',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: teal),
            ),
            const SizedBox(width: 6),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: borderColor),
          ),
        ),
        body: FutureBuilder<_SectionViewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: teal),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 42,
                          color: teal,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Unable to load section',
                          style: TextStyle(
                            color: heading,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _refresh,
                          style: FilledButton.styleFrom(backgroundColor: teal),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            return SafeArea(
              top: false,
              child: Column(
                children: [
                  _collapsibleOverview(data),

                  // Compact tabs; original text sizes retained.
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 7, 12, 0),
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
                        Tab(height: 36, text: 'Students'),
                        Tab(height: 36, text: 'Modules'),
                        Tab(height: 36, text: 'Assessments'),
                        Tab(height: 36, text: 'Grades'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _studentsTab(data),
                        _modulesTab(data),
                        _assessmentsTab(data),
                        _gradesTab(data),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
