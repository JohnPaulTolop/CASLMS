import 'dart:async';

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/models/calendar_entry.dart';
import 'package:caslms/services/calendar_service.dart';
import 'package:caslms/services/philippine_holidays.dart';
import 'package:caslms/screens/shared/calendar_page.dart';
import 'package:caslms/screens/shared/workspace_shell.dart';
import 'package:caslms/screens/student/student_progress_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calendar extends Fake implements CalendarService {
  @override
  bool get temporaryEvents => true;
  String? account = 'teacher';
  bool fail = false;
  bool eventsAvailable = true;
  final saved = <CalendarEntry>[];
  final changes = StreamController<String?>.broadcast();
  DateTime? sentStart, sentEnd;
  String? sentCourse;
  @override
  String? get uid => account;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<CalendarData> load(String role) async {
    if (fail) throw StateError('Unavailable');
    return CalendarData(
      eventsAvailable: eventsAvailable,
      courses: [
        {'id': 'course', 'code': 'IT302', 'title': 'Mobile Development'},
      ],
      entries: [
        CalendarEntry(
          id: 'deadline',
          title: 'Quiz deadline',
          start: DateTime.utc(2026, 11, 6, 15, 59),
          end: DateTime.utc(2026, 11, 6, 15, 59),
          kind: CalendarKind.deadline,
          courseId: 'course',
          courseLabel: 'IT302',
        ),
        CalendarEntry(
          id: 'workshop',
          title: 'Class workshop',
          start: DateTime.utc(2026, 11, 6, 1),
          end: DateTime.utc(2026, 11, 6, 2),
          kind: CalendarKind.event,
          courseId: 'course',
          ownerId: 'teacher',
        ),
        ...saved,
      ],
    );
  }

  @override
  Future<void> save({
    required String role,
    required String title,
    required String description,
    required String courseId,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    CalendarEntry? existing,
  }) async {
    sentStart = start;
    sentEnd = end;
    sentCourse = courseId;
    saved.add(
      CalendarEntry(
        id: 'new',
        title: title,
        description: description,
        start: start,
        end: end,
        kind: CalendarKind.event,
        courseId: courseId,
        ownerId: 'teacher',
        allDay: allDay,
      ),
    );
  }

  @override
  Future<void> delete(String role, CalendarEntry event) async =>
      saved.removeWhere((row) => row.id == event.id);
}

