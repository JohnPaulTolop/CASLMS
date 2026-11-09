import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_workspace_widgets.dart';
import 'package:caslms/screens/instructor/instructor_ui.dart';
import 'package:caslms/screens/instructor/instructor_messages_page.dart';
import 'package:caslms/screens/instructor/instructor_chat_page.dart';
import 'package:caslms/screens/instructor/instructor_teaching_assistant_page.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/services/chat_service.dart';
import 'package:caslms/services/instructor_teaching_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _courses = [
  {
    'id': 'mobile',
    'title': 'Advance Mobile Development',
    'code': 'IT302',
    'semester': 'First Semester',
    'academicYear': '2026–2027',
    'studentCount': 38,
  },
  {
    'id': 'networks',
    'title': 'Computer Networks and Infrastructure',
    'code': 'IT303',
    'studentCount': 31,
  },
  {
    'id': 'capstone',
    'title': 'Capstone Project',
    'code': 'IT401',
    'studentCount': 24,
  },
];

class _Chat extends Fake implements ChatService {
  final opened = <String>[];
  final sent = <String>[];
  int watches = 0;
  Completer<Map<String, dynamic>?>? slowStudent;
  String? uid = 'instructor';
  @override
  String? get currentUserId => uid;
  @override
  Stream<List<Map<String, dynamic>>> watchInstructorConversations() {
    watches++;
    return Stream.value([
      for (final id in ['one', 'two'])
        {
          'courseId': 'course',
          'studentId': id,
          'studentName': 'Student $id',
          'instructorId': 'instructor',
          'instructorName': 'Professor',
          'lastMessage': 'Can you help with our coursework?',
        },
    ]);
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String userId) async =>
      userId == 'one' && slowStudent != null
      ? await slowStudent!.future
      : {'email': '$userId@gmail.com'};
  @override
  Future<String> ensureConversation({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
  }) async {
    opened.add(studentId);
    return studentId;
  }

  @override
  Stream<int> watchConversationUnreadCount({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) => Stream.value(0);
  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) => Stream.value([
    {
      'text': 'Hello from $studentId',
      'senderId': studentId,
      'receiverId': instructorId,
      'isRead': true,
    },
  ]);
  @override
  Future<void> markMessagesAsRead({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) async {}
  @override
  Future<void> sendMessage({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
    required String receiverId,
    required String text,
  }) async {
    expect(receiverId, studentId);
    sent.add(text);
  }
}

class _Ai extends Fake implements InstructorTeachingAiService {
  final questions = <String>[];
  bool fail = false;
  Completer<String>? pending;
  @override
  Future<List<Map<String, String>>> loadCourses() async => [
    {'id': 'mobile', 'code': 'IT302', 'title': 'Mobile development'},
  ];
  @override
  Future<String> ask({
    required String question,
    required List<TeachingAiTurn> history,
    String? courseId,
    void Function(String text)? onDelta,
  }) async {
    questions.add(question);
    if (fail) throw StateError('Try again later.');
    if (pending != null) return await pending!.future;
    onDelta?.call('A sample lesson plan.');
    return 'A sample lesson plan.';
  }
}

Future<void> _mount(
  WidgetTester t,
  Widget child, {
  double width = 390,
  bool dark = false,
  double scale = 1,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 1000);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await t.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: child,
    ),
  );
  await t.pumpAndSettle();
}

