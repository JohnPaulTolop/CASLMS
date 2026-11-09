import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';

class StudentProgressCharts extends StatelessWidget {
  const StudentProgressCharts({super.key, required this.learning});
  final Map<String, dynamic> learning;
  int _count(String key) => learning[key] is num
      ? (learning[key] as num).toInt().clamp(0, 1000000)
      : 0;
  @override
  Widget build(BuildContext context) {
    return WorkspaceSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Completion by type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Completed items as a share of published items.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in [
                (
                  'Modules',
                  'completedModules',
                  'totalModules',
                  AppColors.primaryBlue,
                ),
                (
                  'Assignments',
                  'submittedAssignments',
                  'totalAssignments',
                  AppColors.amber,
                ),
                (
                  'Quizzes',
                  'completedQuizzes',
                  'totalQuizzes',
                  AppColors.purple,
                ),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _column(
                      context,
                      item.$1,
                      _count(item.$2),
                      _count(item.$3),
                      AppColors.resolve(context, item.$4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _column(
    BuildContext context,
    String label,
    int completed,
    int total,
    Color color,
  ) {
    final done = completed.clamp(0, total);
    final value = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: '$label: $done of $total completed',
      child: Column(
        children: [
          Text(
            total == 0 ? '—' : '${(value * 100).round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            width: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value,
                widthFactor: 1,
                child: ColoredBox(color: color),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
          Text('$done / $total', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
