import 'dart:async';

import 'package:caslms/core/app_colors.dart';
import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/shared/notification_inbox.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1920.0]) {
    for (final dark in [false, true]) {
      testWidgets('Inbox borders follow theme at $width, dark $dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 956);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: NotificationInboxScreen(
              notifications: Stream.value([
                {'id': 'read', 'title': 'Read update', 'isRead': true},
                {'id': 'unread', 'title': 'Unread update', 'isRead': false},
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final previews = tester.widgetList<NotificationPreview>(
          find.byType(NotificationPreview),
        );
        expect(previews, hasLength(2));
        for (final preview in previews) {
          final ink = tester.widget<Ink>(
            find
                .descendant(
                  of: find.byWidget(preview),
                  matching: find.byType(Ink),
                )
                .first,
          );
          final border = (ink.decoration! as BoxDecoration).border! as Border;
          final unread = preview.notice['isRead'] != true;
          expect(
            border.top.color,
            unread
                ? dark
                      ? DarkAppColors.primaryBlue.withValues(alpha: .4)
                      : const Color(0xFFBED4FA)
                : dark
                ? DarkAppColors.inputBorder.withValues(alpha: .5)
                : LightAppColors.inputBorder.withValues(alpha: .5),
          );
          expect(
            (ink.decoration! as BoxDecoration).color,
            unread
                ? dark
                      ? DarkAppColors.blueTint
                      : LightAppColors.blueTint
                : Colors.transparent,
          );
          final material = tester.widget<Material>(
            find
                .ancestor(
                  of: find.byWidget(preview),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.color, Colors.transparent);
        }
        for (final chip in tester.widgetList<ChoiceChip>(
          find.byType(ChoiceChip),
        )) {
          expect(
            chip.side!.color,
            chip.selected
                ? dark
                      ? DarkAppColors.primaryBlue.withValues(alpha: .4)
                      : const Color(0xFFAFC9F7)
                : dark
                ? DarkAppColors.inputBorder
                : LightAppColors.inputBorder,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Bell opens Inbox after navigating away and back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 956);
    addTearDown(tester.view.reset);
    var selected = 0;
    var opened = false;
    final inbox = NotificationInboxScreen(notifications: Stream.value([]));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => WorkspaceShell(
            name: 'Student',
            destinations: studentDestinations
                .where((d) => d.index != 9)
                .toList(),
            selectedIndex: selected,
            onSelected: (index) => setState(() => selected = index),
            onInbox: () => setState(() {
              selected = 9;
              opened = true;
            }),
            onLogout: () {},
            child: IndexedStack(
              index: selected,
              children: [
                for (var index = 0; index < 10; index++)
                  if (index == 9 && opened) inbox else const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Your inbox'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inbox renders when opened in the student workspace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 956);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkspaceShell(
          destinations: studentDestinations,
          selectedIndex: 9,
          onSelected: (_) {},
          onInbox: () {},
          onLogout: () {},
          name: 'Student',
          child: IndexedStack(
            index: 1,
            children: [
              const SizedBox.shrink(),
              NotificationInboxScreen(
                notifications: Stream.value([
                  {
                    'id': 'notice',
                    'title': 'New quiz',
                    'message': 'Open your quiz',
                    'isRead': true,
                  },
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Your inbox'), findsOneWidget);
    expect(find.text('New quiz'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1920.0]) {
    testWidgets('Inbox loading and error states render at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 956);
      addTearDown(tester.view.reset);
      final stream = StreamController<List<Map<String, dynamic>>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationInboxScreen(notifications: stream.stream),
        ),
      );
      await tester.pump();
      expect(find.text('Loading notifications…'), findsOneWidget);
      stream.addError(StateError('Connection unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Unable to load notifications. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
