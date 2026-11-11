import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../shared/workspace_shell.dart';
import '../shared/workspace_widgets.dart';
import '../shared/learner_assistant_page.dart';
import '../shared/live_classes_page.dart';
import '../../services/assessment_submission_service.dart';
import '../../services/course_content_paths.dart';
import '../../services/enrollment_service.dart';
import '../../services/progress_service.dart';
import '../../services/section_audience_service.dart';
import '../../services/learning_material_service.dart';
import '../../services/student_roster_service.dart';
import '../../services/student_assessment_query_service.dart';
import 'student_ai_quiz_page.dart';
import '../shared/course_banner.dart';
import 'student_assessment_submission_page.dart';

class StudentCourseModulesScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String instructorName;
  final String initialModuleId;
  final String initialAssessmentId;
  final String initialResourceId;
  final int initialView;

  const StudentCourseModulesScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.instructorName,
    this.initialModuleId = '',
    this.initialAssessmentId = '',
    this.initialResourceId = '',
    this.initialView = 0,
  });

  @override
  State<StudentCourseModulesScreen> createState() =>
      _StudentCourseModulesScreenState();
}

class _StudentCourseModulesScreenState
    extends State<StudentCourseModulesScreen> {
  int _viewDirection = 1;
  double _swipeDistance = 0;
  Color get primaryBlue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get darkText => AppColors.resolve(context, AppColors.darkText);
  Color get secondaryText =>
      AppColors.resolve(context, AppColors.secondaryText);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AssessmentSubmissionService _submissionService =
      AssessmentSubmissionService();
  final EnrollmentService _enrollmentService = EnrollmentService();
  final ProgressService _progressService = ProgressService();
  final LearningMaterialService _materialService = LearningMaterialService();
  final StudentAssessmentQueryService _assessmentQuery =
      StudentAssessmentQueryService();
  StreamSubscription<List<Map<String, dynamic>>>? _courseColorsSubscription;
  Color _courseColor = AppColors.primaryBlue;

  bool _isLoading = true;
  String? _errorMessage;
  List<CourseModule> _modules = [];
  Map<String, Map<String, dynamic>> _modulesProgress = {};
  final Set<int> _expandedModuleIndices = {};
  int _selectedView = 0;
  String _activityFilter = 'All';

  void _openAssistant([String? topic]) {
    final subject = topic ?? widget.courseTitle;
    final prompt =
        'Help me understand "$subject" in ${widget.courseTitle} (${widget.courseCode}). '
        'Explain the key ideas and guide me through a practice example.';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LearnerAssistantScreen(
          role: 'student',
          showBackButton: true,
          initialCourseId: widget.courseId,
          initialPrompt: prompt.length > 1400
              ? prompt.substring(0, 1400)
              : prompt,
        ),
      ),
    );
  }

  List<Map<String, dynamic>>? _students;
  bool _rosterLoading = false;
  String? _rosterError;
  String _rosterSearch = '';

  @override
  void initState() {
    super.initState();
    _selectedView = widget.initialView.clamp(0, 3);
    _courseColorsSubscription = _enrollmentService.watchMyActiveCourses().listen(
      (courses) {
        final index = courses.indexWhere(
          (course) => (course['courseId'] ?? course['id']) == widget.courseId,
        );
        if (!mounted || index < 0) return;
        final color = courseSummary(courses[index], index).color;
        if (color != _courseColor) setState(() => _courseColor = color);
      },
      // Keep the last cover color; course access and loading errors are handled
      // independently by _loadCourseContent.
      onError: (Object error) {},
    );
    _loadCourseContent();
    if (_selectedView == 3) _loadRoster();
  }

  @override
  void dispose() {
    _courseColorsSubscription?.cancel();
    super.dispose();
  }

  void _selectView(int index) {
    index = index.clamp(0, 3);
    if (_selectedView == index) return;
    setState(() {
      _viewDirection = index > _selectedView ? 1 : -1;
      _selectedView = index;
    });
    if (index == 3 && _students == null && !_rosterLoading) _loadRoster();
  }

  Future<void> _loadRoster() async {
    if (_rosterLoading) return;
    setState(() {
      _rosterLoading = true;
      _rosterError = null;
    });
    try {
      final students = await StudentRosterService().load(widget.courseId);
      if (mounted) setState(() => _students = students);
    } catch (_) {
      if (mounted) {
        setState(
          () => _rosterError =
              'Unable to load classmates. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _rosterLoading = false);
    }
  }

  Widget _buildStudentsTab() {
    final students = (_students ?? [])
        .where(
          (student) =>
              student['name'].toString().toLowerCase().contains(_rosterSearch),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _students == null
                    ? 'Classmates in your section'
                    : '${_students!.length} students in your section',
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Refresh roster',
              onPressed: _rosterLoading ? null : _loadRoster,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) =>
              setState(() => _rosterSearch = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search classmates',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (_rosterLoading)
          const WorkspaceLoadingState(label: 'Loading classmates…')
        else if (_rosterError != null)
          WorkspaceErrorState(message: _rosterError!, onRetry: _loadRoster)
        else if (students.isEmpty)
          WorkspaceEmptyState(
            icon: Icons.people_outline_rounded,
            title: _rosterSearch.isEmpty
                ? 'No students yet'
                : 'No matching classmates',
            message: _rosterSearch.isEmpty
                ? 'Students will appear when they join your section.'
                : 'Try a different name.',
          )
        else
          WorkspaceSurface(
            child: Column(
              children: [
                for (final student in students)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.resolve(
                        context,
                        AppColors.blueTint,
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: primaryBlue,
                      ),
                    ),
                    title: Text(student['name'].toString()),
                    trailing: student['isCurrentStudent'] == true
                        ? Text(
                            'You',
                            style: TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _loadCourseContent() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw EnrollmentServiceException(
          'Please sign in again to load this course.',
        );
      }

      final enrolled = await _enrollmentService.isEnrolled(
        courseId: widget.courseId,
      );
      if (!enrolled) {
        throw EnrollmentServiceException(
          'You are not enrolled in this course.',
        );
      }

      final enrollmentData = await SectionAudienceService(
        firestore: _firestore,
      ).requireActiveEnrollment(courseId: widget.courseId, studentId: user.uid);
      final sectionId = (enrollmentData['sectionId'] ?? '').toString();

      final modulesSnapshot =
          await CourseContentPaths.modules(_firestore, widget.courseId)
              .where('courseId', isEqualTo: widget.courseId)
              .where('status', isEqualTo: 'published')
              .where(
                'sectionIds',
                arrayContainsAny: <String>[
                  SectionAudienceService.allSections,
                  sectionId,
                ],
              )
              .get();

      final assessmentDocuments = await _assessmentQuery.getVisibleAssessments(
        courseId: widget.courseId,
      );

      final assessmentsByModule = <String, List<Map<String, dynamic>>>{};
      for (final assessmentDoc in assessmentDocuments) {
        final data = assessmentDoc.data();
        final moduleId = (data['moduleId'] ?? '').toString();
        if (moduleId.isEmpty) continue;
        assessmentsByModule.putIfAbsent(moduleId, () => []).add({
          'id': assessmentDoc.id,
          ...data,
        });
      }

      if (!mounted) return;

      final List<CourseModule> loadedModules = [];
      for (final moduleDoc in modulesSnapshot.docs) {
        final moduleData = moduleDoc.data();
        final status = (moduleData['status'] ?? '').toString().toLowerCase();
        if (status != 'published') continue;

        final resources =
            (await _materialService.getModuleMaterials(
              courseId: widget.courseId,
              moduleId: moduleDoc.id,
            )).where((resource) {
              return SectionAudienceService.studentCanAccess(
                enrollment: enrollmentData,
                module: {...moduleData, 'id': moduleDoc.id},
                child: resource,
              );
            }).toList();

        final assessments = List<Map<String, dynamic>>.from(
          assessmentsByModule[moduleDoc.id] ?? const <Map<String, dynamic>>[],
        );

        loadedModules.add(
          CourseModule(
            id: moduleDoc.id,
            title: moduleData['title'] ?? 'Module',
            description: moduleData['description'] ?? '',
            order: (moduleData['order'] ?? 0).toInt(),
            resources: resources,
            assessments: assessments,
          ),
        );
      }

      loadedModules.sort((a, b) => a.order.compareTo(b.order));

      final submissions = await _submissionService.getMyCourseSubmissions(
        courseId: widget.courseId,
      );
      final submissionsByAssessment = <String, Map<String, dynamic>>{};
      for (final submission in submissions) {
        final assessmentId = (submission['assessmentId'] ?? '').toString();
        if (assessmentId.isNotEmpty) {
          submissionsByAssessment[assessmentId] = submission;
        }
      }
      for (final module in loadedModules) {
        for (final assessment in module.assessments) {
          final assessmentId = (assessment['id'] ?? '').toString();
          final submission = submissionsByAssessment[assessmentId];
          if (submission != null) {
            assessment['studentSubmission'] = submission;
          }
        }
      }

      final progressData = await _progressService.getCourseModuleProgress(
        courseId: widget.courseId,
      );

      if (!mounted) return;

      final focusedModuleIndex = widget.initialModuleId.isEmpty
          ? -1
          : loadedModules.indexWhere(
              (module) => module.id == widget.initialModuleId,
            );
      if (focusedModuleIndex >= 0) {
        _expandedModuleIndices.add(focusedModuleIndex);
      }

      setState(() {
        _modules = loadedModules;
        _modulesProgress = {
          for (final module in (progressData['modules'] as List? ?? const []))
            if (module is Map)
              module['moduleId'].toString(): Map<String, dynamic>.from(module),
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load course: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleModuleExpanded(int index) {
    setState(() {
      if (_expandedModuleIndices.contains(index)) {
        _expandedModuleIndices.remove(index);
      } else {
        _expandedModuleIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : _errorMessage != null
          ? _buildErrorView()
          : _buildMainView(),
    );
  }

  Widget _buildMainView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = workspaceInset(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: _loadCourseContent,
          color: primaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    constraints.maxWidth < 700 ? 12 : 20,
                    inset,
                    44,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (constraints.maxWidth >= 700) ...[
                        _buildCourseToolbar(),
                        const SizedBox(height: 4),
                      ],
                      _buildCourseHeader(),
                      const SizedBox(height: 20),
                      _buildWorkspaceTabs(),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onHorizontalDragStart: (_) => _swipeDistance = 0,
                        onHorizontalDragUpdate: (details) =>
                            _swipeDistance += details.delta.dx,
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (_swipeDistance.abs() < 48 &&
                              velocity.abs() < 250) {
                            return;
                          }
                          final delta = velocity.abs() >= 250
                              ? velocity
                              : _swipeDistance;
                          _selectView(_selectedView + (delta < 0 ? 1 : -1));
                        },
                        child: ClipRect(
                          child: AnimatedSize(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeInOutCubic,
                              switchOutCurve: Curves.easeInOutCubic,
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  ...previous.map(
                                    (child) => IgnorePointer(
                                      child: ExcludeSemantics(child: child),
                                    ),
                                  ),
                                  ?current,
                                ],
                              ),
                              transitionBuilder: (child, animation) {
                                final incoming =
                                    child.key == ValueKey(_selectedView);
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: Offset(
                                      (incoming ? 1 : -1) *
                                          _viewDirection.toDouble(),
                                      0,
                                    ),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                              child: Column(
                                key: ValueKey(_selectedView),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_selectedView == 0) _buildContentTab(),
                                  if (_selectedView == 1) _buildActivitiesTab(),
                                  if (_selectedView == 2) _buildGradesTab(),
                                  if (_selectedView == 3) _buildStudentsTab(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourseToolbar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
        color: secondaryText,
        padding: EdgeInsets.zero,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
      IconButton(
        tooltip: 'Refresh course content',
        onPressed: _loadCourseContent,
        icon: const Icon(Icons.refresh_rounded),
        color: secondaryText,
      ),
    ],
  );

  void _openLiveClassroom() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LiveClassesScreen(courseId: widget.courseId),
    ),
  );

  Widget _buildCourseHeader() {
    return CourseBanner(
      color: _courseColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: WorkspaceEyebrow('COURSE LEARNING WORKSPACE'),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Live classroom',
                onPressed: _openLiveClassroom,
                style: IconButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  Icons.video_call_outlined,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
          WorkspaceHeading(
            showEyebrow: false,
            eyebrow: 'COURSE LEARNING WORKSPACE',
            title: widget.courseTitle,
            subtitle: [
              widget.courseCode,
              if (widget.instructorName.trim().isNotEmpty)
                'Instructor: ${widget.instructorName}',
            ].where((part) => part.trim().isNotEmpty).join(' • '),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceTabs() {
    const labels = ['Content', 'Activities', 'Grades', 'Students'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.resolve(context, Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(
                2 * _selectedView / (labels.length - 1) - 1,
                0,
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.resolve(context, AppColors.blueTint),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: _selectedView == index,
                    label: labels[index],
                    hint: _selectedView == index ? 'Selected tab' : 'Open tab',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _selectView(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedView == index
                                ? primaryBlue
                                : secondaryText,
                            fontSize: 12,
                            fontWeight: _selectedView == index
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _allAssessments() {
    final result = <Map<String, dynamic>>[];
    for (final module in _modules) {
      for (final assessment in module.assessments) {
        result.add({
          ...assessment,
          '_moduleTitle': module.title,
          '_moduleOrder': module.order,
        });
      }
    }
    result.sort((a, b) {
      final aFocused = a['id'] == widget.initialAssessmentId;
      final bFocused = b['id'] == widget.initialAssessmentId;
      if (aFocused != bFocused) return aFocused ? -1 : 1;
      return _compareContentItems(a, b);
    });
    return result;
  }

  String _activityState(Map<String, dynamic> assessment) {
    final submission = assessment['studentSubmission'] is Map
        ? Map<String, dynamic>.from(assessment['studentSubmission'] as Map)
        : null;
    final status = (submission?['status'] ?? '').toString().toLowerCase();
    if (status == 'graded' || submission?['score'] is num) return 'Graded';
    final due = _assessmentDueDate(assessment['dueAt']);
    if (status == 'submitted') return 'Submitted';
    if ((assessment['status'] ?? '').toString().toLowerCase() == 'closed') {
      return 'Closed';
    }
    if (due != null && DateTime.now().isAfter(due)) return 'Overdue';
    return 'Upcoming';
  }

  Widget _buildActivitiesTab() {
    final activities = _allAssessments()
        .where(
          (assessment) =>
              _activityFilter == 'All' ||
              _activityState(assessment) == _activityFilter,
        )
        .toList();
    const filters = [
      'All',
      'Upcoming',
      'Submitted',
      'Graded',
      'Overdue',
      'Closed',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in filters)
              ChoiceChip(
                label: Text(filter),
                selected: _activityFilter == filter,
                onSelected: (_) => setState(() => _activityFilter = filter),
                selectedColor: AppColors.resolve(context, AppColors.blueTint),
                labelStyle: TextStyle(
                  color: _activityFilter == filter
                      ? primaryBlue
                      : secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (activities.isEmpty)
          _buildEmptyState(
            'No matching activities',
            'Activities for this course will appear here.',
          )
        else
          for (final assessment in activities) ...[
            _buildActivitySummary(assessment),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildActivitySummary(Map<String, dynamic> assessment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(
            (assessment['_moduleTitle'] ?? 'Course activity').toString(),
            style: TextStyle(
              color: secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
            ),
          ),
        ),
        _buildAssessmentCard(assessment),
      ],
    );
  }

  Widget _buildGradesTab() {
    final graded = _allAssessments().where((assessment) {
      final submission = assessment['studentSubmission'];
      if (submission is! Map) return false;
      final status = (submission['status'] ?? '').toString().toLowerCase();
      return status == 'graded' || submission['score'] is num;
    }).toList();
    final earned = graded.fold<double>(0, (total, assessment) {
      final submission = assessment['studentSubmission'];
      return total +
          ((submission is Map && submission['score'] is num)
              ? (submission['score'] as num).toDouble()
              : 0);
    });
    final possible = graded.fold<double>(0, (total, assessment) {
      final submission = assessment['studentSubmission'];
      final value = submission is Map && submission['totalPoints'] is num
          ? submission['totalPoints']
          : assessment['totalPoints'];
      return total + (value is num ? value.toDouble() : 0);
    });
    final percent = possible > 0 ? earned / possible * 100 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.resolve(context, Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(child: _buildGradeStat('Graded', '${graded.length}')),
              Expanded(
                child: _buildGradeStat(
                  'Earned',
                  possible > 0 ? _formatNumber(earned) : '—',
                ),
              ),
              Expanded(
                child: _buildGradeStat(
                  'Overall',
                  percent == null ? '—' : '${percent.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (graded.isEmpty)
          _buildEmptyState(
            'No grades posted yet',
            'Your graded course activities will appear here.',
          )
        else
          for (final assessment in graded) ...[
            _buildGradeRow(assessment),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildGradeStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: secondaryText, fontSize: 10)),
      ],
    );
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  Widget _buildGradeRow(Map<String, dynamic> assessment) {
    final submission = Map<String, dynamic>.from(
      assessment['studentSubmission'] as Map,
    );
    final score = submission['score'];
    final total = submission['totalPoints'] ?? assessment['totalPoints'];
    final feedback = (submission['feedback'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.resolve(context, Colors.white),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, color: green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (assessment['title'] ?? 'Assessment').toString(),
                  style: TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${assessment['_moduleTitle'] ?? 'Course activity'} · ${_contentTypeLabel(assessment)}',
                  style: TextStyle(color: secondaryText, fontSize: 10),
                ),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    feedback,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${score ?? '—'} / ${total ?? '—'}',
            style: TextStyle(
              color: green,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    if (_modules.isEmpty) {
      return _buildEmptyState(
        'No modules available',
        'Course content will appear here.',
      );
    }

    // The page already applies the responsive workspace inset. Do not add
    // another 36px horizontal inset here; it makes mobile cards too narrow.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _modules.asMap().entries)
          _buildModuleCard(
            entry.value,
            entry.key,
            _expandedModuleIndices.contains(entry.key),
          ),
      ],
    );
  }

  Widget _buildModuleCard(CourseModule module, int index, bool isExpanded) {
    final totalItems = module.resources.length + module.assessments.length;
    final progress = _modulesProgress[module.id];
    final isCompleted = progress?['completed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.resolve(context, Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: Semantics(
              container: true,
              button: true,
              expanded: isExpanded,
              label: '${module.title}, Module ${index + 1}',
              hint: isExpanded ? 'Collapse module' : 'Expand module',
              child: InkWell(
                onTap: () => _toggleModuleExpanded(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Module ${index + 1}',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              module.title,
                              style: TextStyle(
                                color: darkText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (module.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                module.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.pending_outlined,
                            color: isCompleted ? green : secondaryText,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalItems items',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: isExpanded ? 1 : 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: value,
                child: child,
              ),
            ),
            child: ExcludeFocus(
              excluding: !isExpanded,
              child: ExcludeSemantics(
                excluding: !isExpanded,
                child: IgnorePointer(
                  ignoring: !isExpanded,
                  child: Column(
                    children: [
                      Divider(height: 1, color: borderColor),
                      _buildModuleContent(module),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleContent(CourseModule module) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (module.resources.isEmpty && module.assessments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No learning items have been added to this module yet.',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            ),
          if (module.resources.isNotEmpty) ...[
            _buildSectionHeader(
              '📚 Learning Materials',
              module.resources.length,
            ),
            const SizedBox(height: 12),
            ..._buildResourceItems(module.resources),
            if (module.assessments.isNotEmpty) const SizedBox(height: 20),
          ],
          if (module.assessments.isNotEmpty) ...[
            _buildSectionHeader(
              '📋 Assessments & Activities',
              module.assessments.length,
            ),
            const SizedBox(height: 12),
            ..._buildAssessmentItems(module.assessments),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResourceItems(List<Map<String, dynamic>> resources) {
    final ordered = List<Map<String, dynamic>>.from(resources)
      ..sort(_compareContentItems);
    return ordered
        .map(
          (resource) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildResourceCard(resource),
          ),
        )
        .toList();
  }

  int _compareContentItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aOrder = a['order'];
    final bOrder = b['order'];

    if (aOrder is num && bOrder is num) {
      return aOrder.compareTo(bOrder);
    }
    if (aOrder is num) return -1;
    if (bOrder is num) return 1;

    final aDate = _contentDate(a);
    final bDate = _contentDate(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  }

  DateTime? _contentDate(Map<String, dynamic> item) {
    final value =
        item['createdAt'] ?? item['uploadedAt'] ?? item['publishedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateLabel(Map<String, dynamic> item) {
    final date = _contentDate(item);
    if (date == null) return 'Date not available';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'Uploaded $month/$day/${local.year}';
  }

  String _contentDescription(Map<String, dynamic> item) {
    return (item['description'] ?? item['instructions'] ?? '')
        .toString()
        .trim();
  }

  String _contentTypeLabel(Map<String, dynamic> item) {
    final delivery = (item['deliveryType'] ?? '').toString().toLowerCase();
    final type = (item['resourceType'] ?? item['assessmentType'] ?? '')
        .toString();
    if (delivery == 'external_link') {
      return type.isEmpty ? 'External link' : type;
    }
    if (delivery == 'uploaded_file') {
      return type.isEmpty ? 'File' : type;
    }
    return type.isEmpty ? 'Learning item' : type;
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleResourceTap(resource),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildResourceIcon(resource['deliveryType'] ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resource['title'] ?? 'Untitled Resource',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildTypeBadge(_contentTypeLabel(resource)),
                        ],
                      ),
                      if ((resource['fileName'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          resource['fileName'] ?? '',
                          style: TextStyle(color: secondaryText, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _dateLabel(resource),
                        style: TextStyle(color: secondaryText, fontSize: 10),
                      ),
                      if (_contentDescription(resource).isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _contentDescription(resource),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ask AI about this material',
                  onPressed: () => _openAssistant(
                    (resource['title'] ?? 'this learning material').toString(),
                  ),
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                ),
                Icon(Icons.chevron_right, color: secondaryText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceIcon(String deliveryType) {
    final isExternal = deliveryType.toLowerCase() == 'external_link';
    final icon = isExternal ? Icons.link : Icons.file_present;
    final color = isExternal
        ? const Color(0xFF06b6d4)
        : const Color(0xFF6366f1);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.resolve(context, AppColors.blueTint),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primaryBlue,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Widget> _buildAssessmentItems(List<Map<String, dynamic>> assessments) {
    final ordered = List<Map<String, dynamic>>.from(assessments)
      ..sort(_compareContentItems);
    return ordered
        .map(
          (assessment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildAssessmentCard(assessment),
          ),
        )
        .toList();
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final statusColor = _getStatusColor(assessment['status'] ?? '');
    final totalPoints = assessment['totalPoints'];
    final points = totalPoints is num
        ? totalPoints.toInt()
        : int.tryParse(totalPoints?.toString() ?? '');
    final submission = assessment['studentSubmission'] is Map
        ? Map<String, dynamic>.from(assessment['studentSubmission'] as Map)
        : null;
    final submissionStatus = (submission?['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final dueDate = _assessmentDueDate(assessment['dueAt']);
    final isGraded =
        submissionStatus == 'graded' ||
        (submission?['score'] is num && submissionStatus != 'not_complied');
    final isPastDue = dueDate != null && DateTime.now().isAfter(dueDate);
    final isLocked =
        isGraded ||
        isPastDue ||
        submissionStatus == 'submitted' ||
        (assessment['status'] ?? '').toString().toLowerCase() == 'closed';

    return Container(
      decoration: BoxDecoration(
        color: assessment['id'] == widget.initialAssessmentId
            ? AppColors.blueTint
            : background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked ? borderColor.withValues(alpha: 0.75) : borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => isLocked
              ? _showAssessmentDetails(assessment)
              : _handleAssessmentTap(assessment),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAssessmentIcon(assessment['assessmentType'] ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              assessment['title'] ?? 'Untitled Assessment',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildTypeBadge(_contentTypeLabel(assessment)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _activityState(assessment).toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (dueDate != null)
                            _buildAssessmentMeta(
                              icon: Icons.schedule_rounded,
                              label: 'Due ${_formatAssessmentDate(dueDate)}',
                              color:
                                  isPastDue &&
                                      submissionStatus != 'submitted' &&
                                      !isGraded
                                  ? AppColors.error
                                  : secondaryText,
                            )
                          else
                            Text(
                              _dateLabel(assessment),
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          if (points != null && points > 0)
                            Text(
                              '$points pts',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      if (isGraded) ...[
                        const SizedBox(height: 7),
                        _buildAssessmentMeta(
                          icon: Icons.verified_rounded,
                          label:
                              'Graded: ${submission?['score']} / ${submission?['totalPoints'] ?? totalPoints ?? points ?? '—'}',
                          color: AppColors.resolve(context, AppColors.green),
                          strong: true,
                        ),
                      ] else if (isPastDue &&
                          submissionStatus != 'submitted') ...[
                        const SizedBox(height: 7),
                        _buildAssessmentMeta(
                          icon: Icons.event_busy_rounded,
                          label: 'Deadline passed',
                          color: AppColors.resolve(context, AppColors.error),
                          strong: true,
                        ),
                      ] else if (submissionStatus == 'submitted') ...[
                        const SizedBox(height: 7),
                        _buildAssessmentMeta(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Submitted · awaiting grade',
                          color: primaryBlue,
                        ),
                      ],
                      if (_contentDescription(assessment).isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _contentDescription(assessment),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ask AI about this activity',
                  onPressed: () => _openAssistant(
                    (assessment['title'] ?? 'this activity').toString(),
                  ),
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                ),
                Icon(
                  isLocked ? Icons.info_outline_rounded : Icons.chevron_right,
                  color: isLocked
                      ? secondaryText.withValues(alpha: 0.7)
                      : secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentMeta({
    required IconData icon,
    required String label,
    required Color color,
    bool strong = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  DateTime? _assessmentDueDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatAssessmentDate(DateTime value) {
    final date = value.toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${date.year} · $hour:$minute $meridiem';
  }

  Widget _buildAssessmentIcon(String assessmentType) {
    final type = assessmentType.toLowerCase();
    IconData icon = Icons.check_circle;
    Color color = secondaryText;

    if (type == 'quiz') {
      icon = Icons.quiz;
      color = const Color(0xFF8b5cf6);
    } else if (type == 'assignment' || type == 'activity') {
      icon = Icons.assignment;
      color = const Color(0xFFec4899);
    } else if (type == 'exam') {
      icon = Icons.assignment_turned_in;
      color = const Color(0xFFf59e0b);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'draft') return Colors.grey;
    if (s == 'published') return primaryBlue;
    if (s == 'closed') return Colors.red;
    if (s == 'graded') return green;
    return secondaryText;
  }

  Future<void> _handleResourceTap(Map<String, dynamic> resource) async {
    final deliveryType = (resource['deliveryType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    try {
      Uri? uri;
      if (deliveryType == 'external_link') {
        final url = (resource['externalUrl'] ?? '').toString().trim();
        uri = Uri.tryParse(url);
      } else if (deliveryType == 'uploaded_file') {
        uri = await LearningMaterialService().createAuthorizedDownloadUri(
          (resource['id'] ?? resource['resourceId'] ?? '').toString(),
        );
      } else {
        final url = (resource['externalUrl'] ?? resource['fileUrl'] ?? '')
            .toString()
            .trim();
        uri = Uri.tryParse(url);
      }

      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException(
          'This learning item has no valid file or link URL.',
        );
      }

      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        throw Exception('The device could not open this learning item.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'Could not open ${resource['title'] ?? 'this learning item'}: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAssessmentDetails(Map<String, dynamic> assessment) async {
    final submission = assessment['studentSubmission'];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((assessment['title'] ?? 'Assessment details').toString()),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Status: ${_activityState(assessment)}'),
            if (_contentDescription(assessment).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_contentDescription(assessment)),
            ],
            if (submission is Map && submission['score'] is num) ...[
              const SizedBox(height: 12),
              Text(
                'Score: ${submission['score']} / ${submission['totalPoints'] ?? assessment['totalPoints'] ?? '—'}',
              ),
            ],
            if (submission is Map &&
                (submission['feedback'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Feedback: ${submission['feedback']}'),
            ],
            const SizedBox(height: 12),
            const Text('This assessment is available for review only.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAssessmentTap(Map<String, dynamic> assessment) async {
    final assessmentType = (assessment['assessmentType'] ?? '')
        .toString()
        .toLowerCase();
    final assessmentId = assessment['id'] ?? '';
    final moduleId = assessment['moduleId'] ?? '';

    if (assessmentType == 'quiz') {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (c) => StudentAiQuizScreen(
            assessmentId: assessmentId,
            courseId: widget.courseId,
            moduleId: moduleId,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (c) =>
              StudentAssessmentSubmissionScreen(assessment: assessment),
        ),
      );
    }
    if (mounted) await _loadCourseContent();
  }

  Widget _buildEmptyState(String title, String message) {
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.resolve(context, Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, color: secondaryText, size: 40),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 46),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadCourseContent,
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final String description;
  final int order;
  final List<Map<String, dynamic>> resources;
  final List<Map<String, dynamic>> assessments;

  CourseModule({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.resources,
    required this.assessments,
  });
}
