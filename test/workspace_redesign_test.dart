import 'dart:io';
import 'dart:ui' as ui;

import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/shared/workspace_widgets.dart';
import 'package:caslms/screens/student/student_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures are deliberately isolated from the production data/controller.
final fixtureCourses = [
  courseSummary(
    {
      'code': 'IT 310',
      'title': 'Data Structures and Algorithms',
      'category': 'COMPUTER SCIENCE',
    },
    0,
    progress: .75,
  ),
  courseSummary(
    {
      'code': 'IT 320',
      'title': 'Web Technologies',
      'category': 'WEB DEVELOPMENT',
    },
    1,
    progress: .60,
  ),
  courseSummary(
    {
      'code': 'IT 330',
      'title': 'Mobile Development',
      'category': 'APP DEVELOPMENT',
    },
    2,
    progress: .40,
  ),
];
const fixtureAssessments = [
  AssessmentSummary(
    title: 'Data Structures Quiz',
    course: 'IT 310',
    day: '25',
    month: 'OCT',
    due: 'Oct 25, 2026',
    time: '9:00 AM',
    type: 'Quiz',
    color: AppColors.primaryBlue,
    tint: AppColors.blueTint,
  ),
  AssessmentSummary(
    title: 'Web Development Activity',
    course: 'IT 320',
    day: '27',
    month: 'OCT',
    due: 'Oct 27, 2026',
    time: '1:00 PM',
    type: 'Activity',
    color: AppColors.green,
    tint: AppColors.greenTint,
  ),
];

