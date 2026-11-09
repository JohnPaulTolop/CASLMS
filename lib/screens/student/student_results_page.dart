import 'package:flutter/material.dart';

import 'activities_scores_page.dart';
import 'posted_grades_page.dart';
import 'progress_page.dart';

class StudentResultsScreen extends StatelessWidget {
  const StudentResultsScreen({super.key, required this.selection});
  final ValueNotifier<int> selection;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: selection,
    builder: (context, selected, _) => Column(
      children: [
        StudentResultTabs(
          selected: selected,
          onSelected: (index) => selection.value = index,
        ),
        Expanded(
          child: switch (selected) {
            1 => const ActivitiesScoresScreen(),
            2 => const PostedGradesScreen(),
            _ => const ProgressScreen(),
          },
        ),
      ],
    ),
  );
}

class StudentResultTabs extends StatelessWidget {
  const StudentResultTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < 3; index++)
            Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
              child: ChoiceChip(
                label: Text(
                  const [
                    'Progress',
                    'Activity scores',
                    'Official grades',
                  ][index],
                ),
                selected: selected == index,
                onSelected: (_) => onSelected(index),
              ),
            ),
        ],
      ),
    ),
  );
}
