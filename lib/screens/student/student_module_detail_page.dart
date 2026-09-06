import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/assessment_submission_service.dart';

import 'student_ai_quiz_page.dart';
import 'student_assessment_submission_page.dart';

class StudentModuleDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String moduleId;

  const StudentModuleDetailScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.moduleId,
  });

  @override
  State<StudentModuleDetailScreen> createState() =>
      _StudentModuleDetailScreenState();
}

class _StudentModuleDetailScreenState extends State<StudentModuleDetailScreen>
    with WidgetsBindingObserver {
  // ============================================================
  // DESIGN
  // ============================================================

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);
  static const Color purple = Color(0xFF7B4DFF);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final AssessmentSubmissionService _submissionService =
      AssessmentSubmissionService();

  // ============================================================
  // STATE
  // ============================================================

  int _selectedTab = 1;

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _course;
  Map<String, dynamic>? _module;

  List<Map<String, dynamic>> _assessments = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _resources = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadPage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _loadPage();
    }
  }

  // ============================================================
  // LOAD PAGE
  // ============================================================

  Future<void> _loadPage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String? studentId = _auth.currentUser?.uid;

      if (studentId == null || studentId.isEmpty) {
        throw Exception('You must be logged in to open this module.');
      }

      // ----------------------------------------------------------
      // CHECK ENROLLMENT
      // ----------------------------------------------------------

      final String enrollmentId = '${widget.courseId}_$studentId';

      final DocumentSnapshot<Map<String, dynamic>> enrollmentDocument =
          await _firestore.collection('enrollments').doc(enrollmentId).get();

      if (!enrollmentDocument.exists || enrollmentDocument.data() == null) {
        throw Exception('You are not enrolled in this course.');
      }

      final String enrollmentStatus =
          (enrollmentDocument.data()!['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (enrollmentStatus != 'active') {
        throw Exception('Your enrollment in this course is not active.');
      }

      // ----------------------------------------------------------
      // COURSE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await _firestore.collection('courses').doc(widget.courseId).get();

      if (!courseDocument.exists || courseDocument.data() == null) {
        throw Exception('Course could not be found.');
      }

      final Map<String, dynamic> courseData = courseDocument.data()!;

      final String courseStatus = (courseData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (courseStatus != 'active') {
        throw Exception('This course is not currently active.');
      }

      // ----------------------------------------------------------
      // MODULE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> moduleDocument =
          await _firestore.collection('modules').doc(widget.moduleId).get();

      if (!moduleDocument.exists || moduleDocument.data() == null) {
        throw Exception('Module could not be found.');
      }

      final Map<String, dynamic> moduleData = moduleDocument.data()!;

      final String moduleCourseId = (moduleData['courseId'] ?? '')
          .toString()
          .trim();

      if (moduleCourseId != widget.courseId) {
        throw Exception('This module does not belong to the selected course.');
      }

      final String moduleStatus = (moduleData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (moduleStatus != 'published') {
        throw Exception('This module is not currently published.');
      }

      // ----------------------------------------------------------
      // PUBLISHED ASSESSMENTS
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> assessmentSnapshot =
          await _firestore
              .collection('assessments')
              .where('moduleId', isEqualTo: widget.moduleId)
              .get();

      final List<Map<String, dynamic>> assessments = [];

      for (final document in assessmentSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String courseId = (data['courseId'] ?? '').toString();

        final String status = (data['status'] ?? '').toString().toLowerCase();

        if (courseId != widget.courseId) {
          continue;
        }

        if (status != 'published') {
          continue;
        }

        assessments.add({
          ...data,
          'id': document.id,
          'assessmentId': document.id,
        });
      }

      assessments.sort((a, b) {
        final DateTime? aDue = _dateFrom(a['dueAt']);

        final DateTime? bDue = _dateFrom(b['dueAt']);

        if (aDue == null && bDue == null) {
          return 0;
        }

        if (aDue == null) {
          return 1;
        }

        if (bDue == null) {
          return -1;
        }

        return aDue.compareTo(bDue);
      });

      // ----------------------------------------------------------
      // CURRENT STUDENT SUBMISSIONS
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> submissions = await _submissionService
          .getMyModuleSubmissions(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
          );

      // ----------------------------------------------------------
      // OPTIONAL RESOURCES
      //
      // Current project may not have resources yet.
      // This query is safe if the collection is empty.
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> resourceSnapshot =
          await _firestore
              .collection('moduleResources')
              .where('moduleId', isEqualTo: widget.moduleId)
              .get();

      final List<Map<String, dynamic>> resources = resourceSnapshot.docs
          .map((document) => {...document.data(), 'id': document.id})
          .where((resource) {
            final String status = (resource['status'] ?? 'published')
                .toString()
                .trim()
                .toLowerCase();

            return (resource['courseId'] ?? '').toString() == widget.courseId &&
                status == 'published';
          })
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _course = {...courseData, 'id': courseDocument.id};

        _module = {...moduleData, 'id': moduleDocument.id};

        _assessments = assessments;
        _submissions = submissions;
        _resources = resources;

        _isLoading = false;
      });
    } on AssessmentSubmissionException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
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
  // DYNAMIC VALUES
  // ============================================================

  String get _moduleTitle {
    return (_module?['title'] ?? 'Module').toString();
  }

  String get _moduleDescription {
    return (_module?['description'] ?? '').toString().trim();
  }

  int get _moduleOrder {
    return (_module?['order'] as num?)?.toInt() ?? 0;
  }

  String get _instructorName {
    return (_course?['instructorName'] ?? '').toString().trim();
  }

  int get _completedAssessmentCount {
    int completed = 0;
    for (final assessment in _assessments) {
      final String assessmentId =
          (assessment['assessmentId'] ?? assessment['id'] ?? '').toString();
      final String status = (_submissionFor(assessmentId)?['status'] ?? '')
          .toString()
          .toLowerCase();
      if (status == 'submitted' || status == 'graded') {
        completed++;
      }
    }
    return completed;
  }

  int get _gradedAssessmentCount => _submissions.where((submission) {
    return (submission['status'] ?? '').toString().toLowerCase() == 'graded';
  }).length;

  double get _assessmentProgress => _assessments.isEmpty
      ? 0.0
      : (_completedAssessmentCount / _assessments.length)
            .clamp(0.0, 1.0)
            .toDouble();

  // ============================================================
  // SUBMISSION LOOKUP
  // ============================================================

  Map<String, dynamic>? _submissionFor(String assessmentId) {
    for (final submission in _submissions) {
      if ((submission['assessmentId'] ?? '').toString() == assessmentId) {
        return submission;
      }
    }

    return null;
  }

  String _assessmentSubmissionMethod(Map<String, dynamic> assessment) {
    final String configured = (assessment['submissionMethod'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (configured == 'google_form' || configured == 'artifact') {
      return configured;
    }

    final String deliveryType = (assessment['deliveryType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (deliveryType == 'ai_generated') {
      return 'in_app_quiz';
    }

    if (deliveryType == 'artifact_submission') {
      return 'artifact';
    }

    // Automatically recognize Google Forms created before Phase 7F.
    final Uri? uri = Uri.tryParse(
      (assessment['externalUrl'] ?? '').toString().trim(),
    );
    final String host = uri?.host.toLowerCase() ?? '';
    final bool googleForm =
        host == 'forms.gle' ||
        (host == 'docs.google.com' &&
            (uri?.path.toLowerCase().contains('/forms/') ?? false));

    return googleForm ? 'google_form' : 'artifact';
  }

  // ============================================================
  // OPEN EXTERNAL LINK
  // ============================================================

  Future<void> _openAssessment(Map<String, dynamic> assessment) async {
    final String deliveryType = (assessment['deliveryType'] ?? 'external_link')
        .toString()
        .trim()
        .toLowerCase();

    final String assessmentType = (assessment['assessmentType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    final bool isAiQuiz =
        deliveryType == 'ai_generated' && assessmentType == 'quiz';

    if (isAiQuiz) {
      if (assessmentId.isEmpty) {
        _showError('Assessment ID is missing.');

        return;
      }

      if (_isPastDue(assessment)) {
        _showError('The deadline for this quiz has already passed.');

        return;
      }

      final Map<String, dynamic>? existingSubmission = _submissionFor(
        assessmentId,
      );

      if (existingSubmission != null) {
        final String status = (existingSubmission['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'submitted' || status == 'graded') {
          _showError('You have already submitted this quiz.');

          return;
        }
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentAiQuizScreen(
            assessmentId: assessmentId,
            courseId: widget.courseId,
            moduleId: widget.moduleId,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      await _loadPage();

      return;
    }

    final String url = (assessment['externalUrl'] ?? '').toString().trim();

    if (url.isEmpty) {
      _showError('This assessment does not have a valid link.');

      return;
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showError('This assessment link is invalid.');

      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showError('Unable to open the assessment link.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to open assessment: $e');
    }
  }

  // ============================================================
  // OPEN LEARNING RESOURCE
  // ============================================================

  Future<void> _openResource(Map<String, dynamic> resource) async {
    final String deliveryType = (resource['deliveryType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final String uploadedUrl = (resource['fileUrl'] ?? '').toString().trim();

    final String externalUrl = (resource['externalUrl'] ?? '')
        .toString()
        .trim();

    final String url = deliveryType == 'uploaded_file'
        ? uploadedUrl
        : externalUrl.isNotEmpty
        ? externalUrl
        : uploadedUrl;

    if (url.isEmpty) {
      _showError('This resource does not have a valid file or link.');

      return;
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showError('This resource link is invalid.');

      return;
    }

    try {
      bool opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (!opened && mounted) {
        _showError('Unable to open this resource.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to open resource: $e');
    }
  }

  // ============================================================
  // OPEN ASSESSMENT SUBMISSION
  // ============================================================

  Future<void> _openAssessmentSubmission(
    Map<String, dynamic> assessment,
  ) async {
    if (_assessmentSubmissionMethod(assessment) != 'artifact') {
      _showError('This assessment does not accept GitHub or file uploads.');
      return;
    }

    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    final Map<String, dynamic>? existingSubmission = _submissionFor(
      assessmentId,
    );

    if (existingSubmission != null) {
      final String status = (existingSubmission['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status == 'submitted' || status == 'graded') {
        _showError('This assessment has already been submitted.');
        return;
      }
    }

    if (_isPastDue(assessment)) {
      _showError('The deadline for this assessment has passed.');
      return;
    }

    final bool? submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) =>
            StudentAssessmentSubmissionScreen(assessment: assessment),
      ),
    );

    if (!mounted || submitted != true) {
      return;
    }

    await _loadPage();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assessment submitted successfully.'),
        backgroundColor: green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
  // DATE HELPERS
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

  bool _isPastDue(Map<String, dynamic> assessment) {
    final DateTime? dueAt = _dateFrom(assessment['dueAt']);

    if (dueAt == null) {
      return false;
    }

    return DateTime.now().isAfter(dueAt);
  }

  String _formatDate(dynamic value) {
    final DateTime? date = _dateFrom(value);

    if (date == null) {
      return 'No due date';
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

  String _formatSubmittedAt(dynamic value) {
    final DateTime? date = _dateFrom(value);

    if (date == null) {
      return 'Submitted';
    }

    return 'Submitted ${_formatDate(value)}';
  }

  // ============================================================
  // ASSESSMENT ICON
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
        return primaryBlue;

      case 'activity':
        return orange;

      case 'assignment':
        return purple;

      case 'exam':
        return red;

      default:
        return primaryBlue;
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1769FF), Color(0xFF4E86FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildTabs(),
                  const SizedBox(height: 4),
                  Expanded(child: _buildSelectedTab()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.courseCode.isEmpty
                      ? widget.courseTitle
                      : '${widget.courseCode} • ${widget.courseTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: IconButton(
                  onPressed: _loadPage,
                  tooltip: 'Refresh module',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_moduleOrder > 0)
                      Text(
                        'MODULE $_moduleOrder',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      _moduleTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_instructorName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Instructor: $_instructorName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '$_completedAssessmentCount of ${_assessments.length} tasks completed',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(_assessmentProgress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _assessmentProgress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFF3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Lessons', Icons.notes_rounded, 0)),
          Expanded(child: _buildTab('Tasks', Icons.task_alt_rounded, 1)),
          Expanded(child: _buildTab('Files', Icons.folder_rounded, 2)),
          Expanded(child: _buildTab('Grades', Icons.grade_rounded, 3)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, IconData icon, int index) {
    final bool selected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? primaryBlue : textGrey),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                color: selected ? primaryBlue : textGrey,
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 0:
        return _buildLessons();

      case 1:
        return _buildTasks();

      case 2:
        return _buildResources();

      case 3:
        return _buildGrades();

      default:
        return _buildTasks();
    }
  }

  // ============================================================
  // LESSONS
  // ============================================================

  Widget _buildLessons() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
      children: [
        _buildLearningSnapshot(),

        const SizedBox(height: 22),

        const Text(
          'Module Overview',
          style: TextStyle(
            color: textDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            _moduleDescription.isNotEmpty
                ? _moduleDescription
                : 'No module description has been provided yet.',
            style: const TextStyle(
              color: textGrey,
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningSnapshot() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: [
          _buildSnapshotItem(
            Icons.task_alt_rounded,
            'Tasks',
            '$_completedAssessmentCount/${_assessments.length}',
          ),
          Container(width: 1, height: 38, color: borderColor),
          _buildSnapshotItem(
            Icons.folder_rounded,
            'Resources',
            '${_resources.length}',
          ),
          Container(width: 1, height: 38, color: borderColor),
          _buildSnapshotItem(
            Icons.grade_rounded,
            'Graded',
            '$_gradedAssessmentCount',
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: primaryBlue, size: 19),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TASKS
  // ============================================================

  Widget _buildTasks() {
    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 45),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Assessments',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildCountBadge(
                '$_completedAssessmentCount/${_assessments.length} done',
                primaryBlue,
              ),
            ],
          ),

          const SizedBox(height: 4),

          const Text(
            'Complete each assessment using only the submission method selected by your instructor.',
            style: TextStyle(color: textGrey, fontSize: 11.5, height: 1.45),
          ),

          const SizedBox(height: 16),

          if (_assessments.isEmpty)
            _buildEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No assessments yet',
              message:
                  'Published assessments for this module will appear here.',
            )
          else
            ..._assessments.map(_buildAssessmentCard),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '').toString();

    final String title = (assessment['title'] ?? 'Assessment').toString();

    final String instructions = (assessment['instructions'] ?? '').toString();

    final String type = (assessment['assessmentType'] ?? 'assessment')
        .toString()
        .toLowerCase();

    final num points = (assessment['totalPoints'] as num?) ?? 0;

    final String deliveryType = (assessment['deliveryType'] ?? 'external_link')
        .toString()
        .trim()
        .toLowerCase();

    final bool isAiQuiz = deliveryType == 'ai_generated' && type == 'quiz';

    final String submissionMethod = _assessmentSubmissionMethod(assessment);
    final bool isGoogleForm = submissionMethod == 'google_form';
    final bool isArtifact = submissionMethod == 'artifact';
    final bool hasExternalUrl = (assessment['externalUrl'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final bool showPrimaryAction =
        isAiQuiz || isGoogleForm || (isArtifact && hasExternalUrl);

    final Map<String, dynamic>? submission = _submissionFor(assessmentId);

    final String submissionStatus = (submission?['status'] ?? '')
        .toString()
        .toLowerCase();

    final bool submitted =
        submissionStatus == 'submitted' || submissionStatus == 'graded';

    final bool graded = submissionStatus == 'graded';

    final bool notComplied = submissionStatus == 'not_complied';

    final bool pastDue = _isPastDue(assessment);

    final Color color = _assessmentColor(type);

    final Color stateColor = graded || submitted
        ? green
        : notComplied || pastDue
        ? red
        : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stateColor.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_assessmentIcon(type), color: color, size: 24),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${_capitalize(type)} • $points points',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStatusBadge(
                submitted: submitted,
                graded: graded,
                pastDue: pastDue,
                notComplied: notComplied,
              ),
            ],
          ),

          if (instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 13),

            Text(
              instructions,
              style: const TextStyle(
                color: textGrey,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 13),

          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: pastDue ? red : textGrey,
                size: 16,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  'Due ${_formatDate(assessment['dueAt'])}',
                  style: TextStyle(
                    color: pastDue ? red : textGrey,
                    fontSize: 10.5,
                    fontWeight: pastDue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (submission != null && (submitted || notComplied)) ...[
            const SizedBox(height: 9),

            Row(
              children: [
                Icon(
                  notComplied
                      ? Icons.cancel_outlined
                      : graded
                      ? Icons.verified_rounded
                      : Icons.check_circle_rounded,
                  color: notComplied ? red : green,
                  size: 16,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    notComplied
                        ? 'Your instructor could not verify a Google Form response.'
                        : graded
                        ? 'Graded'
                        : _formatSubmittedAt(submission['submittedAt']),
                    style: TextStyle(
                      color: notComplied ? red : green,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (isGoogleForm && !submitted && !pastDue) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sync_rounded, color: primaryBlue, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    notComplied
                        ? 'Submit the form using your registered email, then ask your instructor to verify it again.'
                        : 'After submitting the form, your instructor will verify your response. Progress updates only after you are marked Complied.',
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (showPrimaryAction) ...[
            const SizedBox(height: 17),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: submitted || pastDue
                    ? null
                    : () {
                        _openAssessment(assessment);
                      },
                icon: Icon(
                  isAiQuiz
                      ? Icons.quiz_rounded
                      : isGoogleForm
                      ? Icons.description_outlined
                      : Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  submitted
                      ? graded
                            ? 'Assessment Graded'
                            : isAiQuiz
                            ? 'Quiz Submitted'
                            : isGoogleForm
                            ? 'Form Response Received'
                            : 'Assessment Submitted'
                      : pastDue
                      ? 'Deadline Passed'
                      : isAiQuiz
                      ? 'Take Quiz in CASLMS'
                      : isGoogleForm
                      ? 'Open Google Form'
                      : 'Open Assessment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  disabledBackgroundColor: submitted
                      ? green
                      : const Color(0xFF9AA3B3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],

          if (isArtifact) ...[
            const SizedBox(height: 9),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: submitted || pastDue
                    ? null
                    : () {
                        _openAssessmentSubmission(assessment);
                      },
                icon: Icon(
                  submitted
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 18,
                ),
                label: Text(
                  graded
                      ? 'Graded'
                      : submitted
                      ? 'Submitted'
                      : pastDue
                      ? 'Deadline Passed'
                      : 'Submit Work',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: submitted ? green : primaryBlue,
                  side: BorderSide(color: submitted ? green : primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool submitted,
    required bool graded,
    required bool pastDue,
    required bool notComplied,
  }) {
    String text;
    Color color;

    if (graded) {
      text = 'GRADED';
      color = green;
    } else if (submitted) {
      text = 'SUBMITTED';
      color = green;
    } else if (notComplied) {
      text = 'NOT COMPLIED';
      color = red;
    } else if (pastDue) {
      text = 'CLOSED';
      color = red;
    } else {
      text = 'TO DO';
      color = orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // RESOURCES
  // ============================================================

  Widget _buildResources() {
    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Learning Resources',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildCountBadge(
                '${_resources.length} ${_resources.length == 1 ? 'file' : 'files'}',
                primaryBlue,
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_resources.isEmpty)
            _buildEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No resources yet',
              message:
                  'Learning materials added to this module will appear here.',
            )
          else
            ..._resources.map(_buildResourceCard),
        ],
      ),
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    final String title =
        (resource['title'] ??
                resource['fileName'] ??
                resource['name'] ??
                'Resource')
            .toString();

    final String type = (resource['resourceType'] ?? resource['type'] ?? 'file')
        .toString();

    final String normalizedType = type.toLowerCase();
    final IconData resourceIcon = normalizedType.contains('pdf')
        ? Icons.picture_as_pdf_rounded
        : normalizedType.contains('video')
        ? Icons.play_circle_outline_rounded
        : normalizedType.contains('link')
        ? Icons.link_rounded
        : normalizedType.contains('doc') || normalizedType.contains('word')
        ? Icons.article_outlined
        : Icons.insert_drive_file_outlined;

    final Color resourceColor = normalizedType.contains('pdf')
        ? red
        : normalizedType.contains('video')
        ? purple
        : primaryBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resourceColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: resourceColor.withValues(alpha: 0.045),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openResource(resource),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: resourceColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(resourceIcon, color: resourceColor),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        type,
                        style: const TextStyle(color: textGrey, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.open_in_new_rounded,
                  color: textGrey,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GRADES
  // ============================================================

  Widget _buildGrades() {
    final List<Map<String, dynamic>> gradedSubmissions = _submissions.where((
      submission,
    ) {
      return (submission['status'] ?? '').toString().toLowerCase() == 'graded';
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Assessment Grades',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildCountBadge('${gradedSubmissions.length} graded', green),
            ],
          ),

          const SizedBox(height: 4),

          const Text(
            'Only assessments graded by your instructor appear here.',
            style: TextStyle(color: textGrey, fontSize: 11.5),
          ),

          const SizedBox(height: 16),

          if (gradedSubmissions.isEmpty)
            _buildEmptyState(
              icon: Icons.grade_outlined,
              title: 'No grades yet',
              message: 'Your instructor has not graded any assessment in this module yet.',
            )
          else
            ...gradedSubmissions.map(_buildGradeCard),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> submission) {
    final String assessmentId = (submission['assessmentId'] ?? '').toString();

    Map<String, dynamic>? assessment;

    for (final item in _assessments) {
      if ((item['assessmentId'] ?? item['id'] ?? '').toString() ==
          assessmentId) {
        assessment = item;
        break;
      }
    }

    final String title = (assessment?['title'] ?? 'Assessment').toString();

    final num totalPoints = (assessment?['totalPoints'] as num?) ?? 0;

    final num score = (submission['score'] as num?) ?? 0;

    final String feedback = (submission['feedback'] ?? '').toString().trim();

    final double percentage = totalPoints > 0 ? (score / totalPoints) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: green.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: 0.05),
            blurRadius: 15,
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
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.verified_outlined, color: green),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score / $totalPoints',
                    style: const TextStyle(
                      color: green,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(color: textGrey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructor Feedback',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    feedback,
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryBlue, size: 27),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textGrey, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Container(
      color: background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 48),

              const SizedBox(height: 13),

              Text(
                _errorMessage ?? 'Unable to load module.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: _loadPage,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
