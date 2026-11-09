import 'package:caslms/core/app_theme.dart';
import 'package:caslms/core/theme_notifier.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeNotifier.instance.setThemeMode(ThemeMode.light);
  });

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'Header theme button is reachable and persists theme at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        final notifier = ThemeNotifier.instance;
        await notifier.setThemeMode(ThemeMode.light);
        await tester.pumpWidget(
          AnimatedBuilder(
            animation: notifier,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: notifier.themeMode,
              home: WorkspaceShell(
                name: 'Student',
                destinations: studentDestinations,
                selectedIndex: 0,
                onSelected: (_) {},
                onInbox: () {},
                onLogout: () {},
                child: ListView(
                  key: const ValueKey('header-scroll'),
                  children: List.generate(
                    40,
                    (index) =>
                        SizedBox(height: 80, child: Text('Lesson $index')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('header-theme-button'));
        expect(button.hitTestable(), findsOneWidget);
        expect(find.byTooltip('Your profile'), findsNothing);
        expect(
          tester.getCenter(button).dx,
          lessThan(tester.getCenter(find.byTooltip('Notifications')).dx),
        );
        expect(
          tester.getCenter(find.byTooltip('Notifications')).dx,
          lessThan(tester.getCenter(find.byTooltip('Logout')).dx),
        );
        final top = tester.getTopLeft(button).dy;
        await tester.drag(
          find.byKey(const ValueKey('header-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        if (width < 1100) {
          expect(button.hitTestable(), findsNothing);
          expect(
            find.byKey(const ValueKey('nav-0')).hitTestable(),
            findsNothing,
          );
          await tester.drag(
            find.byKey(const ValueKey('header-scroll')),
            const Offset(0, 250),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('nav-0')).hitTestable(),
            findsOneWidget,
          );
        }
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(button).dy, top);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.light_mode_outlined),
          ),
          findsOneWidget,
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(notifier.themeMode, ThemeMode.dark);
        expect(Theme.of(tester.element(button)).brightness, Brightness.dark);
        expect(find.byTooltip('Switch to light mode'), findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.byIcon(Icons.dark_mode_outlined),
          ),
          findsOneWidget,
        );
        expect(
          (await SharedPreferences.getInstance()).getString('themeMode'),
          'dark',
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(notifier.themeMode, ThemeMode.light);
        expect(
          (await SharedPreferences.getInstance()).getString('themeMode'),
          'light',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
