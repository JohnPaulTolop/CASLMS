import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_task_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 900.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('Selected module is clear at $width dark $dark', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 1000);
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: InstructorTaskScaffold(
              title: 'Chapter 2: Advanced mobile development',
              subtitle: 'IT302 • published',
              highlightHeading: true,
              body: ListView(
                children: const [
                  Text('Learning materials'),
                  Text('Assessments'),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('selected-module-heading')),
          findsOneWidget,
        );
        expect(find.text('Selected module'), findsOneWidget);
        expect(
          find.text('Chapter 2: Advanced mobile development'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
