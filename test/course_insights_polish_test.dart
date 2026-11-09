// SDK reference/query fakes isolate rendering from production data.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';
import 'dart:ui' as ui;

import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_analytics_page.dart';
import 'package:caslms/screens/instructor/instructor_course_content.dart';
import 'package:caslms/screens/shared/course_banner.dart';
import 'package:caslms/screens/shared/course_workspace_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'teacher';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _Db extends Fake implements FirebaseFirestore {
  _Db({this.role = 'instructor'});
  final String role;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path, role);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.name, this.role);
  final String name, role;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(role);
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #where ? this : super.noSuchMethod(i);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot([
    if (name == 'courses')
      _Row('course', {
        'code': 'IT302',
        'title': 'Mobile Development',
        'instructorId': 'teacher',
        'status': 'active',
      }),
    if (name == 'modules')
      _Row('mod', {
        'title': 'Foundations',
        'order': 1,
        'courseId': 'course',
        'status': 'published',
      }),
  ]);
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.role);
  final String role;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Row('teacher', {'role': role, 'status': 'active'});
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Row extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Row(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => row;
}

Future<void> _mount(
  WidgetTester t,
  Widget page, {
  double width = 390,
  bool dark = true,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 1000);
  addTearDown(t.view.reset);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: RepaintBoundary(key: const ValueKey('fix-preview'), child: page),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_COURSE_FIX')) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('fix-preview')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/course-fix-preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto');
    for (final face in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$face.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [390.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('Actual class insights surfaces at $width dark $dark', (
        t,
      ) async {
        await _mount(
          t,
          InstructorAnalyticsScreen(firestore: _Db(), auth: _Auth()),
          width: width,
          dark: dark,
        );
        expect(find.text('Class Average'), findsOneWidget);
        expect(find.text('No enrolled students'), findsWidgets);
        for (final label in [
          'Class Average',
          'Active Today',
          'No enrolled students',
          'No quiz analytics yet',
        ]) {
          final card = find.ancestor(
            of: find.text(label).first,
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          );
          expect(
            (t.widget<Container>(card.first).decoration! as BoxDecoration)
                .color,
            dark ? DarkAppColors.surface : Colors.white,
          );
        }
        expect(t.takeException(), isNull);
        await _capture(t, 'insights-$width-$dark');
      });
    }
  }
  testWidgets('Analytics still rejects other account roles', (t) async {
    await _mount(
      t,
      InstructorAnalyticsScreen(
        firestore: _Db(role: 'student'),
        auth: _Auth(),
      ),
    );
    expect(
      find.text('Only instructors can view cohort analytics.'),
      findsOneWidget,
    );
    expect(find.text('Class Average'), findsNothing);
  });
  for (final width in [390.0, 1440.0, 1920.0]) {
    testWidgets(
      'Course edges, tabs, subtle actions and mobile add module at $width',
      (t) async {
        var created = 0;
        await _mount(
          t,
          CourseWorkspaceLayout(
            title: 'Advance Mobile Development',
            subtitle: 'IT302 · First Semester',
            onRefresh: () async {},
            actions: [
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Sections'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Live classroom'),
              ),
            ],
            labels: const ['Content', 'Activities', 'Grades', 'Students'],
            pages: [
              InstructorCourseContent(
                modules: const [
                  {'id': 'one', 'title': 'Chapter 1', 'status': 'published'},
                ],
                materials: const [],
                assessments: const [],
                onCreate: () => created++,
                onManage: (_) {},
                onMaterial: (_, _) {},
                onAssessment: (_) {},
              ),
              for (var i = 0; i < 3; i++)
                const Center(child: Text('Another tab')),
            ],
          ),
          width: width,
        );
        final module = find
            .ancestor(
              of: find.text('Chapter 1'),
              matching: find.byType(Material),
            )
            .first;
        final banner = find.byType(CourseBanner);
        expect(t.getTopLeft(module).dx, closeTo(t.getTopLeft(banner).dx, .1));
        expect(
          t.getBottomRight(module).dx,
          closeTo(t.getBottomRight(banner).dx, .1),
        );
        if (width < 600) {
          expect(find.text('Add module'), findsNothing);
          await t.tap(find.byTooltip('Add module'));
        } else {
          expect(
            find.byKey(const ValueKey('add-module-floating')),
            findsNothing,
          );
          await t.tap(find.text('Add module'));
        }
        expect(created, 1);
        final filled = find.widgetWithText(FilledButton, 'Sections');
        final outline = find.widgetWithText(OutlinedButton, 'Live classroom');
        final f = FilledButtonTheme.of(t.element(filled)).style!;
        final o = OutlinedButtonTheme.of(t.element(outline)).style!;
        expect(f.backgroundColor!.resolve({}), o.backgroundColor!.resolve({}));
        expect(f.foregroundColor!.resolve({}), DarkAppColors.link);
        await t.tap(find.text('Activities'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('add-module-floating')).hitTestable(),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.tap(find.text('Content'));
        await t.pumpAndSettle();
        await _capture(t, 'course-$width');
      },
    );
  }
  testWidgets('Shared text actions use the muted theme token in both themes', (
    t,
  ) async {
    for (final dark in [false, true]) {
      await _mount(
        t,
        Scaffold(
          body: TextButton(onPressed: () {}, child: const Text('View all')),
        ),
        dark: dark,
      );
      final context = t.element(find.text('View all'));
      expect(
        TextButtonTheme.of(context).style!.foregroundColor!.resolve({}),
        dark ? DarkAppColors.link : LightAppColors.link,
      );
    }
  });
  test('Muted text actions retain readable contrast', () {
    double contrast(Color foreground, Color background) =>
        (foreground.computeLuminance() > background.computeLuminance()
        ? (foreground.computeLuminance() + .05) /
              (background.computeLuminance() + .05)
        : (background.computeLuminance() + .05) /
              (foreground.computeLuminance() + .05));
    expect(
      contrast(LightAppColors.link, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DarkAppColors.link, DarkAppColors.background),
      greaterThanOrEqualTo(4.5),
    );
  });
}
