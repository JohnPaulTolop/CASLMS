import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../shared/workspace_shell.dart';
import '../shared/workspace_widgets.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/progress_service.dart';
import 'student_progress_view.dart';
import 'student_course_modules_page.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  Color get primaryBlue => AppColors.resolve(context, AppColors.primaryBlue);

  Color get background => AppColors.resolve(context, AppColors.background);

  Color get textDark => AppColors.resolve(context, AppColors.darkText);

  // ============================================================
  // SERVICE
  // ============================================================

  final ProgressService _progressService = ProgressService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic> _learning = {};

  Map<String, dynamic> _academic = {};
  StreamSubscription<Map<String, dynamic>>? _progressChanges;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadData();
    _progressChanges = _progressService.watchStudentProgress().listen(
      (report) {
        if (mounted) {
          setState(() {
            _learning = report;
            _academic = report;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to update your grades. Please refresh.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _progressChanges?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> results = await Future.wait([
        _progressService.getOverallLearningProgress(),

        _progressService.getOverallAcademicPerformance(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _learning = results[0];

        _academic = results[1];

        _isLoading = false;
      });
    } on ProgressServiceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = 'Unable to load your progress.';
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: WorkspaceScrollingBody(
              header: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      workspaceInset(MediaQuery.sizeOf(context).width),
                      0,
                      workspaceInset(MediaQuery.sizeOf(context).width),
                      0,
                    ),
                    child: WorkspaceHeading(
                      showEyebrow: false,
                      inlineActions: true,
                      title: 'My progress',
                      subtitle: 'See how your learning and academic performance are building over time.',
                      eyebrow: 'YOUR LEARNING',
                      actions: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _isLoading ? null : _loadData,
                          icon: Icon(Icons.refresh_rounded, color: textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              body: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const WorkspaceLoadingState(label: 'Loading your progress…');
    }

    if (_errorMessage != null) {
      return WorkspaceErrorState(
        message: 'Unable to load your progress. Check your connection and try again.',
        onRetry: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          workspaceInset(MediaQuery.sizeOf(context).width),
          16,
          workspaceInset(MediaQuery.sizeOf(context).width),
          40,
        ),
        child: StudentProgressView(
          learning: _learning,
          academic: _academic,
          onCourse: (course) {
            final courseId = (course['courseId'] ?? course['id'] ?? '')
                .toString();
            if (courseId.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StudentCourseModulesScreen(
                  courseId: courseId,
                  courseCode: (course['code'] ?? '').toString(),
                  courseTitle: (course['title'] ?? 'Course').toString(),
                  instructorName: (course['instructorName'] ?? '').toString(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
