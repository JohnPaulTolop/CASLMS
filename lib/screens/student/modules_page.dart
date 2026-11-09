import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/progress_service.dart';

import 'student_course_modules_page.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final EnrollmentService _enrollmentService = EnrollmentService();

  final ProgressService _progressService = ProgressService();

  StreamSubscription<List<Map<String, dynamic>>>? _coursesSubscription;
  int _loadGeneration = 0;
  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  List<Map<String, dynamic>> _courses = [];

  int get _totalModuleCount => _courses.fold<int>(
    0,
    (total, course) => total + ((course['totalModules'] as num?)?.toInt() ?? 0),
  );

  int get _completedModuleCount => _courses.fold<int>(
    0,
    (total, course) =>
        total + ((course['completedModules'] as num?)?.toInt() ?? 0),
  );

  double get _overallProgress {
    final total = _totalModuleCount;
    return total == 0
        ? 0.0
        : (_completedModuleCount / total).clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();

    _coursesSubscription = _enrollmentService.watchMyActiveCourses().listen(
      (courses) {
        if (!mounted) return;
        final previous = {
          for (final course in _courses) course['courseId']: course,
        };
        setState(() {
          _courses = courses
              .map(
                (course) => <String, dynamic>{
                  ...?previous[course['courseId']],
                  ...course,
                },
              )
              .toList();
          _isLoading = false;
          _errorMessage = null;
        });
        _loadCourses(activeCourses: courses, showLoading: false);
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to sync enrolled courses. Please retry.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    _coursesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCourses({
    List<Map<String, dynamic>>? activeCourses,
    bool showLoading = true,
  }) async {
    final generation = ++_loadGeneration;
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> courses =
          activeCourses ?? await _enrollmentService.getMyActiveCourses();

      final List<Map<String, dynamic>> enrichedCourses = [];

      for (final Map<String, dynamic> course in courses) {
        final String courseId = (course['courseId'] ?? course['id'] ?? '')
            .toString()
            .trim();

        if (courseId.isEmpty) {
          continue;
        }

        try {
          final Map<String, dynamic> progress = await _progressService
              .getCourseModuleProgress(courseId: courseId);

          enrichedCourses.add({
            ...course,
            'totalModules': (progress['totalModules'] as num?)?.toInt() ?? 0,
            'completedModules':
                (progress['completedModules'] as num?)?.toInt() ?? 0,
            'moduleProgress': (progress['progress'] as num?)?.toDouble() ?? 0.0,
          });
        } catch (_) {
          enrichedCourses.add({
            ...course,
            'totalModules': 0,
            'completedModules': 0,
            'moduleProgress': 0.0,
          });
        }
      }

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _courses = enrichedCourses;
        _isLoading = false;
      });
    } on EnrollmentServiceException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load enrolled courses.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _courses;
    }

    return _courses.where((course) {
      final String code = (course['code'] ?? '').toString().toLowerCase();

      final String title = (course['title'] ?? '').toString().toLowerCase();

      final String instructor = (course['instructorName'] ?? '')
          .toString()
          .toLowerCase();

      return code.contains(query) ||
          title.contains(query) ||
          instructor.contains(query);
    }).toList();
  }

  Future<void> _openCourse(Map<String, dynamic> course) async {
    final String courseId = (course['courseId'] ?? course['id'] ?? '')
        .toString();

    if (courseId.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCourseModulesScreen(
          courseId: courseId,
          courseCode: (course['code'] ?? '').toString(),
          courseTitle: (course['title'] ?? 'Course').toString(),
          instructorName: (course['instructorName'] ?? 'Instructor').toString(),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadCourses();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inset = workspaceInset(box.maxWidth);
      final filteredCourses = _filteredCourses;
      final courseIndexById = {
        for (var index = 0; index < _courses.length; index++)
          (_courses[index]['courseId'] ?? _courses[index]['id']).toString():
              index,
      };
      return RefreshIndicator(
        onRefresh: _loadCourses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(inset, 0, inset, 28),
          children: [
            const WorkspaceHeading(
              showEyebrow: false,
              title: 'My courses',
              subtitle: 'Your courses and modules, in one place.',
              eyebrow: 'KEEP EXPLORING',
            ),
            const SizedBox(height: 28),
            WorkspaceSurface(
              color: AppColors.resolve(context, AppColors.blueTint),
              borderColor: AppColors.resolve(context, AppColors.blueTint),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learning progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_completedModuleCount of $_totalModuleCount modules completed',
                    style: TextStyle(
                      color: AppColors.resolve(
                        context,
                        AppColors.secondaryText,
                      ),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _overallProgress,
                          minHeight: AppTheme.progressBarHeight,
                          borderRadius: BorderRadius.circular(8),
                          semanticsLabel: 'Overall module progress',
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${(_overallProgress * 100).round()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search by course, code, or instructor',
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search courses',
              ),
            ),
            const SizedBox(height: 24),
            WorkspaceSectionHeading(
              title: 'Enrolled courses',
              subtitle: '${_courses.length} active courses',
              action: 'Refresh',
              onAction: _loadCourses,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const WorkspaceLoadingState(label: 'Loading your courses…')
            else if (_errorMessage != null)
              WorkspaceErrorState(
                message: 'Unable to load your courses. Check your connection and try again.',
                onRetry: _loadCourses,
              )
            else if (_courses.isEmpty)
              const WorkspaceEmptyState(
                icon: Icons.school_outlined,
                title: 'No enrolled courses yet',
                message: 'Open Course Invitations on the Overview page to join a course.',
              )
            else if (filteredCourses.isEmpty)
              const WorkspaceEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching courses',
                message: 'Try a different course, code, or instructor search.',
              )
            else
              LayoutBuilder(
                builder: (context, courseBox) {
                  const gap = 14.0;
                  final availableWidth = courseBox.maxWidth;
                  final columns = ((availableWidth + gap) / 332).floor().clamp(
                    1,
                    4,
                  );
                  final cardWidth =
                      (availableWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (
                        var index = 0;
                        index < filteredCourses.length;
                        index++
                      )
                        SizedBox(
                          width: cardWidth,
                          child: WorkspaceCourseCard(
                            course: courseSummary(
                              filteredCourses[index],
                              courseIndexById[(filteredCourses[index]['courseId'] ??
                                          filteredCourses[index]['id'])
                                      .toString()] ??
                                  0,
                              progress:
                                  (filteredCourses[index]['moduleProgress']
                                          as num?)
                                      ?.toDouble(),
                            ),
                            onTap: () => _openCourse(filteredCourses[index]),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}
