import 'package:flutter_test/flutter_test.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/session_gate.dart';
import 'package:caslms/services/campus_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class _SignedOutAuth extends Fake implements CampusAuthService {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> get authStateChanges => Stream.value(null);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  testWidgets('CASLMS landing page loads', (WidgetTester tester) async {
    // Exercise the real signed-out gate without requiring live Firebase setup.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SessionGate(authService: _SignedOutAuth()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('caslms'), findsOneWidget);
    expect(find.text('Learn together.\nGo further.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Landing page survives animated light and dark theme changes', (
    WidgetTester tester,
  ) async {
    final themeMode = ValueNotifier(ThemeMode.light);
    addTearDown(themeMode.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, child) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: SessionGate(authService: _SignedOutAuth()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      themeMode.value = mode;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Get started'))).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
