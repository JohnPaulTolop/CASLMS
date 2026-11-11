import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import '../../services/instructor_course_service.dart';
import '../../services/module_service.dart';
import '../../services/section_audience_service.dart';
import 'instructor_add_learning_material_page.dart';
import 'instructor_create_assessment_page.dart';
import 'instructor_module_builder_page.dart';
import 'instructor_task_widgets.dart';

enum InstructorCreateKind { module, assessment, material }

class InstructorQuickCreateScreen extends StatefulWidget {
  const InstructorQuickCreateScreen({
    super.key,
    required this.kind,
    this.loadCourses,
    this.loadSections,
    this.loadModules,
    this.currentUid,
    this.onReady,
  });
  final InstructorCreateKind kind;
  final Future<List<Map<String, dynamic>>> Function()? loadCourses;
  final Future<List<Map<String, dynamic>>> Function(String)? loadSections,
      loadModules;
  final String? Function()? currentUid;
  final void Function(String courseId, String? sectionId, String? moduleId)?
  onReady;
  @override
  State<InstructorQuickCreateScreen> createState() =>
      _InstructorQuickCreateState();
}

class _InstructorQuickCreateState extends State<InstructorQuickCreateScreen> {
  List<Map<String, dynamic>> _courses = [], _sections = [], _modules = [];
  String? _course, _section, _module, _error, _uid;
  bool _loading = true, _continuing = false;
  int _generation = 0;
  bool get _needsModule => widget.kind != InstructorCreateKind.module;
  String? get _currentUid =>
      widget.currentUid?.call() ??
      (widget.currentUid == null
          ? FirebaseAuth.instance.currentUser?.uid
          : null);
  Future<List<Map<String, dynamic>>> _getSections(String id) =>
      widget.loadSections?.call(id) ?? CourseSectionService().getSections(id);
  Future<List<Map<String, dynamic>>> _getModules(String id) =>
      widget.loadModules?.call(id) ??
      ModuleService().getCourseModules(courseId: id);
  List<Map<String, dynamic>> get _eligibleModules => _modules
      .where(
        (m) => SectionAudienceService.visibleInInstructorSection(m, _section),
      )
      .toList();
  String _id(Map<String, dynamic> row) =>
      (row['id'] ?? row['courseId'] ?? row['moduleId'] ?? '').toString();

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
    _uid = _currentUid;
    try {
      if (_uid == null) throw StateError('Please sign in again.');
      final courses =
          await (widget.loadCourses?.call() ??
              InstructorCourseService().getInstructorCourses());
      if (!mounted || _currentUid != _uid) return;
      setState(() {
        _courses = courses.where((c) => c['status'] == 'active').toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load courses. Please retry.';
        });
      }
    }
  }

  Future<void> _chooseCourse(String? id) async {
    final generation = ++_generation;
    setState(() {
      _course = id;
      _section = null;
      _module = null;
      _sections = [];
      _modules = [];
      _loading = true;
      _error = null;
    });
    try {
      if (id == null) return;
      final rows = await Future.wait([
        _getSections(id),
        if (_needsModule) _getModules(id),
      ]);
      if (!mounted || generation != _generation || _currentUid != _uid) return;
      setState(() {
        _sections = rows[0].where((r) => r['status'] == 'active').toList();
        _modules = _needsModule ? rows[1] : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Unable to load this course. Choose it again or retry.';
        });
      }
    }
  }

  Future<void> _continue() async {
    if (_course == null ||
        _section == null ||
        (_needsModule && _module == null) ||
        _continuing) {
      return;
    }
    setState(() {
      _continuing = true;
      _error = null;
    });
    final courseId = _course!, sectionId = _section!, moduleId = _module;
    try {
      if (_currentUid != _uid) throw StateError('Session changed');
      final fresh = await Future.wait([
        _getSections(courseId),
        if (_needsModule) _getModules(courseId),
      ]);
      if (!mounted || _currentUid != _uid) return;
      final sections = fresh[0].where((s) => s['status'] == 'active').toList();
      if (sections.isEmpty ||
          (sectionId.isNotEmpty && !sections.any((s) => _id(s) == sectionId))) {
        throw StateError('Section unavailable');
      }
      final course = _courses.firstWhere((c) => _id(c) == courseId);
      final module = _needsModule
          ? fresh[1].firstWhere(
              (m) =>
                  _id(m) == moduleId &&
                  SectionAudienceService.visibleInInstructorSection(
                    m,
                    sectionId,
                  ),
            )
          : null;
      if (widget.onReady != null) {
        widget.onReady!(
          courseId,
          sectionId.isEmpty ? null : sectionId,
          moduleId,
        );
        return;
      }
      final page = switch (widget.kind) {
        InstructorCreateKind.module => InstructorModuleBuilderScreen(
          courseId: courseId,
          courseCode: (course['code'] ?? '').toString(),
          courseTitle: (course['title'] ?? '').toString(),
          sections: sections,
          initialSectionId: sectionId,
          initialSectionIds: sectionId.isEmpty ? const ['*'] : [sectionId],
        ),
        InstructorCreateKind.material => InstructorAddLearningMaterialScreen(
          courseId: courseId,
          moduleId: moduleId!,
          moduleTitle: (module!['title'] ?? 'Module').toString(),
          sections: sections,
          moduleSectionIds: SectionAudienceService.stored(module),
          initialSectionId: sectionId,
        ),
        InstructorCreateKind.assessment => InstructorCreateAssessmentScreen(
          courseId: courseId,
          moduleId: moduleId!,
          courseCode: (course['code'] ?? '').toString(),
          courseTitle: (course['title'] ?? '').toString(),
          moduleTitle: (module!['title'] ?? 'Module').toString(),
          sections: sections,
          moduleSectionIds: SectionAudienceService.stored(module),
          initialSectionId: sectionId,
        ),
      };
      await Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The selected course, section, or module is no longer available. Please choose again.',
        );
      }
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InstructorTaskScaffold(
    title: 'Create ${widget.kind.name}',
    subtitle: 'Choose where this belongs, then continue to the editor.',
    busy: _continuing,
    body: ListView(
      padding: InstructorTaskScaffold.paddingOf(context),
      children: [
        InstructorFormSection(
          title: 'Location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('course-$_course'),
                initialValue: _course,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course'),
                items: [
                  for (final c in _courses)
                    DropdownMenuItem(
                      value: _id(c),
                      child: Text(
                        '${c['code'] ?? ''} • ${c['title'] ?? 'Course'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _loading || _continuing ? null : _chooseCourse,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Create an active course from the dashboard first.',
                  ),
                ),
              if (_course != null && !_loading) ...[
                const SizedBox(height: 20),
                if (_sections.isEmpty)
                  const Text(
                    'Add an active section in this course before creating content.',
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('section-$_course-$_section'),
                    initialValue: _section,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          _needsModule
                              ? 'Use module’s assigned sections'
                              : 'All active sections',
                        ),
                      ),
                      for (final s in _sections)
                        DropdownMenuItem(
                          value: _id(s),
                          child: Text(
                            (s['name'] ?? 'Section').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _continuing
                        ? null
                        : (value) => setState(() {
                            _section = value;
                            _module = null;
                          }),
                  ),
                if (_needsModule && _section != null) ...[
                  const SizedBox(height: 20),
                  if (_eligibleModules.isEmpty)
                    const Text(
                      'No modules are assigned here yet. Create a module from the dashboard first.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey('module-$_course-$_section'),
                      initialValue: _module,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Module'),
                      items: [
                        for (final m in _eligibleModules)
                          DropdownMenuItem(
                            value: _id(m),
                            child: Text(
                              (m['title'] ?? 'Module').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _continuing
                          ? null
                          : (value) => setState(() => _module = value),
                    ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'You can review the assigned sections in the editor before publishing.',
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          InstructorTaskNotice(text: _error!, error: true),
          TextButton(
            onPressed: _continuing
                ? null
                : (_course == null ? _load : () => _chooseCourse(_course)),
            child: const Text('Retry'),
          ),
        ],
      ],
    ),
    footer: InstructorTaskActions(
      children: [
        FilledButton(
          onPressed:
              _loading ||
                  _continuing ||
                  _course == null ||
                  _section == null ||
                  (_needsModule && _module == null)
              ? null
              : _continue,
          child: Text(_continuing ? 'Checking selection…' : 'Continue'),
        ),
      ],
    ),
  );
}
