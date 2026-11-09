import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';

const navy = AppColors.darkText;
const blue = AppColors.primaryBlue;
const muted = AppColors.secondaryText;
const _line = AppColors.inputBorder;
const _blueTint = AppColors.blueTint;

CourseSummary courseSummary(
  Map<String, dynamic> row,
  int index, {
  double? progress,
}) {
  const accents = [
    (AppColors.primaryBlue, AppColors.blueTint, Icons.data_object_rounded),
    (AppColors.purple, AppColors.purpleTint, Icons.language_rounded),
    (AppColors.green, AppColors.greenTint, Icons.phone_iphone_rounded),
    (AppColors.amber, AppColors.amberTint, Icons.menu_book_outlined),
  ];
  final accent = accents[index % accents.length];
  return CourseSummary(
    code: (row['code'] ?? '').toString(),
    title: (row['title'] ?? 'Course').toString(),
    category:
        (row['category'] ?? row['department'] ?? row['instructorName'] ?? '')
            .toString()
            .toUpperCase(),
    progress: progress,
    icon: accent.$3,
    color: accent.$1,
    tint: accent.$2,
  );
}

/// Keeps page titles in the scroll flow while preserving inner list behavior.
class WorkspaceScrollingBody extends StatelessWidget {
  const WorkspaceScrollingBody({
    super.key,
    required this.header,
    required this.body,
  });
  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, innerScrolled) => [
      SliverToBoxAdapter(child: header),
    ],
    body: body,
  );
}

class WorkspaceHeading extends StatelessWidget {
  const WorkspaceHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    this.actions,
    this.inlineActions = false,
    this.showEyebrow = true,
  });
  final String title;
  final String subtitle;
  final String eyebrow;
  final List<Widget>? actions;
  final bool inlineActions;
  final bool showEyebrow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = !showEyebrow && MediaQuery.sizeOf(context).width < 1100;
      final actionsInline = inlineActions || compact;
      final titleText = Text(
        title,
        style: TextStyle(
          fontSize: box.maxWidth < 600 ? 30 : 35,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          height: 1.15,
        ),
      );
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showEyebrow) ...[
            WorkspaceEyebrow(eyebrow),
            const SizedBox(height: 10),
          ],
          if (actionsInline && actions != null && actions!.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleText),
                const SizedBox(width: 8),
                IconButtonTheme(
                  data: IconButtonThemeData(
                    style: compact
                        ? IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                  child: Wrap(spacing: 4, children: actions!),
                ),
              ],
            )
          else
            titleText,
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.resolve(context, muted),
              fontSize: 14,
            ),
          ),
        ],
      );
      if (actionsInline || actions == null || actions!.isEmpty) return heading;
      final actionRow = Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        runSpacing: 4,
        children: actions!,
      );
      if (box.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [heading, const SizedBox(height: 10), actionRow],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 12),
          actionRow,
        ],
      );
    },
  );
}

class WorkspaceLoadingState extends StatelessWidget {
  const WorkspaceLoadingState({
    super.key,
    this.label = 'Loading…',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: compact ? 20 : 32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: AppColors.resolve(context, muted),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class WorkspaceEmptyState extends StatelessWidget {
  const WorkspaceEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => WorkspaceSurface(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.resolve(context, blue), size: 28),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.resolve(context, muted),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
        if (action != null && onAction != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

class WorkspaceErrorState extends StatelessWidget {
  const WorkspaceErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => WorkspaceSurface(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          color: AppColors.resolve(context, AppColors.error),
          size: 28,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.resolve(context, muted),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(retryLabel),
          ),
        ],
      ],
    ),
  );
}

void showWorkspaceFeedback(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : AppColors.darkText,
      ),
    );
}

class WorkspaceEyebrow extends StatelessWidget {
  const WorkspaceEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: AppColors.resolve(context, muted),
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.7,
    ),
  );
}

class WorkspaceSurface extends StatelessWidget {
  const WorkspaceSurface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.borderColor = _line,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.resolve(context, color),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.resolve(context, borderColor)),
    ),
    child: child,
  );
}

