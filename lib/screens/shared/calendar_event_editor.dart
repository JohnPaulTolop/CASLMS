import 'package:flutter/material.dart';

import '../../models/calendar_entry.dart';
import '../../services/calendar_service.dart';

class CalendarEventEditor extends StatefulWidget {
  const CalendarEventEditor({
    super.key,
    required this.role,
    required this.service,
    required this.courses,
    required this.day,
    this.existing,
  });
  final String role;
  final CalendarService service;
  final List<Map<String, dynamic>> courses;
  final DateTime day;
  final CalendarEntry? existing;
  @override
  State<CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<CalendarEventEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description;
  late DateTime _start, _end;
  late String _courseId;
  bool _allDay = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final event = widget.existing;
    _title = TextEditingController(text: event?.title);
    _description = TextEditingController(text: event?.description);
    _allDay = event?.allDay ?? true;
    _start = event == null
        ? DateTime.utc(widget.day.year, widget.day.month, widget.day.day, 9)
        : philippineTime(event.start);
    _end = event == null
        ? _start.add(const Duration(hours: 1))
        : philippineTime(event.end);
    _courseId =
        event?.courseId ??
        (widget.role == 'admin' ? '' : widget.courses.first['id'].toString());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final initial = start ? _start : _end;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day == null || !mounted) return;
    var time = TimeOfDay.fromDateTime(initial);
    if (!_allDay) {
      final picked = await showTimePicker(context: context, initialTime: time);
      if (picked == null || !mounted) return;
      time = picked;
    }
    setState(() {
      final value = DateTime.utc(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
        if (_end.isBefore(value)) _end = value.add(const Duration(hours: 1));
      } else {
        _end = value;
      }
    });
  }

  String _label(DateTime date) =>
      '${MaterialLocalizations.of(context).formatMediumDate(date)}${_allDay ? '' : ' · ${TimeOfDay.fromDateTime(date).format(context)}'}';
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final start = _allDay
        ? DateTime.utc(_start.year, _start.month, _start.day)
        : _start;
    final end = _allDay
        ? DateTime.utc(_end.year, _end.month, _end.day)
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1))
        : _end;
    if (end.isBefore(start) ||
        end.difference(start) > const Duration(days: 31)) {
      setState(
        () => _error = 'Use an end date after the start, within 31 days.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save(
        role: widget.role,
        title: _title.text,
        description: _description.text,
        courseId: _courseId,
        start: philippineWallToUtc(start),
        end: _allDay
            ? DateTime.utc(
                end.year,
                end.month,
                end.day,
                23,
                59,
                59,
                999,
              ).subtract(const Duration(hours: 8))
            : philippineWallToUtc(end),
        allDay: _allDay,
        existing: widget.existing,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this event. Check your connection and course access.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.existing == null ? 'Add event' : 'Edit event'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.service.temporaryEvents)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Temporary event — changes reset when the app reloads.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Event title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an event title.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _courseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Visible to'),
                  items: [
                    if (widget.role == 'admin')
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Everyone · Schoolwide'),
                      ),
                    for (final course in widget.courses)
                      DropdownMenuItem(
                        value: course['id'].toString(),
                        child: Text(
                          '${course['code'] ?? ''} · ${course['title'] ?? 'Course'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _courseId = value!),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _allDay = value),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Starts: ${_label(_start)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(false),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text('Ends: ${_label(_end)}'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Philippine time (UTC+8)',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save event'),
        ),
      ],
    ),
  );
}
