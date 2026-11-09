import 'dart:async';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:caslms/config/academic_catalog.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/auth_page.dart';
import 'package:caslms/services/campus_auth_service.dart';
import 'package:caslms/services/instructor_registration_service.dart';
import 'package:caslms/services/password_reset_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _User extends Fake implements User {}

CampusAuthResult get _result => CampusAuthResult(user: _User(), profile: {});

class _Auth extends Fake implements CampusAuthService {
  List<String>? login, registration;
  Completer<CampusAuthResult>? pending;
  bool fail = false;
  @override
  bool isValidCampusId(String v) => RegExp(r'^\d{5,12}$').hasMatch(v);
  @override
  bool isValidEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  @override
  Future<CampusAuthResult> signIn({
    required String campusId,
    required String password,
  }) async {
    login = [campusId, password];
    if (fail) throw CampusAuthException('Check your ID and password.');
    return pending == null ? _result : await pending!.future;
  }

  @override
  Future<CampusAuthResult> signUpStudent({
    required String fullName,
    required String email,
    required String campusId,
    required String department,
    required String course,
    required String password,
  }) async {
    registration = [fullName, email, campusId, department, course, password];
    return _result;
  }
}

class _Instructor extends Fake implements InstructorRegistrationService {
  List<Object>? registration;
  @override
  Future<FacultyIdDocument?> pickFacultyIdDocument() async => FacultyIdDocument(
    name: 'faculty.pdf',
    mimeType: 'application/pdf',
    bytes: Uint8List.fromList([1, 2]),
  );
  @override
  Future<CampusAuthResult> registerInstructor({
    required String fullName,
    required String email,
    required String campusId,
    required String department,
    required String position,
    required String password,
    required FacultyIdDocument facultyId,
  }) async {
    registration = [
      fullName,
      email,
      campusId,
      department,
      position,
      password,
      facultyId,
    ];
    return _result;
  }
}

class _Reset extends Fake implements PasswordResetService {
  List<String>? request;
  bool fail = false;
  @override
  Future<String> requestPasswordReset({
    required String campusId,
    required String email,
  }) async {
    request = [campusId, email];
    if (fail) throw PasswordResetException('Please try again later.');
    return PasswordResetService.genericSuccessMessage;
  }
}

Finder key(String value) => find.byKey(ValueKey(value));
Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String name, String value) async {
  await t.ensureVisible(key(name));
  await t.enterText(key(name), value);
  await t.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester t, {
  bool signup = false,
  bool dark = false,
  double width = 390,
  double scale = 1,
  _Auth? auth,
  _Instructor? instructor,
  _Reset? reset,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 850);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await t.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      initialRoute: '/auth',
      routes: {
        '/': (_) => const Scaffold(body: Text('Account gate')),
        '/auth': (_) => AuthScreen(
          initialSignUp: signup,
          authService: auth ?? _Auth(),
          instructorRegistrationService: instructor ?? _Instructor(),
          passwordResetService: reset ?? _Reset(),
        ),
      },
    ),
  );
  await t.pumpAndSettle();
}

