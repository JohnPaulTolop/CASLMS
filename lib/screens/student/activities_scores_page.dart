import 'package:flutter/material.dart';

import '../../models/gradebook_models.dart';
import '../../services/semester_grades_service.dart';

class ActivitiesScoresScreen extends StatefulWidget {
  const ActivitiesScoresScreen({super.key, this.api});
  final GradebookApi? api;
  @override
  State<ActivitiesScoresScreen> createState() => _ActivitiesScoresScreenState();
}

class _ActivitiesScoresScreenState extends State<ActivitiesScoresScreen> {
  late final GradebookApi _api = widget.api ?? SemesterGradesService();
  List<ActivityScore> _activities = [];
  bool _loading = true;
  String? _error, _subject, _type;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.request('activities');
      final activities = (result['activities'] as List)
          .map(
            (row) =>
                ActivityScore.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      if (mounted) {
        setState(() {
          _activities = activities;
          _loading = false;
          if (!_activities.any((row) => row.courseId == _subject)) {
            _subject = null;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = {for (final row in _activities) row.courseId: row.subject};
    final visible = _activities
        .where(
          (row) =>
              (_subject == null || row.courseId == _subject) &&
              (_type == null || row.type == _type),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Activities & Scores'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Refresh activities',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your submitted work',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scores here are raw points. Pending grades remain blank; a graded zero is shown as zero. Reported quiz scores still need instructor review.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('subject-$_subject'),
                    initialValue: _subject,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All subjects'),
                      ),
                      ...subjects.entries.map(
                        (row) => DropdownMenuItem(
                          value: row.key,
                          child: Text(
                            row.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _subject = value),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('type-$_type'),
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Activity type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All activity types'),
                      ),
                      ...['activity', 'quiz', 'assignment', 'exam'].map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type[0].toUpperCase() + type.substring(1),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _type = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : visible.isEmpty
                  ? const Center(
                      child: Text('No submitted work matches these filters.'),
                    )
                  : SingleChildScrollView(
                      child: PaginatedDataTable(
                        key: ValueKey('$_subject|$_type|${visible.length}'),
                        header: Text('${visible.length} submitted activities'),
                        rowsPerPage: visible.length < 10 ? visible.length : 10,
                        showEmptyRows: false,
                        columns: const [
                          DataColumn(label: Text('Activity Title')),
                          DataColumn(label: Text('Subject Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Date Submitted')),
                          DataColumn(
                            label: Text('Total Points'),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text('Points Earned'),
                            numeric: true,
                          ),
                          DataColumn(label: Text('Score %'), numeric: true),
                          DataColumn(label: Text('Status')),
                        ],
                        source: _ActivityRows(visible),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRows extends DataTableSource {
  _ActivityRows(this.rows);
  final List<ActivityScore> rows;
  String number(double? value) => value == null
      ? '—'
      : value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final row = rows[index];
    final date = row.submittedAt.toLocal();
    return DataRow(
      cells: [
        DataCell(SizedBox(width: 210, child: Text(row.title))),
        DataCell(SizedBox(width: 190, child: Text(row.subject))),
        DataCell(Text(row.type)),
        DataCell(
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date).format24()}',
          ),
        ),
        DataCell(Text(number(row.totalPoints))),
        DataCell(Text(number(row.pointsEarned))),
        DataCell(
          Text(row.percentage == null ? '—' : '${number(row.percentage)}%'),
        ),
        DataCell(
          Text(
            '${row.status}${row.late ? ' · Late' : ''}${row.needsInstructorReview ? '\nInstructor review needed' : ''}',
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}

extension on TimeOfDay {
  String format24() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
