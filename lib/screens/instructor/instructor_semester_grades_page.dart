import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import '../../services/semester_grades_service.dart';

class InstructorSemesterGradesScreen extends StatefulWidget {
  const InstructorSemesterGradesScreen({
    super.key,
    this.courseId,
    this.sectionId,
  });
  final String? courseId, sectionId;
  @override
  State<InstructorSemesterGradesScreen> createState() =>
      _InstructorSemesterGradesScreenState();
}

class _InstructorSemesterGradesScreenState
    extends State<InstructorSemesterGradesScreen> {
  final GradebookApi _api = SemesterGradesService();
  final _weights = {
    for (final key in ['activity', 'quiz', 'assignment', 'exam'])
      key: TextEditingController(text: '0'),
  };
  List<Map<String, dynamic>> _courses = [], _sections = [];
  final Map<String, Map<String, dynamic>> _dispositions = {};
  Map<String, dynamic>? _preview;
  String? _course, _section, _error;
  String _missing = 'incomplete';
  bool _legacyReviewed = false, _loading = true, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _weights.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw const GradebookException('Please sign in again.');
      final courses = await FirebaseFirestore.instance
          .collection('courses')
          .where('instructorId', isEqualTo: uid)
          .get();
      _courses = courses.docs
          .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
          .toList();
      if (widget.courseId != null &&
          _courses.any((row) => row['id'] == widget.courseId)) {
        _course = widget.courseId;
        _sections = await CourseSectionService().getSections(_course!);
        _section = _sections.any((row) => row['id'] == widget.sectionId)
            ? widget.sectionId
            : null;
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseCourse(String? value) async {
    setState(() {
      _course = value;
      _section = null;
      _sections = [];
      _preview = null;
      _dispositions.clear();
      _loading = true;
      _error = null;
    });
    try {
      final sections = value == null
          ? <Map<String, dynamic>>[]
          : await CourseSectionService().getSections(value);
      if (mounted) {
        setState(() {
          _sections = sections
              .where((row) => row['status'] == 'active')
              .toList();
          _loading = false;
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

  Map<String, dynamic> _request() {
    if (_course == null || _section == null) {
      throw const GradebookException('Select a subject and section.');
    }
    final weights = <String, double>{};
    for (final entry in _weights.entries) {
      final value = double.tryParse(entry.value.text);
      if (value == null || !value.isFinite || value < 0 || value > 100) {
        throw const GradebookException('Enter valid weights from 0 to 100.');
      }
      weights[entry.key] = value;
    }
    if ((weights.values.fold(0.0, (total, value) => total + value) - 100)
            .abs() >
        0.000001) {
      throw const GradebookException('Category weights must total 100%.');
    }
    return {
      'courseId': _course,
      'sectionId': _section,
      'weights': weights,
      'missing': _missing,
      'acceptLegacyQuizScores': _legacyReviewed,
      'dispositions': _dispositions,
    };
  }

  Future<void> _compute() async {
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await _api.request('preview', _request());
      if (mounted) setState(() => _preview = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    if (_preview == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Post semester grades?'),
        content: const Text(
          'This posts the previewed grades for this section. Students must verify their credentials to reveal them. Later corrections require a new preview and posting revision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Post grades'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.request('finalize', {
        ..._request(),
        'previewHash': _preview!['previewHash'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['postedCount']} semester grades posted.'),
          ),
        );
        setState(() => _preview = null);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposition(Map<String, dynamic> row) async {
    final uid = row['studentId'] as String;
    var code = _dispositions[uid]?['code'] as String? ?? 'AUTO';
    final reason = TextEditingController(
      text: _dispositions[uid]?['reason'] as String? ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Grade status · ${row['studentName']}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: code,
                  items: ['AUTO', 'INC', 'DRP']
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item == 'AUTO' ? 'Compute from scores' : item,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => update(() => code = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reason,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required for INC / DRP)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (code != 'AUTO' && reason.text.trim().isEmpty) return;
                Navigator.pop(dialog, true);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        if (code == 'AUTO') {
          _dispositions.remove(uid);
        } else {
          _dispositions[uid] = {'code': code, 'reason': reason.text.trim()};
        }
        _preview = null;
      });
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        (_preview?['grades'] as List?)
            ?.map((row) => Map<String, dynamic>.from(row as Map))
            .toList() ??
        [];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(title: const Text('Semester Grades')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Compute & Finalize Semester Grades',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure weights from your syllabus. Category points are pooled, weighted, then transmuted using (raw percentage × 0.5) + 50. The supplied numerical scale is applied without rounding up.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 330,
                      child: DropdownButtonFormField<String>(
                        initialValue: _course,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                        items: _courses
                            .map(
                              (row) => DropdownMenuItem(
                                value: row['id'] as String,
                                child: Text(
                                  '${row['code']} · ${row['title']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy ? null : _chooseCourse,
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('section-$_course-$_section'),
                        initialValue: _section,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(),
                        ),
                        items: _sections
                            .map(
                              (row) => DropdownMenuItem(
                                value: row['id'] as String,
                                child: Text(row['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _section = value;
                                _preview = null;
                                _dispositions.clear();
                              }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: _weights.entries
                      .map(
                        (entry) => SizedBox(
                          width: 150,
                          child: TextField(
                            controller: entry.value,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() => _preview = null),
                            decoration: InputDecoration(
                              labelText: '${entry.key} weight',
                              suffixText: '%',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _missing,
                  decoration: const InputDecoration(
                    labelText: 'Missing submissions',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'incomplete',
                      child: Text('Mark INC until requirements are complete'),
                    ),
                    DropdownMenuItem(
                      value: 'zero',
                      child: Text('Count unsubmitted work as zero'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _missing = value!;
                          _preview = null;
                        }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _legacyReviewed,
                  title: const Text(
                    'I reviewed legacy quiz scores against my records',
                  ),
                  subtitle: const Text(
                    'Older quizzes report scores from the student app. Unreviewed legacy scores and submitted work awaiting grading produce INC.',
                  ),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _legacyReviewed = value!;
                          _preview = null;
                        }),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _compute,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Compute Preview'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _preview == null ? null : _finalize,
                      icon: const Icon(Icons.publish),
                      label: const Text('Compute & Finalize Semester Grades'),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: LinearProgressIndicator(),
                  ),
                if (_preview != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${_preview!['courseTitle']} · ${_preview!['sectionName']} · ${_preview!['termLabel']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Review every row. Use Grade status to record INC/DRP with a reason, then compute a new preview.',
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Student ID')),
                        DataColumn(label: Text('Raw %')),
                        DataColumn(label: Text('Transmuted %')),
                        DataColumn(label: Text('Final Grade')),
                        DataColumn(label: Text('Result / Requirements')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: rows
                          .map(
                            (row) => DataRow(
                              cells: [
                                DataCell(Text(row['studentName'] as String)),
                                DataCell(Text(row['campusId'] as String)),
                                DataCell(
                                  Text(
                                    row['rawPercentage'] == null
                                        ? '—'
                                        : (row['rawPercentage'] as num)
                                              .toStringAsFixed(4),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row['percentage'] == null
                                        ? '—'
                                        : (row['percentage'] as num)
                                              .toStringAsFixed(4),
                                  ),
                                ),
                                DataCell(Text(row['grade'] as String)),
                                DataCell(
                                  SizedBox(
                                    width: 270,
                                    child: Text(
                                      '${row['result']}${(row['issues'] as List).isEmpty ? '' : '\n${(row['issues'] as List).join('; ')}'}',
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _disposition(row),
                                    child: const Text('Grade status'),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
