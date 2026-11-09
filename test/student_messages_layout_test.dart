import 'dart:ui' show PointerDeviceKind;
import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/student/student_chat_page.dart';
import 'package:caslms/screens/student/student_messages_page.dart';
import 'package:caslms/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChatApi extends Fake implements ChatService {
  int conversationWatches = 0, messageWatches = 0, opened = 0;
  String uid = 'student';
  final sent = <String>[];
  final files = <String>[];
  String? attachmentCaption;
  @override
  Future<void> sendAttachment({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
    required String receiverId,
    required String fileName,
    required Uint8List fileBytes,
    String caption = '',
  }) async {
    expect(receiverId, instructorId);
    files.add(fileName);
    attachmentCaption = caption;
  }

  @override
  String? get currentUserId => uid;
  @override
  Future<List<Map<String, dynamic>>> getStudentChatContacts() async => [
    for (final id in ['one', 'two'])
      {
        'courseId': 'course',
        'studentId': 'student',
        'studentName': 'Student',
        'instructorId': id,
        'instructorName': 'Instructor $id',
        'instructorEmail': '$id@example.edu',
        'courseIds': ['course'],
      },
  ];
  @override
  Stream<List<Map<String, dynamic>>> watchStudentConversations() {
    conversationWatches++;
    return Stream.value([]);
  }

  @override
  Future<String> ensureConversation({
    required String courseId,
    required String studentId,
    required String studentName,
    required String instructorId,
    required String instructorName,
  }) async {
    opened++;
    return instructorId;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMessages({
    required String courseId,
    required String instructorId,
    required String studentId,
  }) {
    messageWatches++;
    return Stream.value([
      {
        'text': 'Welcome to your course. This is a longer message to check wrapping inside the conversation pane.',
        'senderId': instructorId,
        'receiverId': studentId,
        'isRead': true,
      },
    ]);
  }

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
  }) async => sent.add(text);
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, {this.reportedLength = 3});
  @override
  final String name;
  final int reportedLength;
  bool read = false;
  @override
  Uri get uri => Uri.parse('file:///attachment');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  Future<int> length() async => reportedLength;
  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList([1, 2, 3]));
}

Future<void> _pumpAttachmentChat(
  WidgetTester tester,
  _ChatApi api,
  Future<PlatformFile?> Function() pick,
) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: StudentChatScreen(
      courseId: 'course',
      studentId: 'student',
      studentName: 'Student',
      instructorId: 'teacher',
      instructorName: 'Teacher',
      instructorEmail: '',
      chatService: api,
      attachmentPicker: pick,
    ),
  ),
);

