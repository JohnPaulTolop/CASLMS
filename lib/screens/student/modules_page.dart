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
  static const Color primaryBlue = Color(0xFF1769FF);

  static const Color background = Color(0xFFF7F9FC);

  static const Color darkText = Color(0xFF10182F);

  static const Color greyText = Color(0xFF68738A);

  static const Color borderColor = Color(0xFFE6EAF0);

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Learning',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: darkText,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Courses and modules',
              style: TextStyle(
                fontSize: 10.5,
                color: greyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              onPressed: _loadCourses,
              tooltip: 'Refresh progress',
              icon: const Icon(
                Icons.refresh_rounded,
                color: darkText,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryBlue));
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadCourses,
        color: primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(30),
          children: [
            const SizedBox(height: 100),
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: greyText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton(
                onPressed: _loadCourses,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: primaryBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        children: [
          _buildOverviewBanner(),

          const SizedBox(height: 20),

          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by course, code, or instructor',
              prefixIcon: const Icon(Icons.search_rounded, color: primaryBlue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Enrolled Courses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_courses.length} ${_courses.length == 1 ? 'Subject' : 'Subjects'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_courses.isEmpty)
            _buildEmptyState()
          else if (_filteredCourses.isEmpty)
            _buildNoSearchResults()
          else
            _buildCourseGrid(),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner() {
    final int percentage = (_overallProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1769FF), Color(0xFF5B8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -52,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Learning progress',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_completedModuleCount of $_totalModuleCount modules completed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _overallProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_courses.length} ${_courses.length == 1 ? 'active course' : 'active courses'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 760 ? 2 : 1;
        const double spacing = 14;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _filteredCourses
              .map(
                (course) =>
                    SizedBox(width: width, child: _buildCourseCard(course)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.school_outlined, size: 46, color: primaryBlue),
          SizedBox(height: 12),
          Text(
            'No enrolled courses yet',
            style: TextStyle(
              color: darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Open Course Invitations on the Home page and accept an invitation from your instructor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: greyText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: const Center(
        child: Text(
          'No matching courses found.',
          style: TextStyle(color: greyText, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final String code = (course['code'] ?? '').toString();

    final String title = (course['title'] ?? 'Course').toString();

    final String instructor = (course['instructorName'] ?? 'Instructor')
        .toString();

    final int totalModules = (course['totalModules'] as num?)?.toInt() ?? 0;

    final int completedModules =
        (course['completedModules'] as num?)?.toInt() ?? 0;

    final double progress =
        ((course['moduleProgress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);

    final bool completed = totalModules > 0 && completedModules >= totalModules;
    final Color progressColor = completed
        ? const Color(0xFF25A55F)
        : primaryBlue;

    return InkWell(
      onTap: () {
        _openCourse(course);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: progressColor.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: progressColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (code.isNotEmpty)
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 11,
                            color: primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: darkText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instructor,
                        style: const TextStyle(color: greyText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: progressColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                const Text(
                  'Module Progress',
                  style: TextStyle(
                    color: greyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  completed ? 'Completed' : '$completedModules / $totalModules',
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFECEFF4),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
