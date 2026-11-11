import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';

/// Shared layout primitives; teaching data and permissions stay in the screens.
class InstructorTiles extends StatelessWidget {
  const InstructorTiles({
    super.key,
    required this.children,
    this.minWidth = 260,
  });
  final List<Widget> children;
  final double minWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (box.maxWidth / (minWidth * scaled.clamp(1, 1.7)))
          .floor()
          .clamp(1, children.length.clamp(1, 4));
      final width = (box.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class InstructorMetric extends StatelessWidget {
  const InstructorMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final compact =
            box.maxWidth < 180 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 20),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: colors.primary, size: 17),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          label,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Icon(icon, color: colors.primary, size: 21),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class InstructorCourseGrid extends StatelessWidget {
  const InstructorCourseGrid({
    super.key,
    required this.courses,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> courses;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  Widget build(BuildContext context) => InstructorTiles(
    minWidth: 330,
    children: [
      for (var i = 0; i < courses.length; i++)
        _InstructorCourseCard(
          course: courses[i],
          index: i,
          onTap: () => onOpen(courses[i]),
        ),
    ],
  );
}

class _InstructorCourseCard extends StatelessWidget {
  const _InstructorCourseCard({
    required this.course,
    required this.index,
    required this.onTap,
  });
  final Map<String, dynamic> course;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = courseSummary(course, index);
    final accent = AppColors.resolve(context, summary.color);
    final period = [
      course['semester'],
      course['academicYear'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · ');
    return Material(
      key: ValueKey('instructor-course-${course['id'] ?? course['courseId']}'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: accent),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(summary.icon, color: accent, size: 23),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.north_east_rounded,
                        size: 19,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    summary.code,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    summary.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (period.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      period,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      Text(
                        '${course['studentCount'] is num ? course['studentCount'] : 0} enrolled',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructorDashboardContent extends StatelessWidget {
  const InstructorDashboardContent({
    super.key,
    required this.name,
    required this.enrollments,
    required this.pending,
    required this.courseCount,
    required this.courses,
    required this.onCourse,
    required this.onCreate,
    required this.onCourses,
    required this.onGrade,
    required this.onAi,
    required this.onCalendar,
    required this.onAnnouncements,
    required this.onHelp,
    this.onRefresh,
    this.onCreateModule,
    this.onCreateAssessment,
    this.onCreateMaterial,
  });
  final VoidCallback? onRefresh;
  final String name;
  final VoidCallback? onCreateModule, onCreateAssessment, onCreateMaterial;
  final int enrollments, pending, courseCount;
  final List<Map<String, dynamic>> courses;
  final ValueChanged<Map<String, dynamic>> onCourse;
  final VoidCallback onCreate,
      onCourses,
      onGrade,
      onAi,
      onCalendar,
      onAnnouncements,
      onHelp;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Welcome back, $name.',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Refresh overview',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Your courses, classroom conversations, and next teaching steps in one place.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        InstructorTiles(
          minWidth: 88,
          children: [
            InstructorMetric(
              label: 'Courses',
              value: '$courseCount',
              icon: Icons.menu_book_outlined,
              onTap: onCourses,
            ),
            InstructorMetric(
              label: 'Enrollments',
              value: '$enrollments',
              icon: Icons.groups_outlined,
              onTap: onCourses,
            ),
            InstructorMetric(
              label: 'Awaiting review',
              value: '$pending',
              icon: Icons.fact_check_outlined,
              onTap: onGrade,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.primary,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'A little help with your next lesson',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Plan a lesson, draft an assessment, or explore classroom activities with your teaching assistant.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              );
              final button = FilledButton(
                onPressed: onAi,
                child: const Text(
                  'Open teaching AI',
                  style: TextStyle(fontFamily: 'Roboto'),
                ),
              );
              return box.maxWidth < 650
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 16), button],
                    )
                  : Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 28),
                        button,
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text(
              'Your courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: onCourses,
                  child: const Text(
                    'View all',
                    style: TextStyle(fontFamily: 'Roboto'),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Create course content',
                  onSelected: (value) {
                    switch (value) {
                      case 'course':
                        onCreate();
                        break;
                      case 'module':
                        onCreateModule?.call();
                        break;
                      case 'assessment':
                        onCreateAssessment?.call();
                        break;
                      case 'material':
                        onCreateMaterial?.call();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'course',
                      child: Text('Create course'),
                    ),
                    if (onCreateModule != null)
                      const PopupMenuItem(
                        value: 'module',
                        child: Text('Create module'),
                      ),
                    if (onCreateAssessment != null)
                      const PopupMenuItem(
                        value: 'assessment',
                        child: Text('Create assessment'),
                      ),
                    if (onCreateMaterial != null)
                      const PopupMenuItem(
                        value: 'material',
                        child: Text('Add learning material'),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Create'),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Your teaching space starts with a course. Create one to add sections and learning materials.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
          )
        else
          InstructorCourseGrid(courses: courses, onOpen: onCourse),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onCalendar,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text(
                'Calendar',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAnnouncements,
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text(
                'Announcements',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
            ),
            TextButton.icon(
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text(
                'Help & guide',
                style: TextStyle(fontFamily: 'Roboto'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
