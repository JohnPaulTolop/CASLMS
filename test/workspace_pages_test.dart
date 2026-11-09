import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/landing_page.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/student/activities_scores_page.dart';
import 'package:caslms/screens/student/posted_grades_page.dart';
import 'package:caslms/services/semester_grades_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PageApi implements GradebookApi {
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (action == 'posted') {
      return {
        'success': true,
        'terms': [
          {'id': 'term', 'label': '2026 First Semester'},
        ],
        'termId': 'term',
        'subjects': [
          {
            'courseId': 'course',
            'courseTitle': 'Information Systems and Technology',
            'courseCode': 'IT101',
            'termId': 'term',
            'posted': true,
            'revision': 1,
          },
        ],
      };
    }
    if (action == 'activities') {
      return {
        'activities': [
          {
            'title': 'Database design assessment',
            'courseId': 'course',
            'subject': 'Information Systems and Technology',
            'activityType': 'assignment',
            'submittedAt': '2026-10-25T09:00:00Z',
            'totalPoints': 100,
            'pointsEarned': 85,
            'percentage': 85,
            'status': 'graded',
          },
        ],
      };
    }
    throw const GradebookException(
      'Invalid Student ID or Password',
      status: 401,
    );
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  testWidgets(
    'Logout dialog wraps, scrolls, and supports cancellation on short screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 320);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    confirmed = await confirmWorkspaceLogout(context),
                child: const Text('Open logout'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open logout'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      await tester.tap(find.text('Open logout'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Grade credentials and actions remain reachable in landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PostedGradesScreen(api: _PageApi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reveal-course')),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reveal-course')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('reveal-password')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reveal-password')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 600.0, 900.0, 1024.0, 1440.0, 2560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Forms, filters and dialogs at $width, text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: PostedGradesScreen(api: _PageApi()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('reveal-course')),
          200,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('reveal-course')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Verify & Reveal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify & Reveal'));
        await tester.pumpAndSettle();
        expect(
          find.text('Enter your Student ID and account password.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: ActivitiesScoresScreen(api: _PageApi()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Search activities'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byType(TextField).first,
          'no matching activity',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const LandingScreen()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Get started'));
        await tester.pumpAndSettle();
        expect(find.text('Get started').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
