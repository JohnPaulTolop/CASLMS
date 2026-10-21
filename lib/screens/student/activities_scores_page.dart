import 'package:flutter/material.dart';

import '../../models/gradebook_models.dart';
import '../../services/semester_grades_service.dart';
import '../shared/grading_ui.dart';

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
  String _search = '';
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
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _loading = false;
        if (!_activities.any((row) => row.courseId == _subject)) {
          _subject = null;
        }
      });
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
              (_type == null || row.type == _type) &&
              '${row.title} ${row.subject}'.toLowerCase().contains(
                _search.toLowerCase(),
              ),
        )
        .toList();
    final graded = _activities
        .where((row) => row.status.toLowerCase() == 'graded')
        .length;
    return Scaffold(
      backgroundColor: gradeBackground,
      appBar: AppBar(
        title: const Text(
          'Activities & Scores',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          RoundGradeAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh activities',
            accent: gradeBlue,
            onTap: _loading ? null : _load,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
            children: [
              const GradeEntrance(
                child: GradeHero(
                  title: 'Your work. Your progress.',
                  subtitle: 'Find your submissions, check scores, and see what is waiting for feedback.',
                  icon: Icons.assignment_turned_in_outlined,
                ),
              ),
              const SizedBox(height: 16),
              if (!_loading && _error == null) ...[
                GradeStats(
                  items: [
                    (
                      label: 'Submitted',
                      value: '${_activities.length}',
                      icon: Icons.task_alt,
                      color: gradeBlue,
                    ),
                    (
                      label: 'Graded',
                      value: '$graded',
                      icon: Icons.verified_outlined,
                      color: gradeTeal,
                    ),
                    (
                      label: 'Awaiting review',
                      value: '${_activities.length - graded}',
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFB76A00),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              GradeSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Find an activity',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: gradeInk,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, size) {
                        final search = TextField(
                          onChanged: (value) => setState(() => _search = value),
                          decoration: gradeInput(
                            'Search activities',
                            icon: Icons.search_rounded,
                            hint: 'Activity title or subject',
                          ),
                        );
                        final subject = DropdownButtonFormField<String>(
                          key: ValueKey('subject-$_subject'),
                          initialValue: _subject,
                          isExpanded: true,
                          decoration: gradeInput(
                            'Subject',
                            icon: Icons.menu_book_outlined,
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
                          onChanged: (value) =>
                              setState(() => _subject = value),
                        );
                        return size.maxWidth < 600
                            ? Column(
                                children: [
                                  search,
                                  const SizedBox(height: 12),
                                  subject,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: search),
                                  const SizedBox(width: 14),
                                  Expanded(child: subject),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          <String?, String>{
                                null: 'All work',
                                'activity': 'Activities',
                                'quiz': 'Quizzes',
                                'unit_test': 'Unit Tests',
                                'assignment': 'Assignments',
                                'exam': 'Exams',
                              }.entries
                              .map(
                                (entry) => ChoiceChip(
                                  selected: _type == entry.key,
                                  label: Text(entry.value),
                                  avatar: Icon(
                                    entry.key == null
                                        ? Icons.apps_rounded
                                        : gradeTypeIcon(entry.key!),
                                    size: 17,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _type = entry.key),
                                  selectedColor: gradeBlue.withValues(
                                    alpha: .12,
                                  ),
                                  side: const BorderSide(color: gradeBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Submission history',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: gradeInk,
                      ),
                    ),
                  ),
                  if (!_loading) GradeBadge('${visible.length} results'),
                ],
              ),
              const SizedBox(height: 14),
              if (_loading)
                const GradeSurface(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_error != null)
                GradeStateMessage(
                  title: 'Could not load activities',
                  message: _error!,
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                )
              else if (visible.isEmpty)
                const GradeStateMessage(
                  title: 'No matching submissions',
                  message: 'Try another subject or activity type, or change your search.',
                )
              else if (constraints.maxWidth < 800)
                ...visible.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActivityCard(row),
                  ),
                )
              else
                GradeSurface(
                  padding: const EdgeInsets.all(8),
                  child: PaginatedDataTable(
                    key: ValueKey(
                      '$_subject|$_type|$_search|${visible.length}',
                    ),
                    rowsPerPage: visible.length < 10 ? visible.length : 10,
                    showEmptyRows: false,
                    columnSpacing: 24,
                    dataRowMinHeight: 72,
                    dataRowMaxHeight: 88,
                    columns: const [
                      DataColumn(label: Text('Activity')),
                      DataColumn(label: Text('Subject')),
                      DataColumn(label: Text('Submitted')),
                      DataColumn(label: Text('Max points'), numeric: true),
                      DataColumn(label: Text('Earned'), numeric: true),
                      DataColumn(label: Text('Score'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    source: _ActivityRows(visible),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Scores show raw points. A dash means a score is pending; a graded zero is shown as 0. Reported quiz scores require instructor review.',
                  style: TextStyle(
                    color: gradeMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _date(ActivityScore row) {
  final date = row.submittedAt.toLocal();
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Widget _status(ActivityScore row) => Wrap(
  spacing: 5,
  runSpacing: 5,
  children: [
    GradeBadge(
      row.status,
      color: row.status.toLowerCase() == 'graded'
          ? gradeTeal
          : const Color(0xFFB76A00),
    ),
    if (row.late) const GradeBadge('Late', color: Color(0xFFC54444)),
  ],
);

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.row);
  final ActivityScore row;
  @override
  Widget build(BuildContext context) => GradeSurface(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: gradeBlue.withValues(alpha: .09),
              child: Icon(gradeTypeIcon(row.type), color: gradeBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: gradeInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.subject,
                    style: const TextStyle(fontSize: 12, color: gradeMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${row.type.replaceAll('_', ' ').toUpperCase()}  /  ${_date(row)}',
          style: const TextStyle(fontSize: 11, color: gradeMuted),
        ),
        const SizedBox(height: 10),
        _status(row),
        const Divider(height: 28, color: gradeBorder),
        Row(
          children: [
            Expanded(
              child: Text(
                '${gradeNumber(row.pointsEarned)} / ${gradeNumber(row.totalPoints)} points',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: gradeInk,
                ),
              ),
            ),
            Text(
              row.percentage == null
                  ? 'Pending'
                  : '${gradeNumber(row.percentage)}%',
              style: const TextStyle(
                color: gradeBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (row.needsInstructorReview)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Instructor review needed',
              style: TextStyle(color: gradeMuted, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class _ActivityRows extends DataTableSource {
  _ActivityRows(this.rows);
  final List<ActivityScore> rows;
  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final row = rows[index];
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 190,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  row.type == 'unit_test' ? 'Unit Test' : row.type,
                  style: const TextStyle(color: gradeMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              row.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(_date(row))),
        DataCell(Text(gradeNumber(row.totalPoints))),
        DataCell(Text(gradeNumber(row.pointsEarned))),
        DataCell(
          Text(
            row.percentage == null ? '-' : '${gradeNumber(row.percentage)}%',
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _status(row),
              if (row.needsInstructorReview)
                const Text(
                  'Review needed',
                  style: TextStyle(fontSize: 11, color: gradeMuted),
                ),
            ],
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
