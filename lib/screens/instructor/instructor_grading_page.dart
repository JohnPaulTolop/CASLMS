import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';
import '../shared/grading_ui.dart';

import 'instructor_assessment_grading_page.dart';
import 'instructor_semester_grades_page.dart';

class InstructorGradingScreen extends StatefulWidget {
  const InstructorGradingScreen({super.key});

  @override
  State<InstructorGradingScreen> createState() =>
      _InstructorGradingScreenState();
}

class _InstructorGradingScreenState extends State<InstructorGradingScreen> {
  // ============================================================
  // DESIGN
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);
  static const Color blue = Color(0xFF1769FF);
  static const Color purple = Color(0xFF7B4DFF);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  String? _errorMessage;

  String _selectedFilter = 'submitted';

  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _externalAssessments = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadGradingData();
  }

  // ============================================================
  // LOAD REAL GRADING DATA
  // ============================================================

  Future<void> _loadGradingData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String? instructorId = _auth.currentUser?.uid;

      if (instructorId == null || instructorId.isEmpty) {
        throw Exception('You must be logged in as an instructor.');
      }

      // ----------------------------------------------------------
      // VERIFY INSTRUCTOR ACCOUNT
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> instructorDocument =
          await _firestore.collection('users').doc(instructorId).get();

      if (!instructorDocument.exists || instructorDocument.data() == null) {
        throw Exception('Instructor profile could not be found.');
      }

      final Map<String, dynamic> instructorData = instructorDocument.data()!;

      final String role = (instructorData['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'instructor') {
        throw Exception('Only instructors can access grading.');
      }

      final String instructorStatus = (instructorData['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (instructorStatus != 'active') {
        throw Exception('Your instructor account is not active.');
      }

      // ----------------------------------------------------------
      // GET ALL COURSES OWNED BY CURRENT INSTRUCTOR
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> courseSnapshot =
          await _firestore
              .collection('courses')
              .where('instructorId', isEqualTo: instructorId)
              .get();

      final List<Map<String, dynamic>> loadedSubmissions = [];
      final List<Map<String, dynamic>> manualAssessments = [];

      // ----------------------------------------------------------
      // PROCESS EACH OWNED COURSE
      // ----------------------------------------------------------

      for (final courseDocument in courseSnapshot.docs) {
        final Map<String, dynamic> course = courseDocument.data();

        final String courseId = courseDocument.id;

        // --------------------------------------------------------
        // MODULES
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>> moduleSnapshot =
            await _firestore
                .collection('modules')
                .where('courseId', isEqualTo: courseId)
                .get();

        final Map<String, Map<String, dynamic>> moduleById = {};

        for (final document in moduleSnapshot.docs) {
          moduleById[document.id] = {
            ...document.data(),
            'id': document.id,
            'moduleId': document.id,
          };
        }

        // --------------------------------------------------------
        // ASSESSMENTS
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>> assessmentSnapshot =
            await _firestore
                .collection('assessments')
                .where('courseId', isEqualTo: courseId)
                .get();

        final Map<String, Map<String, dynamic>> assessmentById = {};

        for (final document in assessmentSnapshot.docs) {
          final item = document.data();
          if (item['deliveryType'] == 'external_link' &&
              ['published', 'closed'].contains(item['status'])) {
            manualAssessments.add({
              ...item,
              'assessmentId': document.id,
              'courseCode': course['code'],
            });
          }
          assessmentById[document.id] = {
            ...document.data(),
            'id': document.id,
            'assessmentId': document.id,
          };
        }

        // --------------------------------------------------------
        // ASSESSMENT SUBMISSIONS
        // --------------------------------------------------------

        final QuerySnapshot<Map<String, dynamic>> submissionSnapshot =
            await _firestore
                .collection('assessmentSubmissions')
                .where('courseId', isEqualTo: courseId)
                .get();

        for (final submissionDocument in submissionSnapshot.docs) {
          final Map<String, dynamic> submission = submissionDocument.data();

          final String assessmentId = (submission['assessmentId'] ?? '')
              .toString()
              .trim();

          if (assessmentId.isEmpty) {
            continue;
          }

          final Map<String, dynamic>? assessment = assessmentById[assessmentId];

          // Assessment may have been deleted.
          if (assessment == null) {
            continue;
          }

          final String moduleId = (assessment['moduleId'] ?? '')
              .toString()
              .trim();

          final Map<String, dynamic>? module = moduleById[moduleId];

          loadedSubmissions.add({
            ...submission,

            'id': submissionDocument.id,
            'submissionId': submissionDocument.id,

            'assessmentId': assessmentId,

            'assessmentTitle': (assessment['title'] ?? 'Assessment').toString(),

            'assessmentType': (assessment['assessmentType'] ?? 'assessment')
                .toString(),

            'totalPoints': assessment['totalPoints'] ?? 0,

            'assessmentStatus': (assessment['status'] ?? '').toString(),

            'dueAt': assessment['dueAt'],

            'moduleId': moduleId,

            'moduleTitle': (module?['title'] ?? 'Module').toString(),

            'courseId': courseId,

            'courseCode': (course['code'] ?? '').toString(),

            'courseTitle': (course['title'] ?? '').toString(),
          });
        }
      }

      // ----------------------------------------------------------
      // SORT
      //
      // Pending first.
      // Newest submissions first.
      // ----------------------------------------------------------

      loadedSubmissions.sort((a, b) {
        final String aStatus = (a['status'] ?? '').toString().toLowerCase();

        final String bStatus = (b['status'] ?? '').toString().toLowerCase();

        if (aStatus == 'submitted' && bStatus != 'submitted') {
          return -1;
        }

        if (aStatus != 'submitted' && bStatus == 'submitted') {
          return 1;
        }

        final DateTime? aDate = _dateFrom(a['submittedAt']);

        final DateTime? bDate = _dateFrom(b['submittedAt']);

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _submissions = loadedSubmissions;
        _externalAssessments = manualAssessments;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _pendingCount {
    return _submissions.where((submission) {
      return (submission['status'] ?? '').toString().toLowerCase() ==
          'submitted';
    }).length;
  }

  int get _gradedCount {
    return _submissions.where((submission) {
      return (submission['status'] ?? '').toString().toLowerCase() == 'graded';
    }).length;
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _visibleSubmissions {
    if (_selectedFilter == 'submitted') {
      return _submissions.where((submission) {
        return (submission['status'] ?? '').toString().toLowerCase() ==
            'submitted';
      }).toList();
    }

    if (_selectedFilter == 'graded') {
      return _submissions.where((submission) {
        return (submission['status'] ?? '').toString().toLowerCase() ==
            'graded';
      }).toList();
    }

    return _submissions;
  }

  // ============================================================
  // OPEN REAL ASSESSMENT GRADING
  // ============================================================

  Future<void> _openGrading(Map<String, dynamic> submission) async {
    final String assessmentId = (submission['assessmentId'] ?? '')
        .toString()
        .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InstructorAssessmentGradingScreen(assessmentId: assessmentId),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadGradingData();
  }

  void _openSemesterGrades() => Navigator.of(context).push(
    GradeRoute<void>(builder: (_) => const InstructorSemesterGradesScreen()),
  );

  Future<void> _selectManualAssessment() async {
    if (_externalAssessments.isEmpty) {
      _showError('Publish an external quiz or assessment first.');
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Manual Grade Input'),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final assessment in _externalAssessments)
                ListTile(
                  title: Text((assessment['title'] ?? 'Assessment').toString()),
                  subtitle: Text(
                    '${assessment['courseCode'] ?? ''} • ${assessment['totalPoints']} points',
                  ),
                  onTap: () => Navigator.pop(dialog, assessment),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _openGrading(selected);
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final DateTime? date = _dateFrom(value);

    if (date == null) {
      return 'Unknown time';
    }

    final DateTime local = date.toLocal();

    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    int hour = local.hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final String minute = local.minute.toString().padLeft(2, '0');

    return '${months[local.month - 1]} '
        '${local.day}, ${local.year} • '
        '$hour:$minute $period';
  }

  // ============================================================
  // ASSESSMENT UI
  // ============================================================

  IconData _assessmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return Icons.quiz_outlined;

      case 'activity':
        return Icons.task_alt_outlined;

      case 'assignment':
        return Icons.assignment_outlined;

      case 'exam':
        return Icons.fact_check_outlined;

      default:
        return Icons.description_outlined;
    }
  }

  Color _assessmentColor(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
        return blue;

      case 'activity':
        return orange;

      case 'assignment':
        return purple;

      case 'exam':
        return red;

      default:
        return primaryTeal;
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,

      appBar: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: background,

        elevation: 0,

        centerTitle: true,

        title: const Text(
          'Grades & Feedback',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          RoundGradeAction(
            icon: Icons.edit_note_rounded,
            label: 'Manual Grade Input',
            onTap: _isLoading ? null : _selectManualAssessment,
          ),
          const SizedBox(width: 8),
          RoundGradeAction(
            icon: Icons.calculate_outlined,
            label: 'Compute & Finalize Semester Grades',
            onTap: _openSemesterGrades,
          ),
          const SizedBox(width: 8),
          RoundGradeAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh grading',
            onTap: _isLoading ? null : _loadGradingData,
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

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadGradingData,

      color: primaryTeal,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),

        children: [
          const GradeEntrance(
            child: GradeHero(
              title: 'A clearer path to grading.',
              subtitle: 'Review submissions, enter external scores, then preview and post semester grades.',
              icon: Icons.school_outlined,
              accent: gradeTeal,
              eyebrow: 'INSTRUCTOR WORKSPACE',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: constraints.maxWidth < 650
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: GradeShortcut(
                    icon: Icons.edit_note_rounded,
                    title: 'Manual Scores',
                    subtitle: 'Enter results from Google Forms and external assessments.',
                    onTap: _selectManualAssessment,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth < 650
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: GradeShortcut(
                    icon: Icons.calculate_outlined,
                    title: 'Semester Grades',
                    subtitle: 'Choose a class, set weights, review and post.',
                    onTap: _openSemesterGrades,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // ======================================================
          // SUMMARY
          // ======================================================

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'To Grade',
                  value: '$_pendingCount',
                  icon: Icons.pending_actions_rounded,
                  color: orange,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  label: 'Graded',
                  value: '$_gradedCount',
                  icon: Icons.verified_outlined,
                  color: green,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildStatCard(
                  label: 'Total',
                  value: '${_submissions.length}',
                  icon: Icons.assignment_turned_in_outlined,
                  color: primaryTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          // ======================================================
          // HEADER
          // ======================================================
          const Text(
            'Assessment Submissions',

            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Review and grade assessment submissions from your classes.',

            style: TextStyle(color: textGrey, fontSize: 11.5),
          ),

          const SizedBox(height: 15),

          // ======================================================
          // FILTERS
          // ======================================================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            child: Row(
              children: [
                _buildFilter(
                  value: 'submitted',
                  label: 'To Grade ($_pendingCount)',
                ),

                const SizedBox(width: 8),

                _buildFilter(value: 'graded', label: 'Graded ($_gradedCount)'),

                const SizedBox(width: 8),

                _buildFilter(
                  value: 'all',
                  label: 'All (${_submissions.length})',
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (_visibleSubmissions.isEmpty)
            _buildEmptyState()
          else
            ..._visibleSubmissions.map(_buildSubmissionCard),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor),
      ),

      child: Column(
        children: [
          Icon(icon, color: color, size: 22),

          const SizedBox(height: 6),

          Text(
            value,

            style: const TextStyle(
              color: textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,

            textAlign: TextAlign.center,

            style: const TextStyle(color: textGrey, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER CHIP
  // ============================================================

  Widget _buildFilter({required String value, required String label}) {
    final bool selected = _selectedFilter == value;

    return ChoiceChip(
      selected: selected,

      label: Text(label),

      selectedColor: primaryTeal.withValues(alpha: 0.12),

      backgroundColor: Colors.white,

      side: BorderSide(color: selected ? primaryTeal : borderColor),

      labelStyle: TextStyle(
        color: selected ? primaryTeal : textGrey,

        fontSize: 11,

        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),

      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  // ============================================================
  // SUBMISSION CARD
  // ============================================================

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final String studentName = (submission['studentName'] ?? 'Student')
        .toString();

    final String assessmentTitle =
        (submission['assessmentTitle'] ?? 'Assessment').toString();

    final String assessmentType = (submission['assessmentType'] ?? 'assessment')
        .toString()
        .toLowerCase();

    final String courseCode = (submission['courseCode'] ?? '').toString();

    final String courseTitle = (submission['courseTitle'] ?? '').toString();

    final String moduleTitle = (submission['moduleTitle'] ?? '').toString();

    final String status = (submission['status'] ?? 'submitted')
        .toString()
        .toLowerCase();

    final bool graded = status == 'graded';

    final num totalPoints = (submission['totalPoints'] as num?) ?? 0;

    final dynamic score = submission['score'];

    final Color typeColor = _assessmentColor(assessmentType);

    final String studentInitial = studentName.isNotEmpty
        ? studentName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),

      child: Material(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        child: InkWell(
          onTap: () {
            _openGrading(submission);
          },

          borderRadius: BorderRadius.circular(18),

          child: Container(
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: borderColor),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // STUDENT
                // ==================================================

                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,

                      backgroundColor: primaryTeal.withValues(alpha: 0.10),

                      child: Text(
                        studentInitial,

                        style: const TextStyle(
                          color: primaryTeal,

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
                            studentName,

                            style: const TextStyle(
                              color: textDark,

                              fontSize: 13.5,

                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            graded
                                ? 'Graded ${_formatDate(submission['gradedAt'])}'
                                : 'Submitted ${_formatDate(submission['submittedAt'])}',

                            style: const TextStyle(
                              color: textGrey,

                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),

                      decoration: BoxDecoration(
                        color: (graded ? green : orange).withValues(
                          alpha: 0.10,
                        ),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        graded ? 'GRADED' : 'TO GRADE',

                        style: TextStyle(
                          color: graded ? green : orange,

                          fontSize: 8,

                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                const Divider(height: 1, color: borderColor),

                const SizedBox(height: 14),

                // ==================================================
                // ASSESSMENT
                // ==================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Container(
                      width: 44,
                      height: 44,

                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.10),

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Icon(
                        _assessmentIcon(assessmentType),

                        color: typeColor,

                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            assessmentTitle,

                            style: const TextStyle(
                              color: textDark,

                              fontSize: 13,

                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            [
                              if (courseCode.isNotEmpty) courseCode,

                              if (courseTitle.isNotEmpty) courseTitle,
                            ].join(' • '),

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              color: textGrey,

                              fontSize: 10.5,

                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          if (moduleTitle.isNotEmpty) ...[
                            const SizedBox(height: 3),

                            Text(
                              moduleTitle,

                              style: const TextStyle(
                                color: textGrey,

                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (graded)
                      Text(
                        score is num ? '$score / $totalPoints' : 'Graded',

                        style: const TextStyle(
                          color: green,

                          fontSize: 12,

                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,

                        color: Color(0xFF9BA4B4),

                        size: 22,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,

                  height: 44,

                  child: ElevatedButton.icon(
                    onPressed: () {
                      _openGrading(submission);
                    },

                    icon: Icon(
                      graded ? Icons.edit_outlined : Icons.grading_rounded,

                      color: Colors.white,

                      size: 17,
                    ),

                    label: Text(
                      graded ? 'View / Update Grade' : 'Grade Assessment',

                      style: const TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: graded ? green : primaryTeal,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    String title;
    String message;
    IconData icon;

    if (_selectedFilter == 'submitted') {
      title = 'Nothing waiting to be graded';

      message = 'New student assessment submissions will appear here.';

      icon = Icons.check_circle_outline_rounded;
    } else if (_selectedFilter == 'graded') {
      title = 'No graded submissions';

      message = 'Assessments you grade will appear here.';

      icon = Icons.grade_outlined;
    } else {
      title = 'No assessment submissions';

      message = 'Student submissions from your courses will appear here.';

      icon = Icons.assignment_outlined;
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(30),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: borderColor),
      ),

      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,

            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.09),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: primaryTeal, size: 29),
          ),

          const SizedBox(height: 13),

          Text(
            title,

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: textDark,

              fontSize: 15,

              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            message,

            textAlign: TextAlign.center,

            style: const TextStyle(color: textGrey, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _loadGradingData,

      color: primaryTeal,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(30),

        children: [
          const SizedBox(height: 120),

          const Icon(Icons.error_outline_rounded, color: red, size: 50),

          const SizedBox(height: 13),

          Text(
            _errorMessage ?? 'Unable to load grading information.',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: textGrey,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: ElevatedButton.icon(
              onPressed: _loadGradingData,

              icon: const Icon(Icons.refresh_rounded, color: Colors.white),

              label: const Text(
                'Try Again',

                style: TextStyle(color: Colors.white),
              ),

              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
            ),
          ),
        ],
      ),
    );
  }
}