class OverviewStats extends StatelessWidget {
  const OverviewStats({
    super.key,
    required this.courses,
    required this.assessments,
    required this.pending,
    required this.announcements,
  });
  final int courses;
  final int? assessments, pending, announcements;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      String count(int? value) =>
          value == null ? '—' : value.toString().padLeft(2, '0');
      final stats = [
        (
          Icons.menu_book_outlined,
          count(courses),
          'Active courses',
          blue,
          _blueTint,
        ),
        (
          Icons.event_note_outlined,
          count(assessments),
          'Assessments',
          Color(0xFFB68A46),
          Color(0xFFFAF3E6),
        ),
        (
          Icons.task_alt_rounded,
          count(pending),
          pending == 1 ? 'Pending task' : 'Pending tasks',
          Color(0xFF3B9685),
          Color(0xFFEAF6F2),
        ),
        (
          Icons.campaign_outlined,
          count(announcements),
          'Announcements',
          Color(0xFF9472D4),
          Color(0xFFF3EEFB),
        ),
      ];
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 760 * scale
          ? 4
          : constraints.maxWidth >= 260 * scale
          ? 2
          : 1;
      final gap = constraints.maxWidth < 600 ? 10.0 : 14.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final stat in stats)
            SizedBox(
              width: width,
              child: WorkspaceSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        WorkspaceIconTile(
                          icon: stat.$1,
                          color: stat.$4,
                          background: stat.$5,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stat.$2,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: width < 170 ? 36 : 18,
                      ),
                      child: Text(
                        stat.$3,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.resolve(context, muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class LearningBanner extends StatelessWidget {
  const LearningBanner({super.key, required this.onContinue, this.onAskAi});
  final VoidCallback onContinue;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final showArt = constraints.maxWidth >= 500 * textScale;
      return Container(
        padding: EdgeInsets.all(constraints.maxWidth < 400 ? 24 : 28),
        decoration: BoxDecoration(
          color: AppColors.resolve(context, _blueTint),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onAskAi == null
                        ? 'PICK UP WHERE YOU LEFT OFF'
                        : 'YOUR NEXT STEP',
                    style: TextStyle(
                      color: AppColors.resolve(context, blue),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    onAskAi == null
                        ? 'Small steps.\nBig possibilities.'
                        : 'A little help.\nA clearer next step.',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    onAskAi == null
                        ? 'Your next idea is one lesson away.'
                        : 'Ask AI to explain a topic, or continue your course.',
                    style: TextStyle(
                      color: AppColors.resolve(
                        context,
                        AppColors.secondaryText,
                      ),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onAskAi != null)
                        FilledButton.icon(
                          key: const ValueKey('ask-ai'),
                          onPressed: onAskAi,
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                          ),
                          label: const Text('Ask AI'),
                        ),
                      OutlinedButton.icon(
                        key: const ValueKey('continue-course'),
                        onPressed: onContinue,
                        label: const Text('Continue learning'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showArt) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 160,
                height: 190,
                child: RepaintBoundary(
                  child: CustomPaint(painter: _LearningArtwork()),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class WorkspaceSectionHeading extends StatelessWidget {
  const WorkspaceSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.resolve(context, muted),
            ),
          ),
        ],
      );
      final button = TextButton.icon(
        onPressed: onAction,
        label: Text(action),
        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
        iconAlignment: IconAlignment.end,
      );
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      if (constraints.maxWidth < 280 * scale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 8), button],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 12),
          button,
        ],
      );
    },
  );
}

