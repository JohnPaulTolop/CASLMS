import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/calendar_entry.dart';
import '../../services/calendar_service.dart';
import '../../services/philippine_holidays.dart';
import '../student/student_course_modules_page.dart';
import '../instructor/instructor_class_details_page.dart';
import 'calendar_event_editor.dart';
import 'workspace_widgets.dart';
import 'workspace_shell.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.role,
    this.service,
    this.initialDate,
  });
  final String role;
  final CalendarService? service;
  final DateTime? initialDate;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final CalendarService _service = widget.service ?? CalendarService();
  late DateTime _day = widget.initialDate ?? philippineDay(DateTime.now());
  late DateTime _month = DateTime.utc(_day.year, _day.month);
  final _filters = CalendarKind.values.toSet();
  CalendarData? _data;
  String? _error, _uid;
  bool _loading = true, _dayOnly = false;
  int _generation = 0;
  StreamSubscription<String?>? _session;
  bool get _staff => widget.role == 'admin' || widget.role == 'instructor';
  @override
  void initState() {
    super.initState();
    _uid = _service.uid;
    _load();
    _session = _service.accountChanges.listen((uid) {
      if (!mounted || uid == _uid) return;
      _uid = uid;
      _generation++;
      setState(() {
        _data = null;
        _error = null;
      });
      if (uid != null) _load();
    });
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service
          .load(widget.role)
          .timeout(const Duration(seconds: 60));
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = data.eventsAvailable ? null : 'Events could not be loaded. Due dates and holidays are shown. Refresh to retry.';
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error =
              'Events and due dates could not be loaded. Refresh to try again.';
        });
      }
    }
  }

  List<CalendarEntry> get _entries =>
      [
          ...?_data?.entries,
          ...PhilippineHolidays.forYear(_month.year),
        ].where((entry) => _filters.contains(entry.kind)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  Color _color(CalendarKind kind) => switch (kind) {
    CalendarKind.event => Theme.of(context).colorScheme.primary,
    CalendarKind.deadline => const Color(0xFF9B7BE5),
    CalendarKind.holiday => const Color(0xFFB8863B),
  };
  String _kind(CalendarKind kind) => switch (kind) {
    CalendarKind.event => 'Event',
    CalendarKind.deadline => 'Due date',
    CalendarKind.holiday => 'Holiday',
  };
  void _move(int offset) => setState(() {
    _month = DateTime.utc(_month.year, _month.month + offset);
    _day = _month;
    _dayOnly = false;
  });
  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _edit([CalendarEntry? existing]) async {
    final courses = _data?.courses ?? [];
    if (_loading || _data == null || !_data!.eventsAvailable) return;
    if (widget.role == 'instructor' && courses.isEmpty) {
      _notice('You need an active course before adding a class event.');
      return;
    }
    if (widget.role == 'instructor' &&
        existing != null &&
        existing.courseId.isEmpty) {
      _notice('Schoolwide events are managed by administrators.');
      return;
    }
    if (existing != null &&
        existing.courseId.isNotEmpty &&
        !courses.any((row) => row['id'] == existing.courseId)) {
      _notice('This course is no longer active.');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CalendarEventEditor(
        role: widget.role,
        service: _service,
        courses: courses,
        day: _day,
        existing: existing,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(CalendarEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(entry.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(widget.role, entry);
      if (mounted) await _load();
    } catch (_) {
      _notice('Unable to delete this event. Check your access and connection.');
    }
  }

  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(philippineTime(date));
  String _when(CalendarEntry entry) => entry.allDay
      ? '${_date(entry.start)} · All day'
      : '${_date(entry.start)} · ${TimeOfDay.fromDateTime(philippineTime(entry.start)).format(context)} PHT';
  Future<void> _details(CalendarEntry entry) async {
    final editable =
        entry.kind == CalendarKind.event &&
        _staff &&
        (widget.role == 'admin' ||
            entry.ownerId == _service.uid &&
                entry.courseId.isNotEmpty &&
                (_data?.courses.any(
                      (course) => course['id'] == entry.courseId,
                    ) ??
                    false));
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text('${_kind(entry.kind)} · ${_when(entry)}'),
              if (philippineDay(entry.end) != philippineDay(entry.start) ||
                  !entry.allDay && entry.kind == CalendarKind.event)
                Text(
                  'Ends ${_date(entry.end)}${entry.allDay ? '' : ' · ${TimeOfDay.fromDateTime(philippineTime(entry.end)).format(context)} PHT'}',
                ),
              if (entry.courseLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(entry.courseLabel),
                ),
              if (entry.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(entry.description),
                ),
              if (entry.sourceUrl != null)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      if (!await launchUrl(
                        Uri.parse(entry.sourceUrl!),
                        mode: LaunchMode.externalApplication,
                      )) {
                        _notice('Unable to open the holiday source.');
                      }
                    } catch (_) {
                      _notice('Unable to open the holiday source.');
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Official holiday declaration'),
                ),
              if (entry.kind == CalendarKind.deadline && widget.role != 'admin')
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'open'),
                  child: const Text('Open course activity'),
                ),
              if (editable)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit event'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete event'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') await _edit(entry);
    if (action == 'delete') await _delete(entry);
    if (action == 'open') {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.role == 'student'
              ? StudentCourseModulesScreen(
                  courseId: entry.courseId,
                  courseCode: (entry.course['code'] ?? '').toString(),
                  courseTitle: (entry.course['title'] ?? '').toString(),
                  instructorName: (entry.course['instructorName'] ?? '')
                      .toString(),
                  initialModuleId: entry.moduleId,
                  initialAssessmentId: entry.assessmentId,
                  initialView: 1,
                )
              : InstructorClassDetailsScreen(courseId: entry.courseId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: LayoutBuilder(
      builder: (context, box) => RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            workspaceInset(box.maxWidth),
            0,
            workspaceInset(box.maxWidth),
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspaceHeading(
                showEyebrow: false,
                title: 'Calendar',
                eyebrow: '',
                subtitle: 'Events, coursework due dates and Philippine holidays. Times in PHT.',
                actions: [
                  IconButton(
                    tooltip: 'Refresh calendar',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (_staff)
                    IconButton(
                      tooltip: 'Add event',
                      onPressed:
                          _loading || _data == null || !_data!.eventsAvailable
                          ? null
                          : () => _edit(),
                      icon: const Icon(Icons.add_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final kind in CalendarKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${_kind(kind)}s'),
                          avatar: Icon(
                            Icons.circle,
                            size: 9,
                            color: _color(kind),
                          ),
                          selected: _filters.contains(kind),
                          onSelected: (value) => setState(() {
                            if (value) {
                              _filters.add(kind);
                            } else {
                              _filters.remove(kind);
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (box.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(14) < 23)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 440, child: _grid()),
                    const SizedBox(width: 24),
                    Expanded(child: _agenda()),
                  ],
                )
              else ...[
                _grid(),
                const SizedBox(height: 20),
                if (_service.temporaryEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Events are temporary on this device and reset when the app reloads. Course due dates and holidays use real data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _agenda(),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  Widget _grid() {
    final entries = _entries;
    final offset = (_month.weekday - 1) % 7;
    final count = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final cells = ((count + offset) / 7).ceil() * 7;
    final today = philippineDay(DateTime.now());
    return WorkspaceSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context).formatMonthYear(_month),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _day = today;
                _month = DateTime.utc(today.year, today.month);
                _dayOnly = true;
              }),
              child: const Text('Today'),
            ),
          ),
          Row(
            children: [
              for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 20
                  ? 58
                  : 44,
              crossAxisSpacing: 2,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final number = index - offset + 1;
              if (number < 1 || number > count) return const SizedBox.shrink();
              final day = DateTime.utc(_month.year, _month.month, number);
              final kinds = entries
                  .where((entry) => entry.occursOn(day))
                  .map((entry) => entry.kind)
                  .toSet();
              final selected = day == _day;
              return Semantics(
                selected: selected,
                label:
                    '${MaterialLocalizations.of(context).formatFullDate(day)}, ${kinds.length} event types',
                child: Material(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: day == today && !selected
                        ? BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    key: ValueKey('calendar-day-$number'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _day = day;
                      _dayOnly = true;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$number',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final kind in kinds)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : _color(kind),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            PhilippineHolidays.sources.containsKey(_month.year)
                ? '${_month.year} national holidays verified. ${_month.year == 2027 ? 'Eid dates await separate proclamations.' : 'Includes declared Eid dates.'}'
                : 'Official holiday dates for this year are not loaded.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _agenda() {
    final entries = _entries
        .where(
          (entry) => _dayOnly
              ? entry.occursOn(_day)
              : !philippineDay(entry.end).isBefore(_month) &&
                    philippineDay(entry.start)
                        .isBefore(DateTime.utc(_month.year, _month.month + 1)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _dayOnly
                  ? MaterialLocalizations.of(context).formatMediumDate(_day)
                  : 'This month',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (_dayOnly)
              TextButton(
                onPressed: () => setState(() => _dayOnly = false),
                child: const Text('Show full month'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const WorkspaceEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing scheduled',
            message: 'Choose another day or adjust the filters.',
          ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                leading: Icon(
                  entry.kind == CalendarKind.deadline
                      ? Icons.assignment_outlined
                      : entry.kind == CalendarKind.holiday
                      ? Icons.flag_outlined
                      : Icons.event_outlined,
                  color: _color(entry.kind),
                ),
                title: Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${_when(entry)}${entry.courseLabel.isEmpty ? '' : '\n${entry.courseLabel}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => _details(entry),
              ),
            ),
          ),
      ],
    );
  }
}
