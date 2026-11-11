import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_ui.dart';
import 'package:caslms/screens/instructor/instructor_workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Dashboard greeting and course creation menu at $width dark $dark',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(width, 1000);
          addTearDown(t.view.reset);
          final actions = <String>[];
          await t.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: Builder(
                builder: (context) => instructorScaffold(
                  context: context,
                  title: '',
                  showHeading: false,
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: InstructorDashboardContent(
                      name: 'Teacher',
                      enrollments: 20,
                      pending: 3,
                      courseCount: 1,
                      courses: const [],
                      onCourse: (_) {},
                      onCourses: () {},
                      onGrade: () {},
                      onAi: () {},
                      onCalendar: () {},
                      onAnnouncements: () {},
                      onHelp: () {},
                      onCreate: () => actions.add('course'),
                      onCreateModule: () => actions.add('module'),
                      onCreateAssessment: () => actions.add('assessment'),
                      onCreateMaterial: () => actions.add('material'),
                      onRefresh: () => actions.add('refresh'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Welcome back, Teacher.'), findsOneWidget);
          expect(find.text('Teaching overview'), findsNothing);
          expect(find.text('A clear view of your classroom.'), findsNothing);
          await t.tap(find.byTooltip('Refresh overview'));
          expect(actions.last, 'refresh');
          for (final action in ['course', 'module', 'assessment', 'material']) {
            final menu = find.byTooltip('Create course content');
            await t.ensureVisible(menu);
            await t.pumpAndSettle();
            await t.tap(menu);
            await t.pumpAndSettle();
            final label = action == 'material'
                ? 'Add learning material'
                : 'Create $action';
            await t.tap(find.text(label));
            await t.pumpAndSettle();
            expect(actions.last, action);
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
