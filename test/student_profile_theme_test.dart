import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/student/student_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 900.0]) {
    testWidgets('Profile editor follows theme and keeps edits at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, themeMode, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudentProfileEditor(
                  profile: const {
                    'displayName': 'Test Student',
                    'email': 'student@example.edu',
                    'universityId': '12345678',
                    'yearLevel': 2,
                  },
                  onSaved: (_) {},
                  onBusyChanged: (_) {},
                  onResetPassword: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Display name',
      );
      await tester.enterText(name, 'Unsaved student name');
      for (final selected in [ThemeMode.dark, ThemeMode.light]) {
        mode.value = selected;
        await tester.pumpAndSettle();
        final dark = selected == ThemeMode.dark;
        final editor = find.byType(StudentProfileEditor);
        final container = tester.widget<Container>(
          find.descendant(of: editor, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(
          decoration.color,
          dark ? DarkAppColors.surface : LightAppColors.surface,
        );
        expect(
          (decoration.border! as Border).top.color,
          dark ? DarkAppColors.inputBorder : LightAppColors.inputBorder,
        );
        final field = tester.widget<TextField>(name);
        expect(
          field.decoration!.fillColor,
          dark ? DarkAppColors.background : LightAppColors.background,
        );
        expect(
          (field.decoration!.enabledBorder! as OutlineInputBorder)
              .borderSide
              .color,
          dark ? DarkAppColors.inputBorder : LightAppColors.inputBorder,
        );
        expect(field.controller!.text, 'Unsaved student name');
        expect(
          Theme.of(tester.element(editor)).canvasColor,
          dark ? DarkAppColors.surface : AppTheme.light.canvasColor,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
