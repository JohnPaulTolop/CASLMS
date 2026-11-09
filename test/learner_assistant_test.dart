import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/assistant_conversation_widgets.dart';
import 'package:caslms/screens/shared/learner_assistant_page.dart';
import 'package:caslms/services/assistant_attachment_service.dart';
import 'package:caslms/services/ai_router_service.dart';
import 'package:caslms/services/learner_assistant_service.dart';
import 'package:caslms/services/school_chat_service.dart';
import 'package:caslms/services/assistant_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  _User([this.uid = 'learner']);
  @override
  final String uid;
}

class _Router extends Fake implements AiRouterService {
  List<Map<String, String>> messages = [];
  String? task;
  @override
  Future<String> complete({
    required String task,
    required List<Map<String, String>> messages,
    int? questionCount,
    void Function(String)? onDelta,
  }) async {
    this.task = task;
    this.messages = messages;
    return 'Grounded answer';
  }
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User();
  final changes = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => changes.stream;
}

class _Records extends Fake implements LearnerAssistantService {
  @override
  Future<List<AssistantStudent>> students(String role) async => [
    const AssistantStudent('learner', 'My records'),
  ];
  @override
  Future<LearnerAssistantReply> ask({
    required String role,
    required String question,
    String? studentId,
    void Function(String)? onDelta,
  }) async => const LearnerAssistantReply(
    'Your published tasks.',
    'Published record snapshot',
    usedAi: true,
  );
}

class _Study extends Fake implements SchoolChatService {
  final sent = <String>[];
  List<AssistantAttachment> attached = [];
  Completer<String>? pending;
  @override
  Future<String> ask({
    required String question,
    required List<Map<String, String>> history,
    List<AssistantAttachment> attachments = const [],
    void Function(String)? onDelta,
  }) async {
    sent.add(question);
    attached = attachments;
    onDelta?.call('A helpful');
    return pending != null ? pending!.future : 'A helpful explanation.';
  }
}

