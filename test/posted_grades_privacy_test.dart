import 'package:caslms/screens/shared/role_navigation_bar.dart';
import 'package:caslms/screens/student/posted_grades_page.dart';
import 'package:caslms/services/semester_grades_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _GradesApi implements GradebookApi {
  final List<String> actions = [];
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    actions.add(action);
    if (action == 'posted') {
      return {
        'success': true,
        'terms': [
          {'id': '2026|1st', 'label': '2026 1st Semester'},
        ],
        'termId': '2026|1st',
        'subjects': [
          {
            'courseId': 'own-course',
            'courseTitle': 'Information Systems',
            'courseCode': 'IT101',
            'termId': '2026|1st',
            'posted': true,
            'revision': 1,
          },
        ],
      };
    }
    if (data['campusId'] != '12345' || data['password'] != 'correct-password') {
      throw const GradebookException(
        'Invalid Student ID or Password',
        status: 401,
      );
    }
    return {
      'success': true,
      'grade': '1.75',
      'result': 'Passed',
      'description': '',
    };
  }
}

void main() {
  testWidgets(
    'a posted subject contains no grade on initial load; credentials are required and cleared',
    (tester) async {
      final api = _GradesApi();
      await tester.pumpWidget(MaterialApp(home: PostedGradesScreen(api: api)));
      await tester.pumpAndSettle();
      expect(api.actions, ['posted']);
      expect(find.text('Grade: [ Hidden ]'), findsOneWidget);
      expect(find.textContaining('1.75'), findsNothing);
      expect(find.byKey(const ValueKey('reveal-own-course')), findsOneWidget);
      expect(find.byKey(const ValueKey('reveal-other-course')), findsNothing);
      await tester.tap(find.text('Reveal Grade'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reveal-student-id')),
        '99999',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reveal-password')),
        'bad-password',
      );
      await tester.tap(find.text('Verify & Reveal'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid Student ID or Password'), findsOneWidget);
      expect(find.textContaining('1.75'), findsNothing);
      final password = tester.widget<TextField>(
        find.byKey(const ValueKey('reveal-password')),
      );
      expect(password.obscureText, isTrue);
      expect(password.controller!.text, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('reveal-student-id')),
        '12345',
      );
      await tester.enterText(
        find.byKey(const ValueKey('reveal-password')),
        'correct-password',
      );
      await tester.tap(find.text('Verify & Reveal'));
      await tester.pumpAndSettle();
      expect(find.text('Grade: 1.75 · Passed'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh and hide grades'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1.75'), findsNothing);
      expect(find.text('Grade: [ Hidden ]'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile More navigation exposes both grade destinations without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: RoleNavigationBar(
              selectedIndex: 0,
              instructor: false,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Activities & Scores'), findsOneWidget);
      expect(find.text('Posted Grades'), findsOneWidget);
      await tester.ensureVisible(find.text('Posted Grades'));
      await tester.tap(find.text('Posted Grades'));
      await tester.pumpAndSettle();
      expect(selected, 8);
      expect(tester.takeException(), isNull);
    },
  );
}