Widget _shell(Widget child) => WorkspaceShell(
  destinations: instructorDestinations,
  selectedIndex: 0,
  onSelected: (_) {},
  onInbox: () {},
  onLogout: () {},
  name: 'Professor',
  role: 'Instructor',
  child: child,
);
void main() {
  testWidgets(
    'Instructor navigation keeps AI, account and secondary pages reachable',
    (t) async {
      var selected = 0;
      await _mount(
        t,
        WorkspaceShell(
          destinations: instructorDestinations,
          selectedIndex: 0,
          onSelected: (index) => selected = index,
          onInbox: () {},
          onLogout: () {},
          role: 'Instructor',
          name: 'Professor',
          child: const SizedBox.shrink(),
        ),
        width: 390,
        dark: false,
        scale: 1,
      );
      expect(instructorDestinations.length, 6);
      for (final index in [0, 1, 2, 5]) {
        expect(find.byKey(ValueKey('nav-$index')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('nav-6')), findsNothing);
      await t.tap(find.byKey(const ValueKey('instructor-assistant-entry')));
      expect(selected, 6);
      await t.tap(find.byKey(const ValueKey('instructor-account-menu')));
      await t.pumpAndSettle();
      await t.tap(find.text('My profile'));
      await t.pumpAndSettle();
      expect(selected, 4);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  for (final width in [320.0, 390.0, 900.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Instructor dashboard $width dark $dark text $scale', (
          t,
        ) async {
          final actions = <String>[];
          await _mount(
            t,
            _shell(
              Builder(
                builder: (context) => instructorScaffold(
                  context: context,
                  title: 'Teaching overview',
                  subtitle: 'A clear view of your classroom.',
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: InstructorDashboardContent(
                      name: 'Professor',
                      enrollments: 93,
                      pending: 12,
                      courseCount: 3,
                      courses: _courses,
                      onCourse: (c) => actions.add(c['id'].toString()),
                      onCreate: () => actions.add('create'),
                      onCourses: () => actions.add('courses'),
                      onGrade: () => actions.add('grading'),
                      onAi: () => actions.add('ai'),
                      onCalendar: () => actions.add('calendar'),
                      onAnnouncements: () => actions.add('announcements'),
                      onHelp: () => actions.add('help'),
                    ),
                  ),
                ),
              ),
            ),
            width: width,
            dark: dark,
            scale: scale,
          );
          expect(find.text('93'), findsOneWidget);
          await t.ensureVisible(find.text('Open teaching AI'));
          await t.pumpAndSettle();
          await t.tap(find.text('Open teaching AI'));
          expect(actions, contains('ai'));
          final course = find.byKey(const ValueKey('instructor-course-mobile'));
          await t.ensureVisible(course);
          await t.pumpAndSettle();
          await t.tap(course);
          expect(actions, contains('mobile'));
          expect(t.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_INSTRUCTOR') &&
              scale == 1 &&
              [390.0, 1440.0].contains(width)) {
            await t.drag(
              find.byType(SingleChildScrollView).last,
              const Offset(0, 5000),
            );
            await t.pumpAndSettle();
            final boundaryKey = GlobalKey();
            // Capture the complete viewport, including actual shared navigation.
            final root = t.widget<MaterialApp>(find.byType(MaterialApp));
            await t.pumpWidget(RepaintBoundary(key: boundaryKey, child: root));
            await t.pumpAndSettle();
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await t.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('build/instructor-preview/$width-$dark.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }
  for (final width in [390.0, 1440.0]) {
    testWidgets('Instructor messages preserve navigation at $width', (t) async {
      final chat = _Chat();
      await _mount(
        t,
        _shell(InstructorMessagesScreen(chatService: chat)),
        width: width,
        dark: true,
      );
      await t.tap(find.text('Student one'));
      await t.pumpAndSettle();
      expect(find.text('Hello from one'), findsOneWidget);
      expect(chat.opened, ['one']);
      expect(
        find.text('caslms'),
        width == 1440 ? findsOneWidget : findsNothing,
      );
      final input = find.byType(TextField).last;
      await t.enterText(input, 'Here is your feedback');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pumpAndSettle();
      expect(chat.sent, ['Here is your feedback']);
      if (width == 1440) {
        await t.tap(find.byIcon(Icons.close_rounded));
        await t.pumpAndSettle();
        expect(
          find.text('Choose a student to open your messages.'),
          findsOneWidget,
        );
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Latest selected conversation wins while contact requests overlap',
    (t) async {
      final chat = _Chat()..slowStudent = Completer<Map<String, dynamic>?>();
      await _mount(
        t,
        _shell(InstructorMessagesScreen(chatService: chat)),
        width: 1440,
      );
      await t.tap(find.text('Student one'));
      await t.pump();
      await t.tap(find.text('Student two'));
      await t.pumpAndSettle();
      chat.slowStudent!.complete({'email': 'one@gmail.com'});
      await t.pumpAndSettle();
      expect(find.text('Hello from two'), findsOneWidget);
      expect(chat.opened, ['two']);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'Compact instructor AI sends, resets and handles errors dark $dark',
      (t) async {
        final ai = _Ai();
        await _mount(
          t,
          InstructorTeachingAssistantScreen(service: ai),
          dark: dark,
        );
        await t.enterText(find.byType(TextField), 'Help me plan a lesson');
        await t.tap(find.byTooltip('Send to teaching AI'));
        await t.pumpAndSettle();
        expect(find.text('A sample lesson plan.'), findsOneWidget);
        await t.tap(find.byTooltip('New conversation'));
        await t.pumpAndSettle();
        expect(find.text('A sample lesson plan.'), findsNothing);
        ai.fail = true;
        await t.enterText(find.byType(TextField), 'Try again');
        await t.tap(find.byTooltip('Send to teaching AI'));
        await t.pumpAndSettle();
        expect(find.textContaining('Try again later.'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Course layout uses equal metric widths and accessible course taps',
    (t) async {
      await _mount(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: InstructorTiles(
              children: [
                for (var i = 0; i < 3; i++)
                  InstructorMetric(
                    label: 'Metric $i',
                    value: '$i',
                    icon: Icons.school_outlined,
                  ),
              ],
            ),
          ),
        ),
        width: 1440,
      );
      final sizes = [
        for (final e in find.byType(InstructorMetric).evaluate())
          t.getSize(find.byWidget(e.widget)).width,
      ];
      expect(sizes.toSet().length, 1);
      expect(sizes.first, greaterThan(450));
    },
  );
  testWidgets(
    'Opening an instructor conversation still checks the active account',
    (t) async {
      final chat = _Chat()..uid = 'another-account';
      await _mount(
        t,
        InstructorChatScreen(
          courseId: 'course',
          studentId: 'one',
          studentName: 'Student',
          studentEmail: '',
          instructorId: 'instructor',
          instructorName: 'Professor',
          chatService: chat,
        ),
      );
      expect(
        find.text('This chat does not belong to the logged-in instructor.'),
        findsOneWidget,
      );
      expect(chat.opened, isEmpty);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'Teaching AI remains usable with large text and mobile keyboard dark $dark',
      (t) async {
        final ai = _Ai()..pending = Completer<String>();
        await _mount(
          t,
          InstructorTeachingAssistantScreen(service: ai),
          width: 320,
          scale: 2,
          dark: dark,
        );
        await t.enterText(find.byType(TextField), 'Plan a lesson');
        t.view.viewInsets = const FakeViewPadding(bottom: 280);
        await t.pump();
        await t.tap(find.byTooltip('Send to teaching AI'));
        await t.pump(const Duration(milliseconds: 200));
        expect(find.text('Preparing teaching guidance…'), findsOneWidget);
        expect(t.takeException(), isNull);
        ai.pending!.complete('Here is a lesson plan.');
        await t.pumpAndSettle();
        expect(find.text('Here is a lesson plan.'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