void main() {
  testWidgets(
    'Event outages leave due dates visible and prevent unavailable publishing',
    (tester) async {
      final service = _Calendar()..eventsAvailable = false;
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CalendarScreen(
            role: 'instructor',
            service: service,
            initialDate: DateTime.utc(2026, 11, 6),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quiz deadline'), findsOneWidget);
      expect(
        find.textContaining('Due dates and holidays are shown'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .firstWhere((button) => button.tooltip == 'Add event')
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Admins can create schoolwide events', (tester) async {
    final service = _Calendar();
    addTearDown(service.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalendarScreen(
          role: 'admin',
          service: service,
          initialDate: DateTime.utc(2026, 11, 6),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add event'));
    await tester.pumpAndSettle();
    expect(find.text('Everyone · Schoolwide'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Campus assembly');
    await tester.ensureVisible(find.text('Save event'));
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(service.sentCourse, '');
    expect(find.text('Campus assembly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Calendar kind filters and month navigation update the agenda', (
    tester,
  ) async {
    final service = _Calendar();
    addTearDown(service.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalendarScreen(
          role: 'student',
          service: service,
          initialDate: DateTime.utc(2026, 11, 6),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due dates'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz deadline'), findsNothing);
    expect(find.text('Class workshop'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('Class workshop'), findsNothing);
    expect(find.text('Christmas Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'Philippine dates use UTC+8, including midnight and multi-day spans',
    () {
      expect(
        philippineDay(DateTime.utc(2026, 11, 5, 16)),
        DateTime.utc(2026, 11, 6),
      );
      expect(
        philippineWallToUtc(DateTime.utc(2026, 11, 6, 9)),
        DateTime.utc(2026, 11, 6, 1),
      );
      final event = CalendarEntry(
        id: 'span',
        title: 'Break',
        start: DateTime.utc(2026, 11, 5, 16),
        end: DateTime.utc(2026, 11, 7, 15, 59),
        kind: CalendarKind.event,
        allDay: true,
      );
      expect(event.occursOn(DateTime.utc(2026, 11, 6)), isTrue);
      expect(event.occursOn(DateTime.utc(2026, 11, 7)), isTrue);
      expect(event.occursOn(DateTime.utc(2026, 11, 8)), isFalse);
    },
  );
  test('Holiday years and proclamation-specific dates are exact, without guessed Eid dates', () {
    final current = PhilippineHolidays.forYear(2026),
        next = PhilippineHolidays.forYear(2027);
    expect(current, hasLength(21));
    expect(next, hasLength(19));
    expect(
      philippineDay(
        current.firstWhere((event) => event.title == 'Eid’l Fitr').start,
      ),
      DateTime.utc(2026, 3, 20),
    );
    expect(
      philippineDay(
        current.firstWhere((event) => event.title == 'Eid’l Adha').start,
      ),
      DateTime.utc(2026, 5, 27),
    );
    expect(next.where((event) => event.title.startsWith('Eid')), isEmpty);
    expect(
      philippineDay(
        next.firstWhere((event) => event.title == 'Maundy Thursday').start,
      ),
      DateTime.utc(2027, 3, 25),
    );
    expect(PhilippineHolidays.forYear(2028), isEmpty);
  });
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('Calendar at $width dark $dark with accessible text', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = width == 320
            ? 2
            : 1;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final service = _Calendar();
        addTearDown(service.changes.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: CalendarScreen(
              role: 'student',
              service: service,
              initialDate: DateTime.utc(2026, 11, 6),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Calendar'), findsOneWidget);
        expect(find.byTooltip('Add event'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('calendar-day-6')),
        );
        await tester.tap(find.byKey(const ValueKey('calendar-day-6')));
        await tester.pumpAndSettle();
        expect(find.text('Quiz deadline'), findsOneWidget);
        expect(find.text('Class workshop'), findsOneWidget);
        await tester.ensureVisible(find.text('Class workshop'));
        await tester.tap(find.text('Class workshop'));
        await tester.pumpAndSettle();
        expect(find.text('Edit event'), findsNothing);
        expect(find.text('Delete event'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Instructor can save a class event with PHT dates and students cannot edit',
    (tester) async {
      final service = _Calendar();
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CalendarScreen(
            role: 'instructor',
            service: service,
            initialDate: DateTime.utc(2026, 11, 6),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add event'));
      await tester.pumpAndSettle();
      expect(find.text('Everyone · Schoolwide'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Course review');
      await tester.ensureVisible(find.text('Save event'));
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(service.sentCourse, 'course');
      expect(service.sentStart, DateTime.utc(2026, 11, 5, 16));
      expect(service.sentEnd, DateTime.utc(2026, 11, 6, 15, 59, 59, 999));
      expect(find.text('Course review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Calendar refresh recovers errors and changing accounts clears prior course entries',
    (tester) async {
      final service = _Calendar()..fail = true;
      addTearDown(service.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CalendarScreen(
            role: 'student',
            service: service,
            initialDate: DateTime.utc(2026, 11, 6),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.byTooltip('Refresh calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz deadline'), findsOneWidget);
      service.account = null;
      service.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Quiz deadline'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 1440.0]) {
    for (final empty in [false, true]) {
      testWidgets('Progress charts at $width empty $empty', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudentProgressCharts(
                  learning: empty
                      ? {}
                      : {
                          'totalItems': 4,
                          'completedItems': 1,
                          'totalModules': 11,
                          'completedModules': 0,
                          'totalAssignments': 0,
                          'submittedAssignments': 0,
                          'totalQuizzes': 4,
                          'completedQuizzes': 1,
                        },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Activity balance'), findsNothing);
        expect(find.text('Completion by type'), findsOneWidget);
        expect(
          find.text(empty ? '0 / 0' : '1 / 4'),
          empty ? findsNWidgets(3) : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Navigation removes Inbox entry and curiosity card but keeps header bell and Calendar',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      var inbox = false, selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WorkspaceShell(
            name: 'Student',
            destinations: studentDestinations,
            selectedIndex: 0,
            onSelected: (index) => selected = index,
            onInbox: () => inbox = true,
            onLogout: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('Keep your curiosity.'), findsNothing);
      await tester.tap(find.byTooltip('Notifications'));
      expect(inbox, isTrue);
      await tester.tap(find.byKey(const ValueKey('nav-10')));
      expect(selected, 10);
      expect(tester.takeException(), isNull);
    },
  );
}
