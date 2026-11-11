import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_quick_create_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const courses = <Map<String, dynamic>>[
  {
    'id': 'course',
    'code': 'IT302',
    'title': 'Mobile development',
    'status': 'active',
  },
];
const sections = <Map<String, dynamic>>[
  {'id': '4C', 'name': '4C', 'status': 'active', 'courseId': 'course'},
  {'id': '4D', 'name': '4D', 'status': 'active', 'courseId': 'course'},
];
const modules = <Map<String, dynamic>>[
  {
    'id': 'm',
    'courseId': 'course',
    'title': 'Chapter 1',
    'sectionIds': ['4C'],
  },
  {
    'id': 'other',
    'courseId': 'course',
    'title': '4D chapter',
    'sectionIds': ['4D'],
  },
];

Future<void> pick(WidgetTester t, int index, String text) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
  await t.ensureVisible(dropdown);
  await t.pumpAndSettle();
  await t.tap(dropdown);
  await t.pumpAndSettle();
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

Future<void> mount(
  WidgetTester t,
  Widget page, {
  double width = 390,
  bool dark = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 1000);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(theme: dark ? AppTheme.dark : AppTheme.light, home: page),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Changing course clears the previous section and module', (
    t,
  ) async {
    await mount(
      t,
      InstructorQuickCreateScreen(
        kind: InstructorCreateKind.material,
        currentUid: () => 'teacher',
        loadCourses: () async => [
          ...courses,
          {
            'id': 'second',
            'code': 'IT303',
            'title': 'Other course',
            'status': 'active',
          },
        ],
        loadSections: (_) async => sections,
        loadModules: (_) async => modules,
      ),
    );
    await pick(t, 0, 'IT302 • Mobile development');
    await pick(t, 1, '4C');
    await pick(t, 2, 'Chapter 1');
    await pick(t, 0, 'IT303 • Other course');
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('Changed account cannot continue with the previous selection', (
    t,
  ) async {
    var uid = 'teacher', opened = false;
    await mount(
      t,
      InstructorQuickCreateScreen(
        kind: InstructorCreateKind.module,
        currentUid: () => uid,
        loadCourses: () async => courses,
        loadSections: (_) async => sections,
        onReady: (_, s, m) => opened = true,
      ),
    );
    await pick(t, 0, 'IT302 • Mobile development');
    await pick(t, 1, '4C');
    uid = 'another-teacher';
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(opened, isFalse);
    expect(t.takeException(), isNull);
  });
  for (final kind in InstructorCreateKind.values) {
    testWidgets('$kind selects the target before opening its editor', (
      t,
    ) async {
      List<String?>? ready;
      await mount(
        t,
        InstructorQuickCreateScreen(
          kind: kind,
          currentUid: () => 'teacher',
          loadCourses: () async => courses,
          loadSections: (_) async => sections,
          loadModules: (_) async => modules,
          onReady: (c, s, m) => ready = [c, s, m],
        ),
      );
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await pick(t, 0, 'IT302 • Mobile development');
      await pick(t, 1, '4C');
      if (kind != InstructorCreateKind.module) {
        await t.tap(find.byType(DropdownButtonFormField<String>).last);
        await t.pumpAndSettle();
        expect(find.text('4D chapter'), findsNothing);
        await t.tap(find.text('Chapter 1').last);
        await t.pumpAndSettle();
      }
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(ready, [
        'course',
        '4C',
        kind == InstructorCreateKind.module ? null : 'm',
      ]);
      expect(t.takeException(), isNull);
    });
  }
  for (final width in [320.0, 900.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('Creation location at $width dark $dark with large text', (
        t,
      ) async {
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await mount(
          t,
          InstructorQuickCreateScreen(
            kind: InstructorCreateKind.assessment,
            currentUid: () => 'teacher',
            loadCourses: () async => courses,
            loadSections: (_) async => sections,
            loadModules: (_) async => modules,
          ),
          width: width,
          dark: dark,
        );
        await pick(t, 0, 'IT302 • Mobile development');
        await pick(t, 1, '4C');
        await t.ensureVisible(
          find.byType(DropdownButtonFormField<String>).last,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('A section removed before Continue cannot open an editor', (
    t,
  ) async {
    var calls = 0, opened = false;
    await mount(
      t,
      InstructorQuickCreateScreen(
        kind: InstructorCreateKind.module,
        currentUid: () => 'teacher',
        loadCourses: () async => courses,
        loadSections: (_) async => ++calls == 1 ? sections : [],
        onReady: (_, s, m) => opened = true,
      ),
    );
    await pick(t, 0, 'IT302 • Mobile development');
    await pick(t, 1, '4C');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(opened, isFalse);
    expect(
      find.text(
        'The selected course, section, or module is no longer available. Please choose again.',
      ),
      findsOneWidget,
    );
  });
}
