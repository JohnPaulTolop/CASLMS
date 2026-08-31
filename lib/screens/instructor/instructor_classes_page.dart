import 'package:flutter/material.dart';

import '../../services/roster_service.dart';
import 'instructor_class_details_page.dart';

class InstructorClassesScreen extends StatefulWidget {
  const InstructorClassesScreen({
    super.key,
  });

  @override
  State<InstructorClassesScreen> createState() =>
      _InstructorClassesScreenState();
}

class _InstructorClassesScreenState
    extends State<InstructorClassesScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal =
      Color(0xFF00897B);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  // ============================================================
  // SERVICE
  // ============================================================

  final RosterService _rosterService =
      RosterService();

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _courses =
      [];

  bool _isLoading =
      true;

  String? _errorMessage;

  String _searchQuery =
      '';

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCourses();
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> courses =
          await _rosterService
              .getInstructorCourses();

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } on RosterServiceException catch (e) {
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
            'Unable to load classes.';
      });
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>>
      get _filteredCourses {
    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

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

        final String semester =
            (course['semester'] ?? '')
                .toString()
                .toLowerCase();

        final String academicYear =
            (course['academicYear'] ?? '')
                .toString()
                .toLowerCase();

        return code.contains(query) ||
            title.contains(query) ||
            semester.contains(query) ||
            academicYear.contains(query);
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          AppBar(
        automaticallyImplyLeading:
            false,

        backgroundColor:
            background,

        elevation:
            0,

        centerTitle:
            true,

        title:
            const Text(
          'Manage Classes',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w800,

            color:
                textDark,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Refresh',

            icon:
                const Icon(
              Icons.refresh_rounded,

              color:
                  textDark,
            ),

            onPressed:
                _loadCourses,
          ),

          const SizedBox(
            width:
                8,
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Align(
          alignment:
              Alignment.topCenter,

          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  1200,
            ),

            child:
                Column(
              children: [
                // ================================================
                // SEARCH
                // ================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    12,
                  ),

                  child:
                      TextField(
                    onChanged:
                        (value) {
                      setState(() {
                        _searchQuery =
                            value;
                      });
                    },

                    decoration:
                        InputDecoration(
                      hintText:
                          'Search by course code, title, or semester...',

                      prefixIcon:
                          const Icon(
                        Icons.search_rounded,

                        color:
                            primaryTeal,
                      ),

                      filled:
                          true,

                      fillColor:
                          Colors.white,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),

                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE3E7EE,
                          ),
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),

                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE3E7EE,
                          ),
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),

                        borderSide:
                            const BorderSide(
                          color:
                              primaryTeal,

                          width:
                              1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // ================================================
                // CONTENT
                // ================================================

                Expanded(
                  child:
                      _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              primaryTeal,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.cloud_off_rounded,

                size:
                    48,

                color:
                    Colors.redAccent,
              ),

              const SizedBox(
                height:
                    12,
              ),

              Text(
                _errorMessage!,

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      textGrey,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),

              TextButton.icon(
                onPressed:
                    _loadCourses,

                icon:
                    const Icon(
                  Icons.refresh_rounded,
                ),

                label:
                    const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return const Center(
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Icon(
              Icons.class_outlined,

              size:
                  52,

              color:
                  primaryTeal,
            ),

            SizedBox(
              height:
                  12,
            ),

            Text(
              'No active classes',

              style:
                  TextStyle(
                color:
                    textDark,

                fontSize:
                    17,

                fontWeight:
                    FontWeight.w800,
              ),
            ),

            SizedBox(
              height:
                  5,
            ),

            Text(
              'Courses assigned to this instructor will appear here.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    textGrey,

                fontSize:
                    12,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredCourses.isEmpty) {
      return const Center(
        child:
            Text(
          'No matching classes.',

          style:
              TextStyle(
            color:
                textGrey,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color:
          primaryTeal,

      onRefresh:
          _loadCourses,

      child:
          ListView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),

        padding:
            const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          30,
        ),

        children: [
          Row(
            children: [
              const Expanded(
                child:
                    Text(
                  'Active Classes',

                  style:
                      TextStyle(
                    color:
                        textDark,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      10,

                  vertical:
                      6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      primaryTeal.withValues(
                    alpha:
                        0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),

                child:
                    Text(
                  '${_filteredCourses.length} '
                  '${_filteredCourses.length == 1 ? 'Class' : 'Classes'}',

                  style:
                      const TextStyle(
                    color:
                        primaryTeal,

                    fontSize:
                        10.5,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          ..._filteredCourses.map(
            _buildCourseCard,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COURSE CARD
  // ============================================================

  Widget _buildCourseCard(
    Map<String, dynamic> course,
  ) {
    final String courseId =
        (course['id'] ?? '')
            .toString();

    final String code =
        (course['code'] ?? 'COURSE')
            .toString();

    final String title =
        (course['title'] ?? 'Course')
            .toString();

    final String semester =
        (course['semester'] ?? '')
            .toString();

    final String academicYear =
        (course['academicYear'] ?? '')
            .toString();

    final String instructorName =
        (course['instructorName'] ??
                'Instructor')
            .toString();

    final int students =
        course['studentCount'] is num
            ? (course['studentCount'] as num)
                .toInt()
            : 0;

    final String period =
        [
          semester,
          academicYear,
        ]
            .where(
              (value) =>
                  value.trim().isNotEmpty,
            )
            .join(' • ');

    return GestureDetector(
      onTap:
          () {
        if (courseId.isEmpty) {
          return;
        }

        Navigator.push(
          context,

          MaterialPageRoute(
            builder:
                (
              context,
            ) =>
                    InstructorClassDetailsScreen(
              courseId:
                  courseId,

              title:
                  title,

              section:
                  period,

              courseCode:
                  code,

              instructorName:
                  instructorName,
            ),
          ),
        );
      },

      child:
          Container(
        margin:
            const EdgeInsets.only(
          bottom:
              15,
        ),

        padding:
            const EdgeInsets.all(
          20,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border:
              Border.all(
            color:
                const Color(
              0xFFE6EAF0,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha:
                    0.025,
              ),

              blurRadius:
                  14,

              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),

        child:
            Row(
          children: [
            Container(
              width:
                  58,

              height:
                  58,

              decoration:
                  BoxDecoration(
                color:
                    primaryTeal.withValues(
                  alpha:
                      0.10,
                ),

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child:
                  const Icon(
                Icons.school_rounded,

                color:
                    primaryTeal,

                size:
                    28,
              ),
            ),

            const SizedBox(
              width:
                  15,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              8,

                          vertical:
                              4,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF0F3F8,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            6,
                          ),
                        ),

                        child:
                            Text(
                          code,

                          style:
                              const TextStyle(
                            color:
                                textDark,

                            fontSize:
                                10.5,

                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),

                      const Spacer(),

                      Text(
                        '$students enrolled',

                        style:
                            const TextStyle(
                          color:
                              textGrey,

                          fontSize:
                              11,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  Text(
                    title,

                    maxLines:
                        1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      color:
                          textDark,

                      fontSize:
                          16,

                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height:
                        4,
                  ),

                  if (period.isNotEmpty)
                    Text(
                      period,

                      style:
                          const TextStyle(
                        color:
                            primaryTeal,

                        fontSize:
                            12,

                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),

            const Icon(
              Icons.chevron_right_rounded,

              color:
                  Color(
                0xFF9BA4B4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}