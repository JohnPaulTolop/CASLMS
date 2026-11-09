import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/shared/workspace_widgets.dart';
import 'package:caslms/screens/student/student_results_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bars follow nested page scrolling without reopening at idle', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 850);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkspaceShell(
          name: 'Student',
          destinations: studentDestinations,
          selectedIndex: 2,
          onSelected: (_) {},
          onInbox: () {},
          onLogout: () {},
          child: WorkspaceScrollingBody(
            header: const SizedBox(height: 180, child: Text('My tasks')),
            body: ListView.builder(
              key: const ValueKey('nested-page-list'),
              itemCount: 40,
              itemBuilder: (_, index) =>
                  SizedBox(height: 80, child: Text('Task $index')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey('nested-page-list'));
    final header = find.byKey(const ValueKey('header-theme-button'));
    final nav = find.byKey(const ValueKey('nav-2'));
    await tester.drag(page, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(header.hitTestable(), findsNothing);
    expect(nav.hitTestable(), findsNothing);
    await tester.drag(page, const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(header.hitTestable(), findsOneWidget);
    expect(nav.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    for (final dark in [false, true]) {
      testWidgets('Mobile bars follow scroll direction at $width, dark $dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 850);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        var selected = 0;
        late ValueChanged<int> select;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: StatefulBuilder(
              builder: (context, setState) {
                select = (index) => setState(() => selected = index);
                return WorkspaceShell(
                  name: 'Student',
                  destinations: studentDestinations,
                  selectedIndex: selected,
                  onSelected: select,
                  onInbox: () {},
                  onLogout: () {},
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: SingleChildScrollView(
                          key: const ValueKey('horizontal-filters'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              12,
                              (index) => Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('Filter $index'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          key: const ValueKey('mobile-page-scroll'),
                          children: List.generate(
                            50,
                            (index) => SizedBox(
                              height: 70,
                              child: Text('Lesson $index'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('header-theme-button'));
        final navigation = find.byKey(const ValueKey('mobile-navigation'));
        final page = find.byKey(const ValueKey('mobile-page-scroll'));
        final originalHeight = tester.getSize(page).height;
        expect(header.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav-0')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.getSize(navigation).height, lessThanOrEqualTo(60));
        expect(
          (tester.widget<Container>(navigation).decoration! as BoxDecoration)
              .border,
          isNull,
        );
        for (final label in ['Home', 'Courses', 'AI', 'Tasks', 'More']) {
          expect(find.text(label), findsNothing);
          expect(find.byTooltip(label), findsOneWidget);
        }
        final ai = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('nav-6')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect((ai.shape! as RoundedRectangleBorder).side, BorderSide.none);
        expect(ai.color, Colors.transparent);
        final aiIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('nav-6')),
            matching: find.byType(Icon),
          ),
        );
        expect(
          aiIcon.color,
          dark ? DarkAppColors.primaryBlue : LightAppColors.primaryBlue,
        );
        expect(
          (tester.widget<Container>(navigation).decoration! as BoxDecoration)
              .color,
          dark ? DarkAppColors.background : LightAppColors.background,
        );
        await tester.drag(
          find.byKey(const ValueKey('horizontal-filters')),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        expect(header.hitTestable(), findsOneWidget);
        await tester.drag(page, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(header.hitTestable(), findsNothing);
        expect(find.byKey(const ValueKey('nav-0')).hitTestable(), findsNothing);
        expect(tester.getSize(page).height, greaterThan(originalHeight + 60));
        await tester.drag(page, const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(header.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav-0')).hitTestable(),
          findsOneWidget,
        );
        await tester.drag(page, const Offset(0, -200));
        await tester.pumpAndSettle();
        select(1);
        await tester.pumpAndSettle();
        expect(header.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav-1')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Compact task heading and single-row Results tabs at text $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 850);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: WorkspaceHeading(
                          showEyebrow: false,
                          title: 'My tasks',
                          subtitle: 'Your upcoming work.',
                          eyebrow: 'YOUR LEARNING',
                          actions: [
                            IconButton(
                              tooltip: 'Calendar',
                              onPressed: () {},
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                            IconButton(
                              tooltip: 'Reload',
                              onPressed: () {},
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                      StudentResultTabs(
                        selected: selected,
                        onSelected: (index) => setState(() => selected = index),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('YOUR LEARNING'), findsNothing);
        expect(
          tester.getTopLeft(find.byTooltip('Calendar')).dy,
          closeTo(tester.getTopLeft(find.text('My tasks')).dy, 8),
        );
        expect(
          tester.getTopLeft(find.byTooltip('Calendar')).dy,
          closeTo(tester.getTopLeft(find.byTooltip('Reload')).dy, 1),
        );
        final chips = tester.getTopLeft(find.text('Progress')).dy;
        final tabStrip = tester.getRect(find.byType(StudentResultTabs));
        final chip = tester.getRect(find.byType(ChoiceChip).first);
        expect(
          chip.top - tabStrip.top,
          closeTo(tabStrip.bottom - chip.bottom, 1),
        );
        expect(
          tester.getTopLeft(find.text('Activity scores')).dy,
          closeTo(chips, 1),
        );
        expect(
          tester.getTopLeft(find.text('Official grades')).dy,
          closeTo(chips, 1),
        );
        await tester.ensureVisible(find.text('Official grades'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Official grades'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Main page headings omit eyebrows on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: WorkspaceHeading(
            showEyebrow: false,
            title: 'My progress',
            eyebrow: 'YOUR LEARNING',
            subtitle: 'See your learning progress.',
          ),
        ),
      ),
    );
    expect(find.text('YOUR LEARNING'), findsNothing);
    expect(find.text('My progress'), findsOneWidget);
    expect(find.text('See your learning progress.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
