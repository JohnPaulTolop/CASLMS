import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import 'instructor_assessment_grading_page.dart';
import 'instructor_class_details_page.dart';

/// Instructor-only view of an individual course section.
/// Modules are shared across the course; assessments and grades are scoped
/// to their explicit sectionId. Untagged assessments remain course-wide.
class InstructorSectionDetailsScreen extends StatefulWidget {
  const InstructorSectionDetailsScreen({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final String courseId;
  final String sectionId;

  @override
  State<InstructorSectionDetailsScreen> createState() =>
      _InstructorSectionDetailsScreenState();
}

class _SectionViewData {
  const _SectionViewData({
    required this.course,
    required this.section,
    required this.allStudents,
    required this.students,
    required this.modules,
    required this.assessments,
    required this.submissions,
    required this.courseWideCount,
  });

  final Map<String, dynamic> course;
  final Map<String, dynamic> section;
  final List<Map<String, dynamic>> allStudents;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> modules;
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> submissions;
  final int courseWideCount;
}

class _InstructorSectionDetailsScreenState
    extends State<InstructorSectionDetailsScreen> {
  static const Color teal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CourseSectionService _sections = CourseSectionService();
  late Future<_SectionViewData> _future;
  bool _transferring = false;

  String _text(Object? value) => (value ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SectionViewData> _load() async {
    // getSection also verifies the signed-in instructor owns this course.
    final section = await _sections.getSection(
      courseId: widget.courseId,
      sectionId: widget.sectionId,
    );

    final courseDocument = await _db
        .collection('courses')
        .doc(widget.courseId)
        .get();
    final course = courseDocument.data();
    if (course == null) throw StateError('Course no longer exists.');

    final enrollmentDocuments = await _db
        .collection('enrollments')
        .where('courseId', isEqualTo: widget.courseId)
        .get();
    final moduleDocuments = await _db
        .collection('modules')
        .where('courseId', isEqualTo: widget.courseId)
        .get();
    final assessmentDocuments = await _db
        .collection('assessments')
        .where('courseId', isEqualTo: widget.courseId)
        .get();
    final submissionDocuments = await _db
        .collection('assessmentSubmissions')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    final originalCode = _text(course['classCode']);
    String enrollmentSection(Map<String, dynamic> enrollment) {
      final explicitSection = _text(enrollment['sectionId']);
      return explicitSection.isEmpty ? originalCode : explicitSection;
    }

    final allStudents = enrollmentDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .where((data) => _text(data['status']) == 'active')
        .toList();
    final students = allStudents
        .where((data) => enrollmentSection(data) == widget.sectionId)
        .toList();
    students.sort(
      (a, b) =>
          _text(a['studentName'])
              .toLowerCase()
              .compareTo(_text(b['studentName']).toLowerCase()),
    );

    // All course modules are shared. They are never represented as section-only.
    final modules = moduleDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();
    modules.sort(
      (a, b) => ((a['order'] as num?)?.toInt() ?? 0).compareTo(
        (b['order'] as num?)?.toInt() ?? 0,
      ),
    );

    final allAssessments = assessmentDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();
    final assessments = allAssessments
        .where((data) => _text(data['sectionId']) == widget.sectionId)
        .toList();
    final courseWideCount = allAssessments
        .where((data) => _text(data['sectionId']).isEmpty)
        .length;
    final sectionAssessmentIds = assessments
        .map((data) => _text(data['id']))
        .toSet();
    final submissions = submissionDocuments.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .where(
          (data) => sectionAssessmentIds.contains(_text(data['assessmentId'])),
        )
        .toList();

    return _SectionViewData(
      course: {...course, 'id': courseDocument.id},
      section: section,
      allStudents: allStudents,
      students: students,
      modules: modules,
      assessments: assessments,
      submissions: submissions,
      courseWideCount: courseWideCount,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final nextLoad = _load();
    setState(() {
      _future = nextLoad;
    });
    try {
      await _future;
    } catch (_) {
      // FutureBuilder displays errors with Retry.
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _transferStudent(_SectionViewData data) async {
    if (_transferring || _text(data.section['status']) != 'active') return;

    final originalCode = _text(data.course['classCode']);
    final candidates = data.allStudents.where((student) {
      final assignedSection = _text(student['sectionId']);
      final effectiveSection = assignedSection.isEmpty
          ? originalCode
          : assignedSection;
      return effectiveSection != widget.sectionId &&
          _text(student['studentId']).isNotEmpty;
    }).toList();

    if (candidates.isEmpty) {
      _notice('No students from other sections are available to transfer.');
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Transfer enrolled student'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: candidates.map((student) {
              final name = _text(student['studentName']);
              final id = _text(student['studentId']);
              return ListTile(
                title: Text(name.isEmpty ? id : name),
                subtitle: Text('Student ID: $id'),
                onTap: () => Navigator.of(dialog).pop(id),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedId == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirm section transfer'),
        content: Text(
          'Move this student to ${_text(data.section['name'])}? '
          'Their course enrollment will be preserved. '
          'Section-specific assessments available to the student may change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _transferring = true);
    try {
      await _sections.assignStudent(
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        studentId: selectedId,
      );
      _notice('Student transferred successfully.');
      await _refresh();
    } catch (error) {
      _notice('Unable to transfer student: $error');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _openGrading(Map<String, dynamic> assessment) async {
    final assessmentId = _text(assessment['id']);
    if (assessmentId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InstructorAssessmentGradingScreen(assessmentId: assessmentId),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openCourseTools(_SectionViewData data) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstructorClassDetailsScreen(
          courseId: widget.courseId,
          courseCode: _text(data.course['code']),
          courseTitle: _text(data.course['title']),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );

  Widget _studentsTab(_SectionViewData data) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${data.students.length} enrolled student(s)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton.icon(
            onPressed:
                _transferring || _text(data.section['status']) != 'active'
                ? null
                : () => _transferStudent(data),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Transfer student'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (data.students.isEmpty)
        _empty('No active students are assigned to this section.')
      else
        ...data.students.map(
          (student) => Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: teal),
              title: Text(
                _text(student['studentName']).isEmpty
                    ? _text(student['studentId'])
                    : _text(student['studentName']),
              ),
              subtitle: Text(
                _text(student['studentCampusId']).isNotEmpty
                    ? 'Campus ID: ${_text(student['studentCampusId'])}'
                    : 'Student ID: ${_text(student['studentId'])}',
              ),
            ),
          ),
        ),
    ],
  );

  Widget _modulesTab(_SectionViewData data) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline, color: teal),
          title: Text('Shared course modules'),
          subtitle: Text(
            'Modules and learning materials belong to the '
            'course, not a single section. Section-specific quizzes '
            'are shown in the Assessments tab.',
          ),
        ),
      ),
      if (data.modules.isEmpty)
        _empty('No modules have been created for this course.')
      else
        ...data.modules.map(
          (module) => Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: teal),
              title: Text(_text(module['title'])),
              subtitle: Text('Status: ${_text(module['status'])}'),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _openCourseTools(data),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Open course-wide tools'),
        ),
      ),
    ],
  );

  Widget _assessmentsTab(_SectionViewData data) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        '${data.assessments.length} section-assigned assessment(s)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      if (data.assessments.isEmpty)
        _empty(
          'No assessments are assigned specifically to this '
          'section yet. AI quizzes can be assigned to a section '
          'during secure publishing.',
        )
      else
        ...data.assessments.map(
          (assessment) => Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined, color: teal),
              title: Text(_text(assessment['title'])),
              subtitle: Text(
                'Status: ${_text(assessment['status'])} '
                '\u2022 Type: ${_text(assessment['assessmentType'])}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openGrading(assessment),
            ),
          ),
        ),
      if (data.courseWideCount > 0) ...[
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: teal),
            title: Text('${data.courseWideCount} course-wide assessment(s)'),
            subtitle: const Text(
              'These are shared across sections and '
              'are not counted as section-specific assessments. '
              'Manage them through Course Tools.',
            ),
          ),
        ),
      ],
    ],
  );

  Widget _gradesTab(_SectionViewData data) {
    final titles = <String, String>{
      for (final assessment in data.assessments)
        _text(assessment['id']): _text(assessment['title']),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${data.submissions.length} section-assessment submission(s)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (data.submissions.isEmpty)
          _empty(
            'No submissions for section-assigned assessments yet. '
            'Course-wide assessment submissions are managed separately.',
          )
        else
          ...data.submissions.map((submission) {
            final assessmentId = _text(submission['assessmentId']);
            final score = submission['score'];
            final status = _text(submission['status']);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.grade_outlined, color: teal),
                title: Text(titles[assessmentId] ?? 'Assessment'),
                subtitle: Text(
                  'Student: '
                  '${_text(submission['studentName']).isEmpty ? _text(submission['studentId']) : _text(submission['studentName'])}'
                  '\nStatus: $status'
                  '${score is num ? '\nScore: $score' : ''}',
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Section Details'),
        backgroundColor: background,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_SectionViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to load section: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(data.section['name']),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Identifier: ${_text(data.section['identifier'])}'),
                    const SizedBox(height: 8),
                    const Text('Class Code'),
                    SelectableText(
                      _text(data.section['classCode']),
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                    Text('Status: ${_text(data.section['status'])}'),
                  ],
                ),
              ),
              const Material(
                color: Colors.white,
                child: TabBar(
                  isScrollable: true,
                  labelColor: teal,
                  tabs: [
                    Tab(text: 'Students'),
                    Tab(text: 'Modules'),
                    Tab(text: 'Assessments'),
                    Tab(text: 'Grades'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _studentsTab(data),
                    _modulesTab(data),
                    _assessmentsTab(data),
                    _gradesTab(data),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
