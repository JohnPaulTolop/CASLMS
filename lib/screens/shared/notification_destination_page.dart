import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_navigation_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification_target.dart';
import '../admin/admin_instructor_approvals_page.dart';
import '../instructor/instructor_assessment_grading_page.dart';
import '../instructor/instructor_course_sections_page.dart';
import '../instructor/instructor_module_detail_page.dart';
import '../instructor/instructor_chat_page.dart';
import '../student/student_chat_page.dart';
import '../student/student_course_modules_page.dart';
import '../student/student_module_detail_page.dart';
import '../student/assignment_details_page.dart';
import '../student/posted_grades_page.dart';
import 'live_classes_page.dart';
import 'legacy_submission_review_page.dart';

/// A named route inside SessionGate, preserving authentication and role shells.
class NotificationDestinationScreen extends StatefulWidget {
  const NotificationDestinationScreen({
    super.key,
    required this.notificationId,
    required this.onTab,
  });
  final String notificationId;
  final ValueChanged<int> onTab;
  @override
  State<NotificationDestinationScreen> createState() =>
      _NotificationDestinationScreenState();
}

class _NotificationDestinationScreenState
    extends State<NotificationDestinationScreen> {
  Widget? _content;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _content = null;
    });
    try {
      final destination = await NotificationNavigationService().resolve(
        widget.notificationId,
      );
      if (!mounted) return;
      final content = _screen(destination);
      // Mark only this notice, only after an authorized destination resolves.
      try {
        await NotificationService().markAsRead(widget.notificationId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Content opened, but read status could not be saved.',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      final kind = destination.target.kind;
      widget.onTab(
        destination.role == 'admin'
            ? (kind == 'instructorApplication' ? 4 : 2)
            : kind == 'conversation'
            ? 5
            : kind == 'semesterGrade'
            ? 8
            : destination.role == 'instructor' &&
                  destination.target.collection.contains('Submissions')
            ? 2
            : 1,
      );
      setState(() => _content = content);
    } on NotificationAccessException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'permission-denied'
              ? NotificationNavigationService.denied
              : 'Unable to open this notification. Check your connection and retry.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to open this notification. Please retry.',
        );
      }
    }
  }

  Widget _screen(NotificationDestination d) {
    final r = d.record, c = d.course, t = d.target;
    String text(dynamic value) => NotificationTarget.text(value);
    final courseId = text(c['id']);
    final moduleId = t.kind == 'module' ? t.id : text(r['moduleId']);
    if (t.kind == 'semesterGrade') {
      return PostedGradesScreen(
        initialCourseId: courseId,
        initialTermId: text(r['termId']),
      );
    }
    if (t.kind == 'instructorApplication') {
      return AdminInstructorApprovalsScreen(applicationId: t.id);
    }
    if (t.kind == 'conversation') {
      return d.role == 'student'
          ? StudentChatScreen(
              courseId: courseId,
              studentId: text(r['studentId']),
              studentName: text(r['studentName']),
              instructorId: text(r['instructorId']),
              instructorName: text(r['instructorName']),
              instructorEmail: text(r['instructorEmail']),
            )
          : InstructorChatScreen(
              courseId: courseId,
              studentId: text(r['studentId']),
              studentName: text(r['studentName']),
              studentEmail: text(r['studentEmail']),
              instructorId: text(r['instructorId']),
              instructorName: text(r['instructorName']),
            );
    }
    if (t.kind == 'liveClass') {
      return LiveClassesScreen(
        courseId: courseId,
        sectionId: text(r['sectionId']),
      );
    }
    if (t.kind == 'instructorStatus' || t.kind == 'announcement') {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            text(r['title']).isEmpty ? 'Account status' : text(r['title']),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            t.kind == 'instructorStatus'
                ? 'Account status: ${text(r['status'])}\n${text(r['denialReason'])}'
                : text(r['message']),
          ),
        ),
      );
    }
    if (d.role == 'student') {
      if (t.collection == 'assignments') {
        return AssignmentDetailsScreen(assignmentId: t.id);
      }
      if (t.collection == 'submissions') {
        return AssignmentDetailsScreen(assignmentId: text(r['assignmentId']));
      }
      if (moduleId.isNotEmpty) {
        return StudentModuleDetailScreen(
          courseId: courseId,
          courseCode: text(c['code']),
          courseTitle: text(c['title']),
          moduleId: moduleId,
          focusAssessmentId: t.collection == 'assessments'
              ? t.id
              : text(r['assessmentId']),
          showGrades: t.collection == 'assessmentSubmissions',
          focusResourceId: t.kind == 'moduleResource' ? t.id : '',
        );
      }
      if (t.kind != 'course' && t.kind != 'enrollment') {
        throw const NotificationAccessException(
          NotificationNavigationService.missing,
        );
      }
      return StudentCourseModulesScreen(
        courseId: courseId,
        courseCode: text(c['code']),
        courseTitle: text(c['title']),
        instructorName: text(c['instructorName']),
      );
    }
    if (d.role == 'instructor') {
      if (t.collection == 'submissions') {
        return LegacySubmissionReviewScreen(submission: r);
      }
      final assessmentId = t.collection == 'assessments'
          ? t.id
          : text(r['assessmentId']);
      if (assessmentId.isNotEmpty) {
        return InstructorAssessmentGradingScreen(
          assessmentId: assessmentId,
          focusSubmissionId: t.collection == 'assessmentSubmissions'
              ? t.id
              : '',
        );
      }
      if (moduleId.isNotEmpty) {
        return InstructorModuleDetailScreen(
          courseId: courseId,
          moduleId: moduleId,
          courseCode: text(c['code']),
          courseTitle: text(c['title']),
          moduleTitle: text(r['title']),
          focusResourceId: t.kind == 'moduleResource' ? t.id : '',
        );
      }
      return InstructorCourseSectionsScreen(courseId: courseId);
    }
    // Admins inspect the exact authoritative course without impersonating a student.
    return Scaffold(
      appBar: AppBar(
        title: Text(
          text(r['title']).isEmpty ? text(c['title']) : text(r['title']),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          '${text(c['code'])}\n${text(r['title'])}\n${text(r['instructions'] ?? r['description'] ?? r['message'])}\nStatus: ${text(r['status'])}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _content ??
      Scaffold(
        appBar: AppBar(title: const Text('Opening notification')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                        child: const Text('Return to dashboard'),
                      ),
                    ],
                  ),
                ),
        ),
      );
}
