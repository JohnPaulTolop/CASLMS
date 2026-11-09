import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import 'student_notes.dart';

/// Production dashboard presentation. All records and actions come from the
/// authenticated dashboard controller; this widget has no demo data.
class StudentDashboardView extends StatelessWidget {
  const StudentDashboardView({
    super.key,
    required this.firstName,
    required this.courses,
    required this.assessments,
    required this.activeCourseCount,
    required this.assessmentCount,
    required this.pendingCount,
    required this.announcementCount,
    required this.onCourse,
    required this.onAssessment,
    required this.onCourses,
    required this.onTasks,
    required this.onInbox,
    required this.onInvitations,
    required this.onNotes,
    this.pendingInvitations = 0,
    this.summaryError,
    this.onRetry,
    this.onAssistant,
  });
  final String firstName;
  final List<CourseSummary> courses;
  final List<AssessmentSummary> assessments;
  final int activeCourseCount, pendingInvitations;
  final int? assessmentCount, pendingCount, announcementCount;
  final ValueChanged<int> onCourse, onAssessment;
  final VoidCallback onCourses, onTasks, onInbox, onInvitations, onNotes;
  final VoidCallback? onRetry;
  final VoidCallback? onAssistant;
  final String? summaryError;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WorkspaceHeading(
        showEyebrow: false,
        title: 'Hello, $firstName!',
        subtitle: 'A fresh start. A little focus. A step forward.',
        eyebrow: 'YOUR LEARNING SPACE',
      ),
      const SizedBox(height: 28),
      OverviewStats(
        courses: activeCourseCount,
        assessments: assessmentCount,
        pending: pendingCount,
        announcements: announcementCount,
      ),
      if (summaryError != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: WorkspaceSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summaryError!,
                  style: TextStyle(
                    color: AppColors.resolve(context, AppColors.secondaryText),
                    fontSize: 13,
                  ),
                ),
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Refresh dashboard'),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearningBanner(
                onContinue: courses.isEmpty ? onInvitations : () => onCourse(0),
                onAskAi: onAssistant,
              ),
              const SizedBox(height: 28),
              StudentNotesDashboardSection(onOpenNotes: onNotes),
              const SizedBox(height: 28),
              WorkspaceSectionHeading(
                title: 'My courses',
                subtitle: 'Keep the momentum going.',
                action: 'View all',
                onAction: onCourses,
              ),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                WorkspaceSurface(
                  child: Column(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: AppColors.resolve(
                          context,
                          AppColors.primaryBlue,
                        ),
                        size: 32,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'You have not joined a class yet.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Accept a course invitation to start learning.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.resolve(
                            context,
                            AppColors.secondaryText,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              for (var index = 0; index < courses.length; index++) ...[
                WorkspaceCourseCard(
                  course: courses[index],
                  onTap: () => onCourse(index),
                ),
                if (index < courses.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('course-invitations'),
                  onPressed: onInvitations,
                  icon: Badge(
                    isLabelVisible: pendingInvitations > 0,
                    label: Text('$pendingInvitations'),
                    child: const Icon(Icons.mail_outline_rounded, size: 18),
                  ),
                  label: Text(
                    pendingInvitations > 0
                        ? 'Course invitations ($pendingInvitations)'
                        : 'Course invitations',
                  ),
                ),
              ),
            ],
          );
          final side = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _calendar(context),
              const SizedBox(height: 20),
              _noticeboard(context),
            ],
          );
          if (constraints.maxWidth < 860 * scale) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 28), side],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: side),
            ],
          );
        },
      ),
      const SizedBox(height: 32),
      Text(
        'A little progress, every day.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.resolve(context, AppColors.secondaryText),
          fontSize: 11,
          letterSpacing: .3,
        ),
      ),
    ],
  );

  Widget _calendar(BuildContext context) => WorkspaceSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'On your calendar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
            ),
            SizedBox(width: 12),
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.resolve(context, AppColors.secondaryText),
              size: 19,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Your upcoming assessments',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.resolve(context, AppColors.secondaryText),
          ),
        ),
        const SizedBox(height: 24),
        if (assessments.isEmpty)
          Text(
            assessmentCount == null
                ? 'Assessments are not available yet.'
                : 'No upcoming assessments.',
            style: TextStyle(
              color: AppColors.resolve(context, AppColors.secondaryText),
              fontSize: 13,
            ),
          ),
        for (var index = 0; index < assessments.length; index++) ...[
          AssessmentTile(
            item: assessments[index],
            onTap: () => onAssessment(index),
          ),
          if (index < assessments.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
        ],
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onTasks,
          label: const Text('View assessments'),
          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
          iconAlignment: IconAlignment.end,
        ),
      ],
    ),
  );

  Widget _noticeboard(BuildContext context) => WorkspaceSurface(
    color: AppColors.resolve(context, AppColors.noticeboard),
    borderColor: AppColors.resolve(context, AppColors.noticeboard),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'The noticeboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            WorkspacePill(
              label: announcementCount == null ? '—' : '$announcementCount',
              color: AppColors.resolve(context, AppColors.primaryBlue),
              background: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Stay in the loop.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Course updates and announcements, all in one place.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.resolve(context, AppColors.secondaryText),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onInbox,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          label: const Text('Open your inbox'),
          icon: const Icon(Icons.arrow_outward_rounded, size: 15),
          iconAlignment: IconAlignment.end,
        ),
      ],
    ),
  );
}
