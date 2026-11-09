import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_course_content.dart';
import 'package:caslms/screens/shared/course_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const modules = [
  {
    'id': 'one',
    'title': 'Mobile application foundations',
    'status': 'published',
    'description': 'Start with the core concepts.',
  },
  {'id': 'two', 'title': 'Building the final project', 'status': 'draft'},
];
const materials = [
  {
    'id': 'material',
    'moduleId': 'one',
    'title': 'Topic lesson',
    'status': 'published',
  },
];
const assessments = [
  {
    'id': 'assessment',
    'moduleId': 'one',
    'title': 'Practice quiz',
    'status': 'draft',
  },
];

void main() {
  for (final width in [320.0, 390.0, 900.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Instructor workspace at $width, dark $dark, text $scale', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final actions = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: CourseWorkspaceLayout(
                title: 'Advance Mobile Development',
                subtitle: 'IT302 • First Semester',
                onRefresh: () async => actions.add('refresh'),
                actions: [
                  for (final label in ['Sections', 'Live classroom', 'Ask AI'])
                    OutlinedButton(
                      onPressed: () => actions.add(label),
                      child: Text(label),
                    ),
                ],
                labels: const ['Content', 'Activities', 'Grades', 'Students'],
                pages: [
                  InstructorCourseContent(
                    modules: modules,
                    materials: materials,
                    assessments: assessments,
                    onCreate: () => actions.add('create'),
                    onManage: (_) => actions.add('manage'),
                    onMaterial: (_, material) =>
                        actions.add(material['id'].toString()),
                    onAssessment: (assessment) =>
                        actions.add(assessment['id'].toString()),
                  ),
                  for (final label in ['Activities', 'Grades', 'Students'])
                    ListView(children: [Text('$label content')]),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Course Details'), findsNothing);
          final first = find.byKey(const ValueKey('open-module-one'));
          if (first.evaluate().isEmpty) {
            await tester.drag(
              find.byType(NestedScrollView),
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(first);
          await tester.pumpAndSettle();
          await tester.tap(first);
          await tester.pumpAndSettle();
          expect(actions.last, 'manage');
          expect(find.text('Manage module'), findsNothing);
          for (final label in ['Activities', 'Grades', 'Students', 'Content']) {
            await tester.ensureVisible(find.byType(TabBar));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text(label).first);
            await tester.tap(find.text(label).first);
            await tester.pumpAndSettle();
            if (label != 'Content') {
              expect(find.text('$label content').hitTestable(), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'Module authoring opens the targeted tab and keeps toolbar actions',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseWorkspaceLayout(
            title: 'Module title',
            subtitle: 'IT302 • Published',
            eyebrow: 'MODULE AUTHORING',
            initialIndex: 1,
            labels: const ['Learning materials', 'Assessments'],
            onRefresh: () async {},
            toolbarActions: [
              IconButton(
                tooltip: 'Retry missing notifications',
                onPressed: () => retried = true,
                icon: const Icon(Icons.notifications_active_outlined),
              ),
            ],
            pages: [
              ListView(children: const [Text('Material editor')]),
              ListView(children: const [Text('Assessment editor')]),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assessment editor').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Retry missing notifications'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