void main() {
  for (final name in ['photo.jpg', 'notes.pdf']) {
    testWidgets('Student sends $name with the current caption', (tester) async {
      final api = _ChatApi();
      await _pumpAttachmentChat(tester, api, () async => _PickedFile(name));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Here is my work');
      await tester.tap(find.byTooltip('Attach photo or file'));
      await tester.pumpAndSettle();
      expect(api.files, [name]);
      expect(api.attachmentCaption, 'Here is my work');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Cancelled and oversized attachments preserve the draft without sending',
    (tester) async {
      final api = _ChatApi();
      final file = _PickedFile(
        'huge.pdf',
        reportedLength: ChatService.maximumAttachmentBytes + 1,
      );
      var cancelled = true;
      await _pumpAttachmentChat(
        tester,
        api,
        () async => cancelled ? null : file,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep this draft');
      await tester.tap(find.byTooltip('Attach photo or file'));
      await tester.pumpAndSettle();
      cancelled = false;
      await tester.tap(find.byTooltip('Attach photo or file'));
      await tester.pumpAndSettle();
      expect(api.files, isEmpty);
      expect(file.read, isFalse);
      expect(
        find.text('Chat attachments must be 15 MB or smaller.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this draft',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('An account change during picking cannot send an attachment', (
    tester,
  ) async {
    final api = _ChatApi();
    final picked = Completer<PlatformFile?>();
    await _pumpAttachmentChat(tester, api, () => picked.future);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach photo or file'));
    await tester.pump();
    api.uid = 'another-student';
    picked.complete(_PickedFile('notes.pdf'));
    await tester.pumpAndSettle();
    expect(api.files, isEmpty);
    expect(
      find.text('Your session changed. Reopen the conversation.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  for (final (width, scale) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (900.0, 1.0),
    (1100.0, 1.0),
    (1440.0, 1.0),
    (1920.0, 1.0),
    (320.0, 2.0),
    (1440.0, 2.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('Messages layout at $width, text $scale, dark $dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);
        final api = _ChatApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: WorkspaceShell(
              name: 'Student',
              destinations: studentDestinations,
              selectedIndex: 5,
              onSelected: (_) {},
              onInbox: () {},
              onLogout: () {},
              child: StudentMessagesScreen(chatService: api),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Conversation list layout',
        );
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Search messages',
        );
        expect(
          tester.getTopLeft(find.text('Messages').last).dx,
          closeTo(tester.getTopLeft(search).dx, 1),
        );
        final contact = find.byKey(const ValueKey('conversation-one'));
        await tester.ensureVisible(contact);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Scrolled list layout');
        final material = find
            .ancestor(of: contact, matching: find.byType(Material))
            .first;
        expect(tester.widget<Material>(material).elevation, 0);
        expect(tester.widget<Material>(material).color, Colors.transparent);
        expect(
          (tester.widget<Material>(material).shape! as RoundedRectangleBorder)
              .side,
          BorderSide.none,
        );
        expect(
          tester.widget<Material>(material).shadowColor,
          Colors.transparent,
        );
        final before = tester.getRect(material);
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await pointer.addPointer(location: tester.getCenter(contact));
        await tester.pumpAndSettle();
        expect(tester.getRect(material), before);
        await pointer.removePointer();
        await tester.tap(contact);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Open conversation layout',
        );
        final chat = tester.widget<StudentChatScreen>(
          find.byType(StudentChatScreen),
        );
        expect(chat.embedded, width >= 1100 && scale <= 1.4);
        if (width >= 1100 && scale <= 1.4) {
          expect(
            find.byKey(const ValueKey('desktop-sidebar')).hitTestable(),
            findsOneWidget,
          );
          expect(contact.hitTestable(), findsOneWidget);
          expect(find.byTooltip('Close conversation'), findsOneWidget);
          final pane = tester.getRect(
            find.byKey(const ValueKey('desktop-conversation-pane')),
          );
          expect(pane.left, greaterThan(tester.getRect(contact).right));
          final composerSurface = tester.getRect(
            find.byKey(const ValueKey('message-composer-surface')),
          );
          expect(composerSurface.left, closeTo(pane.left, 2));
          expect(composerSurface.right, closeTo(pane.right, 2));
          final composer = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Message',
          );
          expect(
            tester.getRect(composer).left,
            greaterThanOrEqualTo(pane.left),
          );
          expect(tester.getRect(composer).right, lessThanOrEqualTo(pane.right));
          await tester.enterText(composer, 'A course question');
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(api.sent, ['A course question']);
          expect(api.conversationWatches, 1);
          expect(api.messageWatches, 1);
          await tester.tap(find.byKey(const ValueKey('conversation-two')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<StudentChatScreen>(find.byType(StudentChatScreen))
                .instructorId,
            'two',
          );
          await tester.tap(find.byTooltip('Close conversation'));
          await tester.pumpAndSettle();
          expect(find.text('Choose a conversation'), findsOneWidget);
        } else {
          expect(find.byType(BackButton), findsOneWidget);
          expect(find.byTooltip('Close conversation'), findsNothing);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(contact.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Chat retains the current student ownership check', (
    tester,
  ) async {
    final api = _ChatApi()..uid = 'another-student';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StudentChatScreen(
          courseId: 'course',
          studentId: 'student',
          studentName: 'Student',
          instructorId: 'one',
          instructorName: 'Instructor one',
          instructorEmail: '',
          chatService: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This conversation does not belong to the logged-in student.'),
      findsOneWidget,
    );
    expect(api.opened, 0);
    api.uid = 'student';
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(api.opened, 1);
    expect(
      find.text('This conversation does not belong to the logged-in student.'),
      findsNothing,
    );
    expect(find.byTooltip('Send message'), findsOneWidget);
  });
}