class _Attachments extends Fake implements AssistantAttachmentService {
  bool denied = false;
  @override
  Future<List<Map<String, dynamic>>> courses() async => [
    {'id': 'course', 'title': 'Mobile Development'},
  ];
  @override
  Future<List<Map<String, dynamic>>> modules(String courseId) async => [
    {'id': 'module', 'title': 'Chapter 1'},
  ];
  @override
  Future<List<Map<String, dynamic>>> materials(
    String courseId,
    String moduleId,
  ) async => [
    {'id': 'file', 'title': 'Lesson notes'},
  ];
  @override
  Future<AssistantAttachment> fromMaterial(
    String courseId,
    String moduleId,
    String resourceId,
  ) async => const AssistantAttachment(
    name: 'Lesson notes',
    text: 'Widgets build the interface.',
    courseId: 'course',
    moduleId: 'module',
    resourceId: 'file',
  );
  @override
  Future<void> validateAccess(List<AssistantAttachment> attachments) async {
    if (denied) throw const FormatException('Material access changed.');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Auth auth,
  _Study study,
  _Attachments attachments, {
  bool dark = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: LearnerAssistantScreen(
      role: 'student',
      auth: auth,
      service: _Records(),
      studyService: study,
      attachmentService: attachments,
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('History survives service recreation, isolates accounts and roles, and deletes', () async {
    final service = AssistantHistoryService();
    AssistantHistoryEntry entry(String id) => AssistantHistoryEntry(
      id: id,
      title: id,
      updated: DateTime.now(),
      studyHelp: true,
      messages: [
        {'text': 'Saved answer', 'isUser': false, 'records': 'not stored'},
      ],
    );
    await Future.wait([
      service.save('one', 'student', entry('first')),
      service.save('one', 'student', entry('second')),
    ]);
    final restarted = AssistantHistoryService();
    final saved = await restarted.load('one', 'student');
    expect(saved, hasLength(2));
    expect(saved.first.messages.first.containsKey('records'), isFalse);
    expect(await restarted.load('two', 'student'), isEmpty);
    expect(await restarted.load('one', 'instructor'), isEmpty);
    await restarted.delete('one', 'student', 'first');
    expect((await service.load('one', 'student')).single.id, 'second');
  });

  testWidgets('Saved conversations reopen after logout and page recreation', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    await _pump(tester, auth, _Study(), _Attachments());
    await tester.enterText(
      find.byKey(const ValueKey('assistant-question')),
      'Explain widgets',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    await AssistantHistoryService().load('learner', 'student');
    auth.user = null;
    auth.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('A helpful explanation.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.user = _User('learner');
    await _pump(tester, auth, _Study(), _Attachments());
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    expect(find.text('Explain widgets'), findsOneWidget);
    await tester.tap(find.text('Explain widgets'));
    await tester.pumpAndSettle();
    expect(find.text('A helpful explanation.'), findsOneWidget);
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Your conversations will appear here.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close history'));
    await tester.pumpAndSettle();
    expect(await AssistantHistoryService().load('learner', 'student'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile plus menu offers file and link actions on one row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 850);
    addTearDown(tester.view.reset);
    final auth = _Auth();
    addTearDown(auth.changes.close);
    await _pump(tester, auth, _Study(), _Attachments());
    final field = tester.getRect(
      find.byKey(const ValueKey('assistant-question')),
    );
    final plus = tester.getRect(find.byTooltip('Add attachment or link'));
    final send = tester.getRect(find.byTooltip('Send question'));
    expect(plus.center.dy, closeTo(field.center.dy, 3));
    expect(send.center.dy, closeTo(field.center.dy, 3));
    await tester.tap(find.byTooltip('Add attachment or link'));
    await tester.pumpAndSettle();
    expect(find.text('File or module material'), findsOneWidget);
    expect(find.text('Reference link'), findsOneWidget);
    await tester.tap(find.text('Reference link'));
    await tester.pumpAndSettle();
    expect(find.text('Add a reference link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'Study requests retain task restrictions and pass bounded source excerpts',
    () async {
      final router = _Router();
      await SchoolChatService(router: router).ask(
        question: 'Explain widgets',
        history: [],
        attachments: [
          const AssistantAttachment(
            name: 'Lesson',
            text: 'Widgets render the interface.',
          ),
        ],
      );
      expect(router.task, 'study_chat');
      expect(router.messages.single['role'], 'user');
      expect(
        router.messages.single['content'],
        contains('Widgets render the interface.'),
      );
      expect(router.messages.single['content']!.length, lessThan(3000));
    },
  );

  testWidgets(
    'Composer stays usable with a phone keyboard and multiline draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      addTearDown(tester.view.reset);
      final auth = _Auth();
      addTearDown(auth.changes.close);
      await _pump(tester, auth, _Study(), _Attachments());
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        'First line\nSecond line\nThird line\nFourth line',
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send question').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('Assistant layout and streaming at $width dark $dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 850);
        tester.platformDispatcher.textScaleFactorTestValue = width == 320
            ? 1.5
            : 1;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = _Auth();
        final study = _Study();
        addTearDown(auth.changes.close);
        await _pump(tester, auth, study, _Attachments(), dark: dark);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(AssistantConversationToolbar)).height,
          lessThan(80),
        );
        if (width < 700) {
          expect(
            find.byTooltip('Add attachment or link').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('assistant-composer')))
                .height,
            lessThan(90),
          );
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('assistant-question')),
                )
                .maxLines,
            1,
          );
        } else {
          expect(
            find.byTooltip('Attach file or module material').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip('Add reference link').hitTestable(),
            findsOneWidget,
          );
        }
        await tester.enterText(
          find.byKey(const ValueKey('assistant-question')),
          'Explain widgets',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Send question'));
        await tester.pumpAndSettle();
        expect(study.sent, ['Explain widgets']);
        expect(find.text('A helpful explanation.'), findsOneWidget);
        expect(find.byTooltip('Copy answer'), findsOneWidget);
        expect(find.text('Explain more simply'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Module attachment is sent, revoked access is blocked, mode changes clear it',
    (tester) async {
      final auth = _Auth();
      final study = _Study();
      final sources = _Attachments();
      addTearDown(auth.changes.close);
      await _pump(tester, auth, study, sources);
      await tester.tap(find.byTooltip('Attach file or module material'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from modules'));
      await tester.pumpAndSettle();
      for (final name in ['Mobile Development', 'Chapter 1', 'Lesson notes']) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      expect(find.byType(InputChip), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        'Explain this lesson',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(study.attached.single.text, contains('Widgets'));
      sources.denied = true;
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        'Explain again',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(study.sent, hasLength(1));
      expect(find.text('Material access changed.'), findsOneWidget);
      await tester.tap(find.byTooltip('Assistant mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My records').last);
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.byTooltip('Attach file or module material'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        'Show tasks',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pumpAndSettle();
      expect(find.text('Your published tasks.'), findsOneWidget);
      expect(find.text('View source records'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Links can be attached and new conversation clears them', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    await _pump(tester, auth, _Study(), _Attachments());
    await tester.tap(find.byTooltip('Add reference link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'https://example.edu/lesson',
    );
    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Account changes discard streaming answers and attachment drafts',
    (tester) async {
      final auth = _Auth();
      final study = _Study()..pending = Completer<String>();
      addTearDown(auth.changes.close);
      await _pump(tester, auth, study, _Attachments());
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        'Explain widgets',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send question'));
      await tester.pump();
      auth.user = null;
      auth.changes.add(null);
      await tester.pump();
      study.pending!.complete('Old account answer');
      await tester.pumpAndSettle();
      expect(find.text('Old account answer'), findsNothing);
      expect(find.text('Explain widgets'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Text and Office attachments extract actual content with bounded excerpts',
    () async {
      final text = await AssistantAttachmentService.fromBytes(
        'lesson.txt',
        Uint8List.fromList(utf8.encode('Widgets build the interface.')),
      );
      expect(text.text, contains('Widgets'));
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'word/document.xml',
            '<w:document><w:p>Widget lifecycle &amp; state</w:p></w:document>',
          ),
        );
      final doc = await AssistantAttachmentService.fromBytes(
        'notes.docx',
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      expect(doc.text, contains('Widget lifecycle & state'));
      final long = AssistantAttachment(
        name: 'Long lesson',
        text: '${'unrelated text ' * 200}Flutter widgets use state.',
      );
      final context = AssistantAttachmentService.contextFor('Flutter widgets', [
        long,
        text,
        doc,
      ]);
      expect(context, contains('Flutter widgets'));
      expect(context.length + 1500, lessThan(3000));
      expect(context, contains('untrusted source text'));
    },
  );
  test(
    'Unsafe links, empty, oversized, and unsupported files are rejected',
    () async {
      for (final url in [
        'javascript:alert(1)',
        'file:///secret',
        'https://user:pass@example.edu',
      ]) {
        expect(
          () => AssistantAttachmentService.fromLink(url),
          throwsFormatException,
        );
      }
      expect(
        AssistantAttachmentService.fromLink('https://example.edu/lesson').text,
        contains('has not been fetched'),
      );
      await expectLater(
        AssistantAttachmentService.fromBytes('data.exe', Uint8List(2)),
        throwsFormatException,
      );
      await expectLater(
        AssistantAttachmentService.fromBytes('data.txt', Uint8List(0)),
        throwsFormatException,
      );
      await expectLater(
        AssistantAttachmentService.fromBytes(
          'data.txt',
          Uint8List(AssistantAttachmentService.maxBytes + 1),
        ),
        throwsFormatException,
      );
    },
  );
}