Future<void> fillSignup(WidgetTester t, {bool instructor = false}) async {
  await enter(t, 'auth-full-name', 'Juan Dela Cruz');
  await enter(t, 'auth-email', 'juan@gmail.com');
  await enter(t, 'auth-id', '20260001');
  if (instructor) {
    await enter(t, 'auth-position', 'Instructor');
  } else {
    await tap(t, find.byType(DropdownButtonFormField<String>));
    await tap(t, find.text(AcademicCatalog.programLabel('BSIT')).last);
  }
  await enter(t, 'auth-password', 'secure123');
  await enter(t, 'auth-confirm-password', 'secure123');
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto');
    for (final face in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$face.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final signup in [false, true]) {
        testWidgets('Auth layout $width dark $dark signup $signup', (t) async {
          await _mount(t, width: width, dark: dark, signup: signup);
          expect(
            find.text(signup ? 'Join your CAS community' : 'Welcome back'),
            findsOneWidget,
          );
          await t.ensureVisible(key('auth-submit'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_AUTH') && width != 320) {
            await t.drag(
              find.byKey(const ValueKey('auth-scroll')),
              const Offset(0, 3000),
            );
            await t.pumpAndSettle();
            await t.runAsync(
              () => precacheImage(
                const AssetImage('assets/images/landing/ssu-campus.jpg'),
                t.element(find.byType(AuthScreen)),
              ),
            );
            await t.pumpAndSettle();
            await t.runAsync(() async {
              final image = await (t.renderObject(
                key('auth-page'),
              ) as RenderRepaintBoundary).toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                'build/auth-preview/$width-$dark-$signup.png',
              );
              output.parent.createSync(recursive: true);
              output.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
  testWidgets('Large text, validation and keyboard fit mobile signup', (
    t,
  ) async {
    await _mount(t, width: 320, scale: 2, signup: true);
    await tap(t, key('auth-submit'));
    expect(find.text('Enter your full name.'), findsOneWidget);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await enter(t, 'auth-confirm-password', 'bad');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Login validates, reports errors and retries through account gate',
    (t) async {
      final auth = _Auth()..fail = true;
      await _mount(t, auth: auth);
      await tap(t, key('auth-submit'));
      expect(auth.login, isNull);
      await enter(t, 'auth-id', '20260001');
      await enter(t, 'auth-password', 'secure123');
      await tap(t, find.byTooltip('Show password'));
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: key('auth-password'),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        false,
      );
      await tap(t, key('auth-submit'));
      expect(find.text('Check your ID and password.'), findsOneWidget);
      auth.fail = false;
      await tap(t, key('auth-submit'));
      expect(auth.login, ['20260001', 'secure123']);
      expect(find.text('Account gate'), findsOneWidget);
    },
  );
  testWidgets(
    'Student signup preserves academic fields and verification guidance',
    (t) async {
      final auth = _Auth();
      await _mount(t, signup: true, auth: auth);
      expect(find.textContaining('Verify your Gmail'), findsOneWidget);
      await fillSignup(t);
      await enter(t, 'auth-confirm-password', 'different');
      await tap(t, key('auth-submit'));
      expect(auth.registration, isNull);
      await enter(t, 'auth-confirm-password', 'secure123');
      await tap(t, key('auth-submit'));
      expect(auth.registration, [
        'Juan Dela Cruz',
        'juan@gmail.com',
        '20260001',
        AcademicCatalog.department,
        'BSIT',
        'secure123',
      ]);
      expect(find.text('Account gate'), findsOneWidget);
    },
  );
  testWidgets(
    'Instructor application requires faculty proof and retains approval flow',
    (t) async {
      final instructor = _Instructor();
      await _mount(t, signup: true, instructor: instructor);
      await tap(t, find.text('Instructor'));
      await fillSignup(t, instructor: true);
      await tap(t, key('auth-submit'));
      expect(instructor.registration, isNull);
      await tap(t, key('auth-faculty-id'));
      expect(find.text('faculty.pdf'), findsOneWidget);
      await tap(t, key('auth-submit'));
      expect(instructor.registration!.sublist(0, 6), [
        'Juan Dela Cruz',
        'juan@gmail.com',
        '20260001',
        AcademicCatalog.department,
        'Instructor',
        'secure123',
      ]);
      expect(find.text('Account gate'), findsOneWidget);
    },
  );
  testWidgets('Busy login prevents duplicate submits and changing mode', (
    t,
  ) async {
    final auth = _Auth()..pending = Completer<CampusAuthResult>();
    await _mount(t, auth: auth);
    await enter(t, 'auth-id', '20260001');
    await enter(t, 'auth-password', 'secure123');
    await t.ensureVisible(key('auth-submit'));
    await t.tap(key('auth-submit'));
    await t.pump();
    expect(t.widget<FilledButton>(key('auth-submit')).onPressed, isNull);
    expect(t.widget<TextFormField>(key('auth-id')).enabled, false);
    expect(
      t
          .widget<TextButton>(find.widgetWithText(TextButton, 'Create account'))
          .onPressed,
      isNull,
    );
    auth.pending!.complete(_result);
    await t.pumpAndSettle();
    expect(find.text('Account gate'), findsOneWidget);
  });
  testWidgets(
    'Recovery pre-fills ID, handles failure and gives generic confirmation',
    (t) async {
      final reset = _Reset()..fail = true;
      await _mount(t, reset: reset);
      await enter(t, 'auth-id', '20260001');
      await tap(t, find.text('Forgot password?'));
      expect(
        t.widget<TextFormField>(key('reset-id')).controller!.text,
        '20260001',
      );
      await enter(t, 'reset-email', 'juan@gmail.com');
      await tap(t, find.text('Send reset link'));
      expect(find.text('Please try again later.'), findsOneWidget);
      reset.fail = false;
      await tap(t, find.text('Send reset link'));
      expect(reset.request, ['20260001', 'juan@gmail.com']);
      expect(
        find.textContaining('If the information matches an account'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Switching modes clears secrets', (t) async {
    await _mount(t);
    await enter(t, 'auth-password', 'private123');
    await tap(t, find.widgetWithText(TextButton, 'Create account'));
    expect(
      t.widget<TextFormField>(key('auth-password')).controller!.text,
      isEmpty,
    );
    await enter(t, 'auth-password', 'private456');
    await tap(t, find.text('Instructor'));
    expect(
      t.widget<TextFormField>(key('auth-password')).controller!.text,
      isEmpty,
    );
  });
}
