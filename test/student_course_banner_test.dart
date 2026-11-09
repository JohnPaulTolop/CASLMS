import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/workspace_widgets.dart';
import 'package:caslms/screens/shared/course_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const title = 'Advance Mobile Development and Collaborative Applications';
  for (var index = 0; index < 4; index++) {
    for (final dark in [false, true]) {
      testWidgets('Course card and cover share accent $index, dark $dark', (
        tester,
      ) async {
        final course = courseSummary(
          {'code': 'IT302', 'title': title},
          index,
          progress: .25,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    CourseBanner(color: course.color, child: const Text(title)),
                    WorkspaceCourseCard(course: course, onTap: () {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        final cover = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(CourseBanner),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = cover.decoration as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          progress.color!.withValues(alpha: dark ? .20 : .14),
        );
        expect(
          decoration.color,
          Color.alphaBlend(
            progress.color!.withValues(alpha: dark ? .08 : .07),
            dark ? DarkAppColors.surface : LightAppColors.surface,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 390.0, 900.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Course cover at $width, dark $dark, text $scale', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CourseBanner(
                        color: AppColors.primaryBlue,
                        child: WorkspaceHeading(
                          eyebrow: 'COURSE LEARNING WORKSPACE',
                          title: title,
                          subtitle: 'IT302 • Instructor: SR JP',
                        ),
                      ),
                      Text('Course content'),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          final text = tester.widget<Text>(find.text(title));
          expect(text.style!.fontSize, width < 600 ? 30 : 35);
          expect(text.style!.fontWeight, FontWeight.w700);
          expect(text.style!.letterSpacing, -1.1);
          expect(text.style!.height, 1.15);
          expect(find.text('IT302 • Instructor: SR JP'), findsOneWidget);
          final bannerRect = tester.getRect(find.byType(CourseBanner));
          final headingRect = tester.getRect(find.byType(WorkspaceHeading));
          expect(
            bannerRect.bottom - headingRect.bottom,
            closeTo(width - 40 < 700 ? 16 : 20, 1),
          );
          final contentRect = tester.getRect(find.text('Course content'));
          expect(bannerRect.bottom, lessThanOrEqualTo(contentRect.top));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