class WorkspaceCourseCard extends StatelessWidget {
  const WorkspaceCourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.progressBarHeight = AppTheme.progressBarHeight,
  });
  final CourseSummary course;
  final VoidCallback onTap;
  final double progressBarHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final compact = constraints.maxWidth < 440 * scale;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              course.code,
              course.category,
            ].where((part) => part.trim().isNotEmpty).join('  /  '),
            style: TextStyle(
              color: AppColors.resolve(context, course.color),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
          ),
        ],
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 16),
          CourseProgress(course: course, height: progressBarHeight),
        ],
      );
      return Material(
        color: AppColors.resolve(context, Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.resolve(context, _line)),
        ),
        child: InkWell(
          key: ValueKey('course-${course.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WorkspaceIconTile(
                            icon: course.icon,
                            color: AppColors.resolve(context, course.color),
                            background: course.tint,
                            size: 46,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: heading),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_outward_rounded,
                            size: 19,
                            color: AppColors.resolve(context, muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CourseProgress(course: course, height: progressBarHeight),
                    ],
                  )
                : Row(
                    children: [
                      WorkspaceIconTile(
                        icon: course.icon,
                        color: AppColors.resolve(context, course.color),
                        background: course.tint,
                        size: 72,
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: details),
                      const SizedBox(width: 20),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 20,
                        color: AppColors.resolve(context, muted),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

class CourseProgress extends StatelessWidget {
  const CourseProgress({
    super.key,
    required this.course,
    this.height = AppTheme.progressBarHeight,
  });
  final CourseSummary course;
  final double height;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ExcludeSemantics(
          excluding: course.progress == null,
          child: LinearProgressIndicator(
            value: course.progress ?? 0,
            minHeight: height,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: AppColors.resolve(context, course.tint),
            color: AppColors.resolve(context, course.color),
            semanticsLabel: course.progress == null
                ? '${course.title} progress unavailable'
                : '${course.title} progress',
          ),
        ),
      ),
      const SizedBox(width: 14),
      Text(
        course.progress == null ? '—' : '${(course.progress! * 100).round()}%',
        semanticsLabel: course.progress == null ? 'Progress unavailable' : null,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.resolve(context, muted),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class AssessmentTile extends StatelessWidget {
  const AssessmentTile({super.key, required this.item, required this.onTap});
  final AssessmentSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.resolve(context, item.tint),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                item.month,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppColors.resolve(context, item.color),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
              Text(
                item.day,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppColors.resolve(context, item.color),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.course} · ${item.time}',
                style: TextStyle(
                  color: AppColors.resolve(context, muted),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 9),
              WorkspacePill(
                label: item.type,
                color: AppColors.resolve(context, item.color),
                background: item.tint,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class WorkspaceIconTile extends StatelessWidget {
  const WorkspaceIconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.resolve(context, background),
      borderRadius: BorderRadius.circular(size * .25),
    ),
    child: Icon(
      icon,
      color: AppColors.resolve(context, color),
      size: size * .48,
    ),
  );
}

class WorkspacePill extends StatelessWidget {
  const WorkspacePill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.resolve(context, background),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppColors.resolve(context, color),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// A small vector illustration: no images, background filters, or animation.
class _LearningArtwork extends CustomPainter {
  const _LearningArtwork();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 190);
    canvas.drawCircle(
      const Offset(84, 94),
      67,
      Paint()..color = const Color(0xFFE0E8FF),
    );
    canvas.drawCircle(
      const Offset(84, 94),
      79,
      Paint()
        ..color = const Color(0xFFD7E0F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(80, 95);
    canvas.rotate(-.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -50, 102, 115),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFC1D0FA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-55, -58, 102, 115),
        const Radius.circular(14),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-43, -43, 78, 49),
        const Radius.circular(8),
      ),
      Paint()..color = blue,
    );
    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(-19, -29)
        ..lineTo(-28, -20)
        ..lineTo(-19, -11),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, -29)
        ..lineTo(18, -20)
        ..lineTo(9, -11),
      pen,
    );
    canvas.drawLine(const Offset(0, -32), const Offset(-8, -8), pen);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-41, 19 + i * 10, i == 2 ? 38 : 68, 3),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFE5EAF6),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      const Offset(125, 139),
      21,
      Paint()..color = const Color(0xFF17243F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(117, 139)
        ..lineTo(123, 145)
        ..lineTo(134, 133),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      const Offset(23, 40),
      5,
      Paint()..color = const Color(0xFFABC0FA),
    );
    final sparkle = Paint()
      ..color = blue
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(134, 29), const Offset(134, 41), sparkle);
    canvas.drawLine(const Offset(128, 35), const Offset(140, 35), sparkle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LearningArtwork oldDelegate) => false;
}

class CourseSummary {
  const CourseSummary({
    required this.code,
    required this.title,
    required this.category,
    required this.progress,
    required this.icon,
    required this.color,
    required this.tint,
  });
  final String code;
  final String title;
  final String category;
  final double? progress;
  final IconData icon;
  final Color color;
  final Color tint;
}

class AssessmentSummary {
  const AssessmentSummary({
    required this.title,
    required this.course,
    required this.day,
    required this.month,
    required this.due,
    required this.time,
    required this.type,
    required this.color,
    required this.tint,
  });
  final String title;
  final String course;
  final String day;
  final String month;
  final String due;
  final String time;
  final String type;
  final Color color;
  final Color tint;
}
