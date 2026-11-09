import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 900.0, 1920.0]) {
    for (final dark in [false, true]) {
      testWidgets('Toolbar follows content edges at $width dark $dark', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 1000);
        addTearDown(t.view.reset);
        final inset = width < 600 ? 16.0 : 24.0;
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: InstructorTaskScaffold(
              title: 'Module',
              subtitle: 'IT302',
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                ),
              ],
              body: ListView(
                padding: EdgeInsets.symmetric(horizontal: inset),
                children: const [
                  SizedBox(key: ValueKey('content-edge'), height: 100),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final content = t.getRect(find.byKey(const ValueKey('content-edge')));
        final back = t.getRect(find.byTooltip('Back'));
        final refresh = t.getRect(find.byTooltip('Refresh'));
        expect(back.left, closeTo(content.left, 1));
        expect(refresh.right, lessThanOrEqualTo(content.right + 1));
        expect(content.right - refresh.right, lessThan(10));
        expect(find.text('Teaching workspace'), findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
