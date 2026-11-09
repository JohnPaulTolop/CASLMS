import 'dart:io';
import 'dart:ui' as ui;

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/landing_page.dart';
import 'package:caslms/screens/shared/landing_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Roboto');
    for (final face in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$face.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Landing at $width dark $dark text $scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, width == 320 ? 568 : 900);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
              ),
              darkTheme: AppTheme.dark.copyWith(
                textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
              ),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const LandingScreen(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final context = tester.element(find.byType(LandingScreen));
            await precacheImage(
              const AssetImage('assets/images/landing/ssu-campus.jpg'),
              context,
            );
          });
          await tester.pumpAndSettle();
          expect(find.text('Learn together.\nGo further.'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      'assets/images/CASlogo.jpg',
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  widget.image is AssetImage &&
                  (widget.image as AssetImage).assetName ==
                      'assets/images/landing/ssu-campus.jpg',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('landing-start')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('landing-start')).hitTestable(),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Made for our CAS community.'));
          await tester.pumpAndSettle();
          expect(
            find.text('Made for our CAS community.').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_LANDING') &&
              scale == 1 &&
              (width == 390 || width == 1440)) {
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, 3000),
            );
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('landing-page')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = Directory('build/landing-preview');
              await output.create(recursive: true);
              await File(
                '${output.path}/${width.toInt()}-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
  testWidgets(
    'Ambient motion pauses, resumes and stops while another route is open',
    (tester) async {
      binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const LandingScreen(),
          routes: {
            '/auth': (_) => const Scaffold(body: Text('Authentication entry')),
          },
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final animation = tester
          .widget<LandingCommunityPreview>(find.byType(LandingCommunityPreview))
          .animation;
      final first = animation.value;
      await tester.pump(const Duration(seconds: 2));
      expect(animation.value, isNot(first));
      await tester.tap(find.byTooltip('Pause animation'));
      await tester.pumpAndSettle();
      final paused = animation.value;
      await tester.pump(const Duration(seconds: 2));
      expect(animation.value, paused);
      await tester.tap(find.byTooltip('Resume animation'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(animation.value, isNot(paused));
      await tester.ensureVisible(find.byKey(const ValueKey('landing-start')));
      await tester.tap(find.byKey(const ValueKey('landing-start')));
      await tester.pumpAndSettle();
      expect(find.text('Authentication entry'), findsOneWidget);
      expect((animation as AnimationController).isAnimating, false);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(animation.isAnimating, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Reduced motion keeps preview interactive without an idle ticker',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const LandingScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('landing-motion')), findsNothing);
      final animation = tester
          .widget<LandingCommunityPreview>(find.byType(LandingCommunityPreview))
          .animation;
      expect((animation as AnimationController).isAnimating, false);
      for (final index in [1, 2, 0]) {
        final feature = find.byKey(ValueKey('landing-feature-$index'));
        await tester.ensureVisible(feature);
        await tester.tap(feature);
        await tester.pumpAndSettle();
        final caption = tester.widget<Text>(
          find.byKey(const ValueKey('landing-preview-caption')),
        );
        expect(
          caption.data,
          [
            'Your community, connected.',
            'A little progress, every day.',
            'A helping hand, when you need it.',
          ][index],
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Landing entry actions preserve the authentication route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LandingScreen(),
        routes: {
          '/auth': (_) => const Scaffold(body: Text('Authentication entry')),
        },
      ),
    );
    await tester.pumpAndSettle();
    for (final key in ['landing-start', 'landing-sign-in']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.text('Authentication entry'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
