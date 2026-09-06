import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/progress_service.dart';

import 'student_course_modules_page.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() =>
      _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color darkText =
      Color(0xFF10182F);

  static const Color greyText =
      Color(0xFF68738A);

  static const Color borderColor =
      Color(0xFFE6EAF0);

  final EnrollmentService _enrollmentService =
      EnrollmentService();

  final ProgressService _progressService =
      ProgressService();

  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();

    _loadCourses();
  }

  Future<void> _loadCourses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> courses =
          await _enrollmentService
              .getMyActiveCourses();

      final List<Map<String, dynamic>>
          enrichedCourses = [];

      for (final Map<String, dynamic> course
          in courses) {
        final String courseId =
            (course['courseId'] ??
                    course['id'] ??
                    '')
                .toString()
                .trim();

        if (courseId.isEmpty) {
          continue;
        }

        try {
          final Map<String, dynamic> progress =
              await _progressService
                  .getCourseModuleProgress(
            courseId: courseId,
          );

          enrichedCourses.add({
            ...course,
            'totalModules':
                (progress['totalModules']
                        as num?)
                    ?.toInt() ??
                    0,
            'completedModules':
                (progress['completedModules']
                        as num?)
                    ?.toInt() ??
                    0,
            'moduleProgress':
                (progress['progress']
                        as num?)
                    ?.toDouble() ??
                    0.0,
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

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = enrichedCourses;
        _isLoading = false;
      });
    } on EnrollmentServiceException catch (e) {
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
        _errorMessage =
            'Unable to load enrolled courses.';
      });
    }
  }

  List<Map<String, dynamic>>
      get _filteredCourses {
    final String query =
        _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _courses;
    }

    return _courses.where(
      (course) {
        final String code =
            (course['code'] ?? '')
                .toString()
                .toLowerCase();

        final String title =
            (course['title'] ?? '')
                .toString()
                .toLowerCase();

        final String instructor =
            (course['instructorName'] ?? '')
                .toString()
                .toLowerCase();

        return code.contains(query) ||
            title.contains(query) ||
            instructor.contains(query);
      },
    ).toList();
  }

  Future<void> _openCourse(
    Map<String, dynamic> course,
  ) async {
    final String courseId =
        (course['courseId'] ??
                course['id'] ??
                '')
            .toString();

    if (courseId.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentCourseModulesScreen(
          courseId: courseId,
          courseCode:
              (course['code'] ?? '')
                  .toString(),
          courseTitle:
              (course['title'] ?? 'Course')
                  .toString(),
          instructorName:
              (course['instructorName'] ??
                      'Instructor')
                  .toString(),
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
        centerTitle: true,
        title: const Text(
          'My Modules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadCourses,
            icon: const Icon(
              Icons.refresh_rounded,
              color: darkText,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1200,
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryBlue,
        ),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadCourses,
        color: primaryBlue,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          24,
          16,
          24,
          30,
        ),
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search your courses...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: primaryBlue,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide:
                    const BorderSide(
                  color: borderColor,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide:
                    const BorderSide(
                  color: borderColor,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide:
                    const BorderSide(
                  color: primaryBlue,
                  width: 1.5,
                ),
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
                    fontWeight:
                        FontWeight.w800,
                    color: darkText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEAF2FF),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${_courses.length} ${_courses.length == 1 ? 'Subject' : 'Subjects'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: primaryBlue,
                    fontWeight:
                        FontWeight.w800,
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
            ..._filteredCourses.map(
              _buildCourseCard,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 46,
            color: primaryBlue,
          ),
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
            'Use Join Class on the Home page to enroll in a course.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: greyText,
              fontSize: 12,
            ),
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
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(color: borderColor),
      ),
      child: const Center(
        child: Text(
          'No matching courses found.',
          style: TextStyle(
            color: greyText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(
    Map<String, dynamic> course,
  ) {
    final String code =
        (course['code'] ?? '')
            .toString();

    final String title =
        (course['title'] ?? 'Course')
            .toString();

    final String instructor =
        (course['instructorName'] ??
                'Instructor')
            .toString();

    final int totalModules =
        (course['totalModules'] as num?)
                ?.toInt() ??
            0;

    final int completedModules =
        (course['completedModules']
                    as num?)
                ?.toInt() ??
            0;

    final double progress =
        ((course['moduleProgress']
                    as num?)
                ?.toDouble() ??
            0.0)
            .clamp(0.0, 1.0);

    return InkWell(
      onTap: () {
        _openCourse(course);
      },
      borderRadius:
          BorderRadius.circular(20),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border:
              Border.all(
            color: borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: 0.025),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                        const Color(
                      0xFFEAF2FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      if (code.isNotEmpty)
                        Text(
                          code,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color: primaryBlue,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 15,
                          color: darkText,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instructor,
                        style:
                            const TextStyle(
                          color: greyText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Color(0xFF9BA4B4),
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
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedModules / $totalModules',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(8),
              child:
                  LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor:
                    const Color(
                  0xFFECEFF4,
                ),
                valueColor:
                    const AlwaysStoppedAnimation<
                        Color>(
                  primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}