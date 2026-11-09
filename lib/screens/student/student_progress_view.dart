import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../shared/workspace_widgets.dart';
import 'student_progress_charts.dart';

class StudentProgressView extends StatelessWidget {
  const StudentProgressView({
    super.key,
    required this.learning,
    required this.academic,
    this.onCourse,
  });
  final Map<String, dynamic> learning, academic;
  final ValueChanged<Map<String, dynamic>>? onCourse;

  num _number(Map<String, dynamic> row, String key) =>
      row[key] is num ? row[key] as num : 0;
  double _ratio(Map<String, dynamic> row, String key) =>
      _number(row, key).toDouble().clamp(0, 1);
  String _points(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  String _percent(double value) => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final total = _number(learning, 'totalItems').toInt();
    final completed = _number(learning, 'completedItems').toInt();
    final remaining = (total - completed).clamp(0, total);
    final courses = (learning['courses'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final snapshot = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LightAppColors.darkText,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR LEARNING SNAPSHOT',
            style: TextStyle(
              color: Color(0xFFBDC9E5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 28,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                total == 0
                    ? '—'
                    : _percent(_ratio(learning, 'learningProgress')),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 0
                        ? 'Ready when you are'
                        : '$completed of $total activities completed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    total == 0
                        ? 'Published activities will appear here.'
                        : '$remaining remaining · Across ${courses.length} courses',
                    style: const TextStyle(
                      color: Color(0xFFBDC9E5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          _bar(
            context,
            total == 0 ? null : _ratio(learning, 'learningProgress'),
            const Color(0xFF93ADFF),
            track: Colors.white12,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final wide =
                box.maxWidth >= 840 &&
                MediaQuery.textScalerOf(context).scale(14) < 23;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: snapshot),
                        const SizedBox(width: 20),
                        Expanded(child: _performance(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  StudentProgressCharts(learning: learning),
                ] else ...[
                  snapshot,
                  const SizedBox(height: 20),
                  StudentProgressCharts(learning: learning),
                  const SizedBox(height: 20),
                  _performance(context),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          'Across your courses',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.resolve(context, AppColors.darkText),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Activity completion and assessed performance, side by side.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.resolve(context, AppColors.secondaryText),
          ),
        ),
        const SizedBox(height: 14),
        if (courses.isEmpty)
          const WorkspaceEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No active courses yet',
            message: 'Your enrolled courses will appear here.',
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns =
                  box.maxWidth >= 840 &&
                      MediaQuery.textScalerOf(context).scale(14) < 23
                  ? 2
                  : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final course in courses)
                    SizedBox(
                      width: (box.maxWidth - (columns - 1) * 16) / columns,
                      child: _course(context, course),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _performance(BuildContext context) {
    final hasGrades =
        academic['hasGrades'] == true &&
        _number(academic, 'availablePoints') > 0;
    return WorkspaceSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Assessed performance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on recorded points, not an official semester grade.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.resolve(context, AppColors.secondaryText),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasGrades ? _percent(_ratio(academic, 'percentage')) : '—',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: AppColors.resolve(context, AppColors.green),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasGrades
                ? '${_points(_number(academic, 'earnedPoints'))} / ${_points(_number(academic, 'availablePoints'))} assessed points'
                : 'Scores appear once work is assessed.',
            style: TextStyle(
              color: AppColors.resolve(context, AppColors.secondaryText),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          _scoreLine(
            context,
            'Assignments',
            'assignmentEarnedPoints',
            'assignmentAvailablePoints',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _scoreLine(
            context,
            'Quizzes',
            'quizEarnedPoints',
            'quizAvailablePoints',
          ),
        ],
      ),
    );
  }

  Widget _scoreLine(
    BuildContext context,
    String title,
    String earned,
    String available,
  ) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 12,
    runSpacing: 4,
    children: [
      Text(title, style: const TextStyle(fontSize: 13)),
      Text(
        _number(academic, available) > 0
            ? '${_points(_number(academic, earned))} / ${_points(_number(academic, available))} pts'
            : 'Not assessed',
        style: TextStyle(
          color: AppColors.resolve(context, AppColors.secondaryText),
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _course(BuildContext context, Map<String, dynamic> course) {
    final total = _number(course, 'totalItems').toInt();
    final assessed =
        course['hasGrades'] == true &&
        _number(course, 'academicAvailablePoints') > 0;
    final progress = _ratio(course, 'learningProgress');
    return Material(
      color: AppColors.resolve(context, Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.resolve(context, AppColors.inputBorder),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCourse == null ? null : () => onCourse!(course),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (course['code'] ?? '').toString(),
                          style: TextStyle(
                            color: AppColors.resolve(
                              context,
                              AppColors.primaryBlue,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (course['title'] ?? 'Course').toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onCourse != null)
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.resolve(
                          context,
                          AppColors.secondaryText,
                        ),
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _bar(
                context,
                total == 0 ? null : progress,
                AppColors.primaryBlue,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  Text(
                    total == 0
                        ? 'No activities published'
                        : '${_number(course, 'completedItems').toInt()} / $total complete · ${_percent(progress)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.resolve(
                        context,
                        AppColors.secondaryText,
                      ),
                    ),
                  ),
                  Text(
                    assessed
                        ? 'Assessed score ${_percent(_ratio(course, 'academicPerformance'))}'
                        : 'Not assessed yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: assessed
                          ? AppColors.green
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    double? value,
    Color color, {
    Color track = AppColors.inputBorder,
  }) => Semantics(
    label: value == null
        ? 'No activities'
        : '${(value * 100).round()} percent complete',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value ?? 0,
        minHeight: AppTheme.progressBarHeight,
        backgroundColor: AppColors.resolve(context, track),
        color: AppColors.resolve(context, color),
      ),
    ),
  );
}
