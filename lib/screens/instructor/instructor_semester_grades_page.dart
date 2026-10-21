import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import '../../services/semester_grades_service.dart';
import '../shared/grading_ui.dart';

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
    for (final key in ['activity', 'quiz', 'unit_test', 'assignment', 'exam'])
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
    var reasonRequired = false;
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
                  decoration: InputDecoration(
                    labelText: 'Reason (required for INC / DRP)',
                    errorText: reasonRequired
                        ? 'Enter a reason before applying this status.'
                        : null,
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
                if (code != 'AUTO' && reason.text.trim().isEmpty) {
                  update(() => reasonRequired = true);
                  return;
                }
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

  Widget _step(int number, String title, String subtitle, Widget child) =>
      GradeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: gradeTeal.withValues(alpha: .1),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: gradeTeal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: gradeInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: gradeMuted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final rows =
        (_preview?['grades'] as List?)
            ?.map((row) => Map<String, dynamic>.from(row as Map))
            .toList() ??
        [];
    final values = _weights.values
        .map((controller) => double.tryParse(controller.text))
        .toList();
    final validValues = values.every(
      (value) => value != null && value.isFinite && value >= 0 && value <= 100,
    );
    final total = values.fold(
      0.0,
      (total, value) => total + (value != null && value.isFinite ? value : 0),
    );
    final validWeights = validValues && (total - 100).abs() < .000001;
    return Scaffold(
      backgroundColor: gradeBackground,
      appBar: AppBar(
        title: const Text(
          'Semester Grades',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, size) => ListView(
                padding: EdgeInsets.all(size.maxWidth < 600 ? 16 : 24),
                children: [
                  const GradeEntrance(
                    child: GradeHero(
                      title: 'From scores to semester grades.',
                      subtitle: 'Follow the three steps below. Preview grades before posting them to your students.',
                      icon: Icons.calculate_outlined,
                      accent: gradeTeal,
                      eyebrow: 'SEMESTER GRADING',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _step(
                    1,
                    'Choose your class',
                    'Select the subject and section you want to grade.',
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth < 650
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 14) / 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _course,
                              isExpanded: true,
                              decoration: gradeInput(
                                'Subject',
                                icon: Icons.menu_book_outlined,
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
                            width: constraints.maxWidth < 650
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 14) / 2,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('section-$_course-$_section'),
                              initialValue: _section,
                              isExpanded: true,
                              decoration: gradeInput(
                                'Section',
                                icon: Icons.groups_outlined,
                                hint: _course == null
                                    ? 'Choose a subject first'
                                    : 'Choose a section',
                              ),
                              items: _sections
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row['id'] as String,
                                      child: Text(
                                        row['name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _busy || _course == null
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  _step(
                    2,
                    'Set category weights',
                    'Use the percentages in your syllabus. All five categories must total 100%.',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 14,
                            children: _weights.entries
                                .map(
                                  (entry) => SizedBox(
                                    width: constraints.maxWidth < 650
                                        ? (constraints.maxWidth - 12) / 2
                                        : (constraints.maxWidth - 36) / 4,
                                    child: TextField(
                                      controller: entry.value,
                                      enabled: !_busy,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) =>
                                          setState(() => _preview = null),
                                      decoration: gradeInput(
                                        entry.key == 'unit_test'
                                            ? 'Unit Test'
                                            : entry.key[0].toUpperCase() +
                                                  entry.key.substring(1),
                                        icon: gradeTypeIcon(entry.key),
                                      ).copyWith(suffixText: '%'),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GradeBadge(
                              '${gradeNumber(total)} / 100%',
                              color: validWeights
                                  ? gradeTeal
                                  : const Color(0xFFB76A00),
                              icon: validWeights
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                            ),
                            Text(
                              !validValues
                                  ? 'Enter a valid percentage in every category.'
                                  : validWeights
                                  ? 'Weights are ready.'
                                  : total < 100
                                  ? '${gradeNumber(100 - total)}% left to allocate'
                                  : 'Reduce the total by ${gradeNumber(total - 100)}%',
                              style: const TextStyle(
                                color: gradeMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (total / 100).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: gradeBorder,
                            color: validWeights
                                ? gradeTeal
                                : const Color(0xFFB76A00),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          title: const Text(
                            'Grading rules & missing work',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Review these settings before computing.',
                            style: TextStyle(fontSize: 12),
                          ),
                          children: [
                            const Text(
                              'Category points are pooled and weighted. Transmuted percentage = (raw percentage × 0.5) + 50. The configured numerical scale is applied without rounding up.',
                              style: TextStyle(
                                color: gradeMuted,
                                height: 1.6,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _missing,
                              isExpanded: true,
                              decoration: gradeInput('Missing submissions'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'incomplete',
                                  child: Text(
                                    'Mark INC until complete',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'zero',
                                  child: Text(
                                    'Count unsubmitted work as zero',
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                style: TextStyle(fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Unreviewed legacy scores and submitted work awaiting grading produce INC.',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                      _legacyReviewed = value!;
                                      _preview = null;
                                    }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _step(
                    3,
                    'Review & post',
                    'Compute a preview, check every student, then post the final grades.',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (_course == null ||
                            _section == null ||
                            !validWeights)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              'Choose a class and complete the 100% weight allocation to continue.',
                              style: TextStyle(color: gradeMuted, fontSize: 12),
                            ),
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _busy ||
                                      _course == null ||
                                      _section == null ||
                                      !validWeights
                                  ? null
                                  : _compute,
                              icon: const Icon(Icons.calculate_outlined),
                              label: Text(
                                _busy ? 'Please wait...' : 'Compute Preview',
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: gradeTeal,
                              ),
                              onPressed: _busy || _preview == null
                                  ? null
                                  : _finalize,
                              icon: const Icon(Icons.publish_outlined),
                              label: const Text('Post Semester Grades'),
                            ),
                          ],
                        ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: LinearProgressIndicator(),
                          ),
                        if (_preview == null && !_busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Text(
                              'Posting becomes available after you compute a preview.',
                              style: TextStyle(color: gradeMuted, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 20),
                    GradeEntrance(
                      child: GradeSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                const GradeBadge(
                                  'Preview · not posted',
                                  color: gradeTeal,
                                  icon: Icons.visibility_outlined,
                                ),
                                GradeBadge(
                                  '${rows.length} students',
                                  color: gradeTeal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_preview!['courseTitle']} · ${_preview!['sectionName']} · ${_preview!['termLabel']}',
                              style: const TextStyle(
                                color: gradeInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Review each row. Changing a grade status clears this preview; compute again before posting. Scroll the table sideways to see all columns.',
                              style: TextStyle(
                                color: gradeMuted,
                                fontSize: 12,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Student')),
                                  DataColumn(label: Text('Student ID')),
                                  DataColumn(label: Text('Raw %')),
                                  DataColumn(label: Text('Transmuted %')),
                                  DataColumn(label: Text('Final Grade')),
                                  DataColumn(
                                    label: Text('Result / Requirements'),
                                  ),
                                  DataColumn(label: Text('Action')),
                                ],
                                rows: rows
                                    .map(
                                      (row) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(row['studentName'] as String),
                                          ),
                                          DataCell(
                                            Text(row['campusId'] as String),
                                          ),
                                          DataCell(
                                            Text(
                                              row['rawPercentage'] == null
                                                  ? '—'
                                                  : (row['rawPercentage']
                                                            as num)
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
                                          DataCell(
                                            Text(row['grade'] as String),
                                          ),
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
                                              onPressed: _busy
                                                  ? null
                                                  : () => _disposition(row),
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
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
