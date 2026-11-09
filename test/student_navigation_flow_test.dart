import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/shared/workspace_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final listInsideColumn in [false, true]) {
    testWidgets(
      'Heading scrolls away with ${listInsideColumn ? 'filtered list' : 'progress content'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 600);
        addTearDown(tester.view.reset);
        final list = ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('Item $i')),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: WorkspaceScrollingBody(
                header: const SizedBox(
                  height: 200,
                  child: Text('Page heading'),
                ),
                body: listInsideColumn
                    ? Column(
                        children: [
                          const Text('Filters'),
                          Expanded(child: list),
                        ],
                      )
                    : list,
              ),
            ),
          ),
        );
        expect(find.text('Page heading').hitTestable(), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(find.text('Page heading').hitTestable(), findsNothing);
        expect(find.text('Item 8').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Mobile AI is directly accessible and Results remains in More', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: WorkspaceBottomNavigation(
            destinations: studentDestinations,
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );
    for (final label in ['Home', 'Courses', 'AI', 'Tasks']) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(find.text(label), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('nav-6')));
    expect(selected, 6);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });
}
