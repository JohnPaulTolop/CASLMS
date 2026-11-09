import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/student/student_progress_view.dart';
import 'package:caslms/screens/shared/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const courseTitle =
    'Advanced Mobile Development and Collaborative Software Engineering';
final course = <String, dynamic>{
  'courseId': 'course',
  'code': 'IT302',
  'title': courseTitle,
  'totalItems': 4,
  'completedItems': 1,
  'learningProgress': .25,
  'hasGrades': true,
  'academicAvailablePoints': 5,
  'academicPerformance': .35,
};
final learning = <String, dynamic>{
  'totalItems': 4,
  'completedItems': 1,
  'learningProgress': .25,
  'completedModules': 0,
  'totalModules': 11,
  'moduleProgress': 0,
  'submittedAssignments': 0,
  'totalAssignments': 0,
  'assignmentProgress': 0,
  'completedQuizzes': 1,
  'totalQuizzes': 4,
  'quizProgress': .25,
  'courses': [course],
};
final academic = <String, dynamic>{
  'hasGrades': true,
  'earnedPoints': 1.75,
  'availablePoints': 5,
  'percentage': .35,
  'quizEarnedPoints': 1.75,
  'quizAvailablePoints': 5,
};

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Results refresh stays beside the title at mobile text $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var refreshed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: WorkspaceHeading(
                  title: 'My progress',
                  subtitle: 'Your learning and academic performance over time.',
                  eyebrow: 'YOUR LEARNING',
                  inlineActions: true,
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => refreshed = true,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getCenter(find.byIcon(Icons.refresh_rounded)).dy,
          lessThan(
            tester
                .getTopLeft(
                  find.text(
                    'Your learning and academic performance over time.',
                  ),
                )
                .dy,
          ),
        );
        await tester.tap(find.byTooltip('Refresh'));
        expect(refreshed, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Wide Progress places course cards in two columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StudentProgressView(
              learning: {
                ...learning,
                'courses': [
                  for (var i = 0; i < 3; i++) {...course, 'title': 'Course $i'},
                ],
              },
              academic: academic,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Course 0'));
    final second = tester.getTopLeft(find.text('Course 1'));
    final third = tester.getTopLeft(find.text('Course 2'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx + 400));
    expect(third.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 900.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Progress layout at $width and text $scale preserves scores and course action',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          String? opened;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: StudentProgressView(
                    learning: learning,
                    academic: academic,
                    onCourse: (row) => opened = row['courseId'] as String,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('1 of 4 activities completed'), findsOneWidget);
          expect(find.text('1.75 / 5 assessed points'), findsOneWidget);
          expect(find.text('0 / 0'), findsOneWidget);
          expect(find.text('Completion by type'), findsOneWidget);
          expect(find.text('Completion breakdown'), findsNothing);
          expect(find.text('Activity balance'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text(courseTitle));
          await tester.pumpAndSettle();
          await tester.tap(find.text(courseTitle));
          expect(opened, 'course');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Empty progress distinguishes unassessed work from zero scores', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: StudentProgressView(learning: {}, academic: {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.text('Scores appear once work is assessed.'), findsOneWidget);
    expect(find.text('No active courses yet'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