Future<void> loadWorkspaceFonts() async {
  final loader = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Roboto-$weight.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

class DashboardFixture extends StatelessWidget {
  const DashboardFixture({
    super.key,
    required this.onAction,
    this.empty = false,
    this.error = false,
    this.destinations = studentDestinations,
    this.containerWidth,
    this.themeMode = ThemeMode.light,
  });
  final ValueChanged<String> onAction;
  final bool empty, error;
  final List<WorkspaceDestination> destinations;
  final double? containerWidth;
  final ThemeMode themeMode;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    debugShowCheckedModeBanner: false,
    home: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: containerWidth,
        child: WorkspaceShell(
          name: 'Rolando Mabansag',
          unreadCount: 3,
          destinations: destinations,
          selectedIndex: 0,
          onSelected: (index) => onAction('nav-$index'),
          onInbox: () => onAction('inbox'),
          onLogout: () => onAction('logout'),
          child: LayoutBuilder(
            builder: (context, box) => ListView(
              key: const ValueKey('fixture-scroll'),
              padding: EdgeInsets.fromLTRB(
                workspaceInset(box.maxWidth),
                0,
                workspaceInset(box.maxWidth),
                28,
              ),
              children: [
                StudentDashboardView(
                  firstName: 'Rolando',
                  courses: empty ? [] : fixtureCourses,
                  assessments: empty ? [] : fixtureAssessments,
                  activeCourseCount: empty ? 0 : 3,
                  assessmentCount: error
                      ? null
                      : empty
                      ? 0
                      : 2,
                  pendingCount: error
                      ? null
                      : empty
                      ? 0
                      : 1,
                  announcementCount: error
                      ? null
                      : empty
                      ? 0
                      : 2,
                  summaryError: error
                      ? 'Some dashboard totals could not be updated. Pull to refresh.'
                      : null,
                  onRetry: () => onAction('retry'),
                  onCourse: (index) => onAction('course-$index'),
                  onAssessment: (index) => onAction('assessment-$index'),
                  onCourses: () => onAction('courses'),
                  onTasks: () => onAction('tasks'),
                  onInbox: () => onAction('inbox'),
                  onInvitations: () => onAction('invitations'),
                  onNotes: () => onAction('notes'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String file) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('verification/design/$file.png')
        .writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadWorkspaceFonts);

  for (final width in [390.0, 1440.0]) {
    testWidgets('Dashboard surfaces follow theme at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1100);
      addTearDown(tester.view.reset);
      for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.light]) {
        await tester.pumpWidget(
          DashboardFixture(onAction: (_) {}, themeMode: mode),
        );
        await tester.pumpAndSettle();
        final dark = mode == ThemeMode.dark;
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
          dark ? DarkAppColors.background : LightAppColors.background,
        );
        final surfaces = find.descendant(
          of: find.byType(WorkspaceSurface),
          matching: find.byType(Container),
        );
        final surfaceColors = tester
            .widgetList<Container>(surfaces)
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.color);
        expect(
          surfaceColors,
          contains(dark ? DarkAppColors.surface : LightAppColors.surface),
        );
        if (dark) expect(surfaceColors, isNot(contains(Colors.white)));
        final course = find.byKey(const ValueKey('course-IT 310'));
        final card = tester.widget<Material>(
          find.ancestor(of: course, matching: find.byType(Material)).first,
        );
        expect(card.color, dark ? DarkAppColors.surface : Colors.white);
        final selectedNavigation = find.byKey(const ValueKey('nav-0'));
        final navigationMaterial = tester.widget<Material>(
          find
              .ancestor(of: selectedNavigation, matching: find.byType(Material))
              .first,
        );
        expect(
          navigationMaterial.color,
          dark ? DarkAppColors.blueTint : LightAppColors.blueTint,
        );
        final selectedIcon = tester.widget<Icon>(
          find
              .descendant(of: selectedNavigation, matching: find.byType(Icon))
              .first,
        );
        expect(
          selectedIcon.color,
          dark ? DarkAppColors.primaryBlue : LightAppColors.primaryBlue,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
  for (final width in [320.0, 390.0, 600.0, 900.0, 1024.0, 1440.0, 2560.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Dashboard $width px, text $scale: layout, scroll and actions',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1100);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final actions = <String>[];
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: DashboardFixture(onAction: actions.add),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final desktop = width >= 1100 && scale <= 1.4;
          expect(
            find.byKey(const ValueKey('desktop-sidebar')),
            desktop ? findsOneWidget : findsNothing,
          );
          if (Platform.environment['CAPTURE_DESIGN'] == '1') {
            await capture(
              tester,
              key,
              'actual-${width.toInt()}-text${scale.toInt()}',
            );
          }
          for (final entry in <(Finder, String)>[
            (find.byKey(const ValueKey('continue-course')), 'course-0'),
            (find.byKey(const ValueKey('course-IT 330')), 'course-2'),
            (find.text('Data Structures Quiz'), 'assessment-0'),
            (find.text('View assessments'), 'tasks'),
            (find.text('Open your inbox'), 'inbox'),
            (find.byKey(const ValueKey('course-invitations')), 'invitations'),
          ]) {
            await tester.ensureVisible(entry.$1);
            await tester.pumpAndSettle();
            expect(entry.$1.hitTestable(), findsOneWidget);
            await tester.tap(entry.$1);
            await tester.pumpAndSettle();
            expect(actions.last, entry.$2);
            expect(tester.takeException(), isNull);
          }
          if (!desktop) {
            await tester.tap(find.byKey(const ValueKey('nav-more')));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Results'));
            await tester.tap(find.text('Results'));
            await tester.pumpAndSettle();
            expect(actions.last, 'nav-3');
          } else {
            await tester.ensureVisible(find.byKey(const ValueKey('nav-3')));
            await tester.tap(find.byKey(const ValueKey('nav-3')));
            expect(actions.last, 'nav-3');
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('desktop-sidebar')))
                  .width,
              224,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(600, 320),
    const Size(1440, 400),
  ]) {
    testWidgets('Short screen $size: safe areas and complete navigation', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final actions = <String>[];
      await tester.pumpWidget(DashboardFixture(onAction: actions.add));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('A little progress, every day.'));
      await tester.pumpAndSettle();
      expect(
        find.text('A little progress, every day.').hitTestable(),
        findsOneWidget,
      );
      if (size.width < 1100) {
        expect(
          tester.getBottomRight(find.text('A little progress, every day.')).dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('mobile-navigation')))
                .dy,
          ),
        );
        for (final d in studentDestinations.where(
          (d) => [0, 1, 6, 2].contains(d.index),
        )) {
          await tester.tap(find.byKey(ValueKey('nav-${d.index}')));
          expect(actions.last, 'nav-${d.index}');
        }
        for (final d in studentDestinations.where(
          (d) => ![0, 1, 6, 2].contains(d.index),
        )) {
          await tester.tap(find.byKey(const ValueKey('nav-more')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(d.label));
          await tester.tap(find.text(d.label));
          await tester.pumpAndSettle();
          expect(actions.last, 'nav-${d.index}');
        }
      } else {
        await tester.ensureVisible(find.text('Student account'));
        expect(find.text('Student account').hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Container width controls navigation independently of viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2560, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DashboardFixture(onAction: (_) {}, containerWidth: 600),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Unavailable totals stay unknown and empty courses open invitations',
    (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(
        DashboardFixture(onAction: actions.add, empty: true, error: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsNWidgets(4));
      await tester.ensureVisible(find.text('Refresh dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh dashboard'));
      expect(actions.last, 'retry');
      await tester.ensureVisible(find.byKey(const ValueKey('continue-course')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('continue-course')));
      expect(actions.last, 'invitations');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Keyboard focus activates the real course callback', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WorkspaceCourseCard(
            course: fixtureCourses.first,
            onTap: () => opened = true,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, isTrue);
  });
}
