import '../../core/app_colors.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';
import 'instructor_workspace_widgets.dart';

import 'package:flutter/services.dart';

class InstructorAnalyticsScreen extends StatefulWidget {
  const InstructorAnalyticsScreen({super.key, this.firestore, this.auth});
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  @override
  State<InstructorAnalyticsScreen> createState() =>
      _InstructorAnalyticsScreenState();
}

class _InstructorAnalyticsScreenState extends State<InstructorAnalyticsScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  Color get blue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get green => AppColors.resolve(context, AppColors.green);

  // ============================================================
  // FIREBASE
  // ============================================================

  late final FirebaseFirestore _firestore =
      widget.firestore ?? FirebaseFirestore.instance;

  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoadingCourses = true;
  bool _isLoadingAnalytics = false;

  String? _errorMessage;
  String? _selectedCourseId;

  List<Map<String, dynamic>> _courses = [];

  _InstructorAnalyticsData? _analytics;

  // Used so a slower old request cannot overwrite a newer
  // course selection.
  int _loadGeneration = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCourses();
  }

  // ============================================================
  // LOAD INSTRUCTOR COURSES
  // ============================================================

  Future<void> _loadCourses({bool keepSelectedCourse = true}) async {
    final int generation = ++_loadGeneration;

    if (mounted) {
      setState(() {
        _isLoadingCourses = true;
        _errorMessage = null;
      });
    }

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in as an instructor.');
      }

      // ----------------------------------------------------------
      // VERIFY CURRENT PROFILE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> profileDocument =
          await _firestore.collection('users').doc(user.uid).get();

      if (!profileDocument.exists || profileDocument.data() == null) {
        throw Exception('Instructor profile could not be found.');
      }

      final Map<String, dynamic> profile = profileDocument.data()!;

      final String role = (profile['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String accountStatus = (profile['status'] ?? 'active')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'instructor') {
        throw Exception('Only instructors can view cohort analytics.');
      }

      if (accountStatus != 'active') {
        throw Exception('Your instructor account is not active.');
      }

      // ----------------------------------------------------------
      // INSTRUCTOR COURSES
      // ----------------------------------------------------------

      final QuerySnapshot<Map<String, dynamic>> courseSnapshot =
          await _firestore
              .collection('courses')
              .where('instructorId', isEqualTo: user.uid)
              .get();

      final List<Map<String, dynamic>> courses = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in courseSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status = (data['status'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();

        // Analytics focuses on current classes. Legacy course
        // documents without a status are also treated as active.
        if (status.isNotEmpty && status != 'active') {
          continue;
        }

        courses.add({...data, 'id': document.id, 'courseId': document.id});
      }

      courses.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        return _courseLabel(a)
            .toLowerCase()
            .compareTo(_courseLabel(b).toLowerCase());
      });

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      String? nextSelectedCourseId;

      if (keepSelectedCourse &&
          _selectedCourseId != null &&
          courses.any((course) => _courseId(course) == _selectedCourseId)) {
        nextSelectedCourseId = _selectedCourseId;
      } else if (courses.isNotEmpty) {
        nextSelectedCourseId = _courseId(courses.first);
      }

      setState(() {
        _courses = courses;
        _selectedCourseId = nextSelectedCourseId;

        _isLoadingCourses = false;
        _errorMessage = null;

        if (courses.isEmpty) {
          _analytics = null;
        }
      });

      if (nextSelectedCourseId != null) {
        await _loadAnalytics(nextSelectedCourseId);
      }
    } on FirebaseException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingCourses = false;
        _isLoadingAnalytics = false;

        _errorMessage = e.message ?? 'Unable to load instructor courses.';
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingCourses = false;
        _isLoadingAnalytics = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // COURSE CHANGED
  // ============================================================

  Future<void> _changeCourse(String? courseId) async {
    if (courseId == null || courseId.isEmpty || courseId == _selectedCourseId) {
      return;
    }

    setState(() {
      _selectedCourseId = courseId;
      _analytics = null;
      _errorMessage = null;
    });

    await _loadAnalytics(courseId);
  }

  // ============================================================
  // LOAD COURSE ANALYTICS
  // ============================================================

  Future<void> _loadAnalytics(String courseId) async {
    final int generation = ++_loadGeneration;

    if (mounted) {
      setState(() {
        _isLoadingAnalytics = true;
        _errorMessage = null;
      });
    }

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in.');
      }

      final Map<String, dynamic>? selectedCourse = _courseById(courseId);

      if (selectedCourse == null) {
        throw Exception('Selected course could not be found.');
      }

      final String instructorId = (selectedCourse['instructorId'] ?? '')
          .toString()
          .trim();

      if (instructorId != user.uid) {
        throw Exception('You can only view analytics for your own courses.');
      }

      // ----------------------------------------------------------
      // LOAD ALL COURSE DATA IN PARALLEL
      // ----------------------------------------------------------

      final List<dynamic> results = await Future.wait<dynamic>([
        _firestore
            .collection('enrollments')
            .where('courseId', isEqualTo: courseId)
            .get(),

        _firestore
            .collection('modules')
            .where('courseId', isEqualTo: courseId)
            .get(),

        _firestore
            .collection('moduleProgress')
            .where('courseId', isEqualTo: courseId)
            .get(),

        _firestore
            .collection('assessments')
            .where('courseId', isEqualTo: courseId)
            .get(),

        _firestore
            .collection('assessmentSubmissions')
            .where('courseId', isEqualTo: courseId)
            .get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>> moduleSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>> progressSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>> assessmentSnapshot =
          results[3] as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>> submissionSnapshot =
          results[4] as QuerySnapshot<Map<String, dynamic>>;

      // ----------------------------------------------------------
      // ACTIVE ENROLLMENTS
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> enrollments = [];

      final Set<String> studentIds = {};

      for (final document in enrollmentSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status = (data['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final String studentId = (data['studentId'] ?? '').toString().trim();

        if (status != 'active' || studentId.isEmpty) {
          continue;
        }

        if (studentIds.add(studentId)) {
          enrollments.add({...data, 'id': document.id});
        }
      }

      // ----------------------------------------------------------
      // STUDENT PROFILES
      // ----------------------------------------------------------

      final Map<String, Map<String, dynamic>> studentProfiles = {};

      if (studentIds.isNotEmpty) {
        final List<DocumentSnapshot<Map<String, dynamic>>> profileDocuments =
            await Future.wait(
              studentIds.map(
                (String studentId) =>
                    _firestore.collection('users').doc(studentId).get(),
              ),
            );

        for (final DocumentSnapshot<Map<String, dynamic>> profileDocument
            in profileDocuments) {
          if (!profileDocument.exists || profileDocument.data() == null) {
            continue;
          }

          studentProfiles[profileDocument.id] = {
            ...profileDocument.data()!,
            'id': profileDocument.id,
            'uid': profileDocument.id,
          };
        }
      }

      // ----------------------------------------------------------
      // MODULES
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> modules = [];

      for (final document in moduleSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status = (data['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        // Only published modules contribute to student engagement.
        if (status != 'published') {
          continue;
        }

        modules.add({...data, 'id': document.id, 'moduleId': document.id});
      }

      modules.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final int aOrder = _moduleOrder(a);

        final int bOrder = _moduleOrder(b);

        if (aOrder != bOrder) {
          return aOrder.compareTo(bOrder);
        }

        return _moduleTitle(a).compareTo(_moduleTitle(b));
      });

      // ----------------------------------------------------------
      // PROGRESS
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> progressRecords = [];

      for (final document in progressSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String studentId = (data['studentId'] ?? '').toString().trim();

        if (!studentIds.contains(studentId)) {
          continue;
        }

        progressRecords.add({...data, 'id': document.id});
      }

      // ----------------------------------------------------------
      // ASSESSMENTS
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> assessments = [];

      final Map<String, Map<String, dynamic>> assessmentById = {};

      for (final document in assessmentSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final Map<String, dynamic> item = {
          ...data,
          'id': document.id,
          'assessmentId': document.id,
        };

        assessments.add(item);

        assessmentById[document.id] = item;
      }

      // ----------------------------------------------------------
      // SUBMISSIONS
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> submissions = [];

      for (final document in submissionSnapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String studentId = (data['studentId'] ?? '').toString().trim();

        if (!studentIds.contains(studentId)) {
          continue;
        }

        submissions.add({...data, 'id': document.id});
      }

      // ----------------------------------------------------------
      // BUILD ANALYTICS
      // ----------------------------------------------------------

      final _InstructorAnalyticsData analytics = _buildAnalytics(
        course: selectedCourse,
        enrollments: enrollments,
        studentProfiles: studentProfiles,
        modules: modules,
        progressRecords: progressRecords,
        assessments: assessments,
        assessmentById: assessmentById,
        submissions: submissions,
      );

      if (!mounted ||
          generation != _loadGeneration ||
          _selectedCourseId != courseId) {
        return;
      }

      setState(() {
        _analytics = analytics;
        _isLoadingAnalytics = false;
        _errorMessage = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingAnalytics = false;

        _errorMessage = e.message ?? 'Unable to load course analytics.';
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingAnalytics = false;

        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // BUILD ANALYTICS FROM FIRESTORE DATA
  // ============================================================

  _InstructorAnalyticsData _buildAnalytics({
    required Map<String, dynamic> course,
    required List<Map<String, dynamic>> enrollments,
    required Map<String, Map<String, dynamic>> studentProfiles,
    required List<Map<String, dynamic>> modules,
    required List<Map<String, dynamic>> progressRecords,
    required List<Map<String, dynamic>> assessments,
    required Map<String, Map<String, dynamic>> assessmentById,
    required List<Map<String, dynamic>> submissions,
  }) {
    final DateTime now = DateTime.now();

    final Set<String> studentIds = enrollments
        .map((enrollment) => (enrollment['studentId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    // ------------------------------------------------------------
    // CLASS AVERAGE
    // ------------------------------------------------------------

    final List<double> scoredSubmissionPercentages = [];

    for (final submission in submissions) {
      final double? percentage = _submissionPercentage(
        submission,
        assessmentById: assessmentById,
      );

      if (percentage != null) {
        scoredSubmissionPercentages.add(percentage);
      }
    }

    final double? classAverage = scoredSubmissionPercentages.isEmpty
        ? null
        : scoredSubmissionPercentages.reduce((double a, double b) => a + b) /
              scoredSubmissionPercentages.length;

    // ------------------------------------------------------------
    // ACTIVE TODAY
    // ------------------------------------------------------------

    int activeToday = 0;

    for (final String studentId in studentIds) {
      final DateTime? lastLogin = _dateFrom(
        studentProfiles[studentId]?['lastLoginAt'],
      );

      if (lastLogin != null && _isSameLocalDay(lastLogin, now)) {
        activeToday++;
      }
    }

    // ------------------------------------------------------------
    // MODULE ENGAGEMENT
    // ------------------------------------------------------------

    final List<_ModuleEngagement> moduleEngagement = [];

    final Map<String, Map<String, double>> progressByModuleAndStudent = {};

    for (final progress in progressRecords) {
      final String moduleId = (progress['moduleId'] ?? '').toString().trim();

      final String studentId = (progress['studentId'] ?? '').toString().trim();

      if (moduleId.isEmpty || studentId.isEmpty) {
        continue;
      }

      final double percentage = _progressPercentage(progress);

      final Map<String, double> studentProgress = progressByModuleAndStudent
          .putIfAbsent(moduleId, () => {});

      final double existing = studentProgress[studentId] ?? 0;

      // If duplicate progress records exist, keep the highest
      // known value rather than lowering the student's progress.
      if (percentage > existing) {
        studentProgress[studentId] = percentage;
      }
    }

    for (final module in modules) {
      final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
          .toString()
          .trim();

      final Map<String, double> studentProgress =
          progressByModuleAndStudent[moduleId] ?? {};

      double total = 0;

      for (final String studentId in studentIds) {
        total += studentProgress[studentId] ?? 0;
      }

      final double engagement = studentIds.isEmpty
          ? 0
          : total / studentIds.length;

      moduleEngagement.add(
        _ModuleEngagement(
          moduleId: moduleId,
          title: _moduleTitle(module),
          order: _moduleOrder(module),
          percentage: engagement.clamp(0, 100).toDouble(),
        ),
      );
    }

    // ------------------------------------------------------------
    // WEAKEST QUIZ / ASSESSMENT TOPICS
    // ------------------------------------------------------------

    final Map<String, List<double>> percentagesByAssessment = {};

    for (final submission in submissions) {
      final String assessmentId = (submission['assessmentId'] ?? '')
          .toString()
          .trim();

      if (assessmentId.isEmpty) {
        continue;
      }

      final Map<String, dynamic>? assessment = assessmentById[assessmentId];

      if (assessment == null) {
        continue;
      }

      final String assessmentType =
          (assessment['assessmentType'] ?? assessment['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      final String deliveryType = (assessment['deliveryType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      // "Weakest Topics" is primarily quiz-based. AI-generated
      // assessments are also included because CASLMS AI quizzes
      // use deliveryType = ai_generated.
      final bool quizLike =
          assessmentType == 'quiz' || deliveryType == 'ai_generated';

      if (!quizLike) {
        continue;
      }

      final double? percentage = _submissionPercentage(
        submission,
        assessmentById: assessmentById,
      );

      if (percentage == null) {
        continue;
      }

      percentagesByAssessment
          .putIfAbsent(assessmentId, () => [])
          .add(percentage);
    }

    final List<_WeakTopic> weakTopics = [];

    for (final entry in percentagesByAssessment.entries) {
      if (entry.value.isEmpty) {
        continue;
      }

      final Map<String, dynamic>? assessment = assessmentById[entry.key];

      if (assessment == null) {
        continue;
      }

      final double average =
          entry.value.reduce((double a, double b) => a + b) /
          entry.value.length;

      final String topic =
          (assessment['topic'] ?? assessment['title'] ?? 'Assessment')
              .toString()
              .trim();

      weakTopics.add(
        _WeakTopic(
          assessmentId: entry.key,
          title: topic.isEmpty ? 'Assessment' : topic,
          averageScore: average.clamp(0, 100).toDouble(),
        ),
      );
    }

    weakTopics.sort(
      (_WeakTopic a, _WeakTopic b) => a.averageScore.compareTo(b.averageScore),
    );

    final List<_WeakTopic> weakestTopics = weakTopics.take(3).toList();

    // ------------------------------------------------------------
    // STUDENTS REQUIRING ATTENTION
    // ------------------------------------------------------------

    final Map<String, List<Map<String, dynamic>>> submissionsByStudent = {};

    for (final submission in submissions) {
      final String studentId = (submission['studentId'] ?? '')
          .toString()
          .trim();

      if (studentId.isEmpty) {
        continue;
      }

      submissionsByStudent.putIfAbsent(studentId, () => []).add(submission);
    }

    final Map<String, Map<String, double>> progressByStudentAndModule = {};

    for (final entry in progressByModuleAndStudent.entries) {
      final String moduleId = entry.key;

      for (final studentEntry in entry.value.entries) {
        progressByStudentAndModule.putIfAbsent(
          studentEntry.key,
          () => {},
        )[moduleId] = studentEntry.value;
      }
    }

    final Map<String, Map<String, dynamic>> enrollmentByStudent = {
      for (final enrollment in enrollments)
        (enrollment['studentId'] ?? '').toString().trim(): enrollment,
    };

    final Map<String, dynamic>? latestModule = modules.isEmpty
        ? null
        : modules.last;

    final String latestModuleId = latestModule == null
        ? ''
        : (latestModule['moduleId'] ?? latestModule['id'] ?? '')
              .toString()
              .trim();

    final bool latestModuleHasProgress =
        latestModuleId.isNotEmpty &&
        (progressByModuleAndStudent[latestModuleId]?.isNotEmpty ?? false);

    final List<_AtRiskStudent> atRiskStudents = [];

    for (final String studentId in studentIds) {
      final Map<String, dynamic> profile = studentProfiles[studentId] ?? {};

      final Map<String, dynamic> enrollment =
          enrollmentByStudent[studentId] ?? {};

      final String studentName = _studentName(
        profile: profile,
        enrollment: enrollment,
      );

      final List<String> reasons = [];

      int severity = 0;

      // ----------------------------------------------------------
      // INACTIVITY
      // ----------------------------------------------------------

      final DateTime? lastLogin = _dateFrom(profile['lastLoginAt']);

      if (lastLogin != null) {
        final int inactiveDays = now.difference(lastLogin).inDays;

        if (inactiveDays >= 5) {
          reasons.add('Inactive for $inactiveDays days.');

          severity += inactiveDays >= 10 ? 3 : 2;
        }
      } else {
        final DateTime? enrolledAt = _dateFrom(enrollment['enrolledAt']);

        if (enrolledAt != null) {
          final int enrolledDays = now.difference(enrolledAt).inDays;

          if (enrolledDays >= 7) {
            reasons.add('No recent login activity is recorded.');

            severity += 2;
          }
        }
      }

      // ----------------------------------------------------------
      // STUDENT ASSESSMENT AVERAGE
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> studentSubmissions =
          submissionsByStudent[studentId] ?? [];

      final List<double> studentScores = [];

      final Set<String> submittedAssessmentIds = {};

      for (final submission in studentSubmissions) {
        final String assessmentId = (submission['assessmentId'] ?? '')
            .toString()
            .trim();

        if (assessmentId.isNotEmpty) {
          submittedAssessmentIds.add(assessmentId);
        }

        final double? percentage = _submissionPercentage(
          submission,
          assessmentById: assessmentById,
        );

        if (percentage != null) {
          studentScores.add(percentage);
        }
      }

      if (studentScores.isNotEmpty) {
        final double studentAverage =
            studentScores.reduce((double a, double b) => a + b) /
            studentScores.length;

        if (studentAverage < 60) {
          reasons.add('Assessment average ${studentAverage.round()}%.');

          severity += studentAverage < 50 ? 3 : 2;
        }
      }

      // ----------------------------------------------------------
      // MISSED PAST-DUE ASSESSMENTS
      // ----------------------------------------------------------

      int missedAssessments = 0;

      for (final assessment in assessments) {
        final String status = (assessment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status != 'published' && status != 'closed') {
          continue;
        }

        final DateTime? dueAt = _dateFrom(assessment['dueAt']);

        if (dueAt == null || !now.isAfter(dueAt)) {
          continue;
        }

        final String assessmentId =
            (assessment['assessmentId'] ?? assessment['id'] ?? '')
                .toString()
                .trim();

        if (assessmentId.isNotEmpty &&
            !submittedAssessmentIds.contains(assessmentId)) {
          missedAssessments++;
        }
      }

      if (missedAssessments > 0) {
        reasons.add(
          missedAssessments == 1
              ? 'Missed 1 past-due assessment.'
              : 'Missed $missedAssessments past-due assessments.',
        );

        severity += missedAssessments >= 2 ? 3 : 2;
      }

      // ----------------------------------------------------------
      // CURRENT / LATEST MODULE PROGRESS
      // ----------------------------------------------------------

      if (latestModuleHasProgress && latestModuleId.isNotEmpty) {
        final double latestProgress =
            progressByStudentAndModule[studentId]?[latestModuleId] ?? 0;

        if (latestProgress < 50) {
          reasons.add('Latest module progress ${latestProgress.round()}%.');

          severity += latestProgress < 25 ? 2 : 1;
        }
      }

      if (reasons.isNotEmpty) {
        atRiskStudents.add(
          _AtRiskStudent(
            studentId: studentId,
            name: studentName,
            reasons: reasons,
            severity: severity,
          ),
        );
      }
    }

    atRiskStudents.sort((_AtRiskStudent a, _AtRiskStudent b) {
      final int severityCompare = b.severity.compareTo(a.severity);

      if (severityCompare != 0) {
        return severityCompare;
      }

      return a.name.compareTo(b.name);
    });

    return _InstructorAnalyticsData(
      courseId: _courseId(course),
      courseLabel: _courseLabel(course),
      totalStudents: studentIds.length,
      activeToday: activeToday,
      classAverage: classAverage,
      moduleEngagement: moduleEngagement,
      weakTopics: weakestTopics,
      atRiskStudents: atRiskStudents.take(5).toList(),
      gradedSubmissionCount: scoredSubmissionPercentages.length,
    );
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final String? courseId = _selectedCourseId;

    if (courseId == null || courseId.isEmpty) {
      await _loadCourses();

      return;
    }

    await _loadAnalytics(courseId);
  }

  // ============================================================
  // EXPORT / COPY CSV
  //
  // No extra Flutter package is required. The report is copied
  // to the clipboard and can be pasted into Excel/Google Sheets.
  // ============================================================

  Future<void> _exportReport() async {
    final _InstructorAnalyticsData? analytics = _analytics;

    if (analytics == null) {
      _showMessage('There is no analytics report to export yet.');

      return;
    }

    final StringBuffer csv = StringBuffer();

    csv.writeln('CASLMS Instructor Analytics Report');

    csv.writeln('Course,${_csv(analytics.courseLabel)}');

    csv.writeln('Total Students,${analytics.totalStudents}');

    csv.writeln('Active Today,${analytics.activeToday}');

    csv.writeln(
      'Class Average,${analytics.classAverage == null ? 'No graded data' : '${analytics.classAverage!.toStringAsFixed(1)}%'}',
    );

    csv.writeln('Graded Submissions,${analytics.gradedSubmissionCount}');

    csv.writeln();

    csv.writeln('Module Engagement');

    csv.writeln('Module,Engagement');

    for (final _ModuleEngagement module in analytics.moduleEngagement) {
      csv.writeln(
        '${_csv(_moduleDisplayLabel(module))},'
        '${module.percentage.toStringAsFixed(1)}%',
      );
    }

    csv.writeln();

    csv.writeln('Weakest Quiz Topics');

    csv.writeln('Topic,Average Score');

    for (final _WeakTopic topic in analytics.weakTopics) {
      csv.writeln(
        '${_csv(topic.title)},'
        '${topic.averageScore.toStringAsFixed(1)}%',
      );
    }

    csv.writeln();

    csv.writeln('Requires Attention');

    csv.writeln('Student,Reasons');

    for (final _AtRiskStudent student in analytics.atRiskStudents) {
      csv.writeln(
        '${_csv(student.name)},'
        '${_csv(student.reasons.join(' '))}',
      );
    }

    await Clipboard.setData(ClipboardData(text: csv.toString()));

    if (!mounted) {
      return;
    }

    _showMessage(
      'Analytics CSV copied to clipboard. Paste it into Excel or Google Sheets.',
    );
  }

  String _csv(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => instructorScaffold(
    loading: _isLoadingCourses,
    context: context,
    title: 'Class insights',
    subtitle: 'Understand engagement and where students need support.',
    actions: [
      IconButton(
        tooltip: 'Export CSV report',
        onPressed: _analytics == null ? null : _exportReport,
        icon: Icon(Icons.file_download_outlined),
      ),
      IconButton(
        tooltip: 'Refresh insights',
        onPressed: _isLoadingCourses || _isLoadingAnalytics ? null : _refresh,
        icon: Icon(Icons.refresh_rounded),
      ),
    ],
    body: _buildBody(),
  );

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoadingCourses) {
      return Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null && _courses.isEmpty) {
      return _buildFullPageError(_errorMessage!);
    }

    if (_courses.isEmpty) {
      return _buildNoCourses();
    }

    return RefreshIndicator(
      onRefresh: _refresh,

      color: primaryTeal,

      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),

        padding: EdgeInsets.fromLTRB(22, 16, 22, 40),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildCourseSelector(),

            SizedBox(height: 18),

            if (_errorMessage != null) _buildInlineError(_errorMessage!),

            if (_errorMessage != null) SizedBox(height: 16),

            if (_isLoadingAnalytics)
              _buildLoadingCard()
            else if (_analytics != null)
              _buildAnalyticsContent(_analytics!)
            else
              _buildEmptyAnalytics(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COURSE SELECTOR
  // ============================================================

  Widget _buildCourseSelector() {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor, width: 1.5),
      ),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCourseId,

          isExpanded: true,

          icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal),

          style: TextStyle(
            fontWeight: FontWeight.w700,

            color: textDark,

            fontSize: 13.5,
            fontFamily: 'Roboto',
          ),

          items: _courses.map((Map<String, dynamic> course) {
            final String courseId = _courseId(course);

            return DropdownMenuItem<String>(
              value: courseId,

              child: Text(
                _courseLabel(course),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),

          onChanged: _isLoadingAnalytics ? null : _changeCourse,
        ),
      ),
    );
  }

  // ============================================================
  // ANALYTICS CONTENT
  // ============================================================

  Widget _buildAnalyticsContent(_InstructorAnalyticsData analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        // --------------------------------------------------------
        // OVERVIEW
        // --------------------------------------------------------

        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 460;

            if (compact) {
              return Column(
                children: [
                  _buildStatCard(
                    title: 'Class Average',
                    value: analytics.classAverage == null
                        ? '—'
                        : '${analytics.classAverage!.round()}%',
                    subtitle: analytics.gradedSubmissionCount == 0
                        ? 'No graded submissions yet'
                        : '${analytics.gradedSubmissionCount} graded submission${analytics.gradedSubmissionCount == 1 ? '' : 's'}',
                    icon: Icons.grading_rounded,
                    color: blue,
                  ),

                  SizedBox(height: 12),

                  _buildStatCard(
                    title: 'Active Today',
                    value:
                        '${analytics.activeToday}/${analytics.totalStudents}',
                    subtitle: analytics.totalStudents == 0
                        ? 'No enrolled students'
                        : 'Based on student login activity',
                    icon: Icons.people_alt_rounded,
                    color: primaryTeal,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Class Average',
                    value: analytics.classAverage == null
                        ? '—'
                        : '${analytics.classAverage!.round()}%',
                    subtitle: analytics.gradedSubmissionCount == 0
                        ? 'No graded submissions yet'
                        : '${analytics.gradedSubmissionCount} graded submission${analytics.gradedSubmissionCount == 1 ? '' : 's'}',
                    icon: Icons.grading_rounded,
                    color: blue,
                  ),
                ),

                SizedBox(width: 14),

                Expanded(
                  child: _buildStatCard(
                    title: 'Active Today',
                    value:
                        '${analytics.activeToday}/${analytics.totalStudents}',
                    subtitle: analytics.totalStudents == 0
                        ? 'No enrolled students'
                        : 'Based on student login activity',
                    icon: Icons.people_alt_rounded,
                    color: primaryTeal,
                  ),
                ),
              ],
            );
          },
        ),

        SizedBox(height: 28),

        // --------------------------------------------------------
        // REQUIRES ATTENTION
        // --------------------------------------------------------
        InstructorTiles(
          minWidth: 400,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Needs attention'),
                SizedBox(height: 13),
                _buildAtRiskCard(analytics),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('Module engagement'),
                SizedBox(height: 13),
                _buildEngagementCard(analytics),
              ],
            ),
          ],
        ),
        SizedBox(height: 28),
        // --------------------------------------------------------
        // WEAKEST TOPICS
        // --------------------------------------------------------
        _buildSectionTitle('Weakest Topics (Based on Quizzes)'),

        SizedBox(height: 13),

        if (analytics.weakTopics.isEmpty)
          _buildSmallEmptyCard(
            icon: Icons.insights_outlined,
            title: 'No quiz analytics yet',
            message: 'Weakest topics will appear after students complete graded quizzes.',
          )
        else
          ...analytics.weakTopics.asMap().entries.map((
            MapEntry<int, _WeakTopic> entry,
          ) {
            return _buildTopicWeaknessItem(entry.value, entry.key);
          }),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(18),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: color, size: 22),
          ),

          SizedBox(height: 14),

          Text(
            value,

            style: TextStyle(
              fontSize: 24,

              fontWeight: FontWeight.w700,

              color: color,
            ),
          ),

          SizedBox(height: 4),

          Text(
            title,

            style: TextStyle(
              fontSize: 12,

              fontWeight: FontWeight.w700,

              color: textDark,
            ),
          ),

          SizedBox(height: 3),

          Text(
            subtitle,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 10.5, height: 1.35, color: textGrey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIRES ATTENTION CARD
  // ============================================================

  Widget _buildAtRiskCard(_InstructorAnalyticsData analytics) {
    final List<_AtRiskStudent> students = analytics.atRiskStudents;

    if (analytics.totalStudents == 0) {
      return _buildSmallEmptyCard(
        icon: Icons.groups_outlined,
        title: 'No enrolled students',
        message: 'Analytics will appear after students join this class.',
      );
    }

    if (students.isEmpty) {
      return Container(
        width: double.infinity,

        padding: EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: green.withValues(alpha: 0.30), width: 1.5),
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Icon(Icons.check_circle_outline_rounded, color: green, size: 22),

            SizedBox(width: 11),

            Expanded(
              child: Text(
                'No students currently meet the CASLMS attention rules for inactivity, low scores, missed assessments, or low module progress.',

                style: TextStyle(
                  color: textDark,

                  fontSize: 12.5,

                  height: 1.45,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: red.withValues(alpha: 0.30), width: 1.5),
      ),

      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                padding: EdgeInsets.all(8),

                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(Icons.warning_rounded, color: red, size: 20),
              ),

              SizedBox(width: 11),

              Expanded(
                child: Text(
                  'CASLMS identified ${students.length} student${students.length == 1 ? '' : 's'} who may need attention.',

                  style: TextStyle(
                    fontSize: 12.5,

                    height: 1.4,

                    fontWeight: FontWeight.w700,

                    color: textDark,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),

            child: Divider(height: 1, thickness: 1, color: borderColor),
          ),

          ...students.asMap().entries.map((
            MapEntry<int, _AtRiskStudent> entry,
          ) {
            return Column(
              children: [
                _buildAtRiskStudent(entry.value),

                if (entry.key != students.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 11),

                    child: Divider(height: 1, color: borderColor),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAtRiskStudent(_AtRiskStudent student) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        CircleAvatar(
          radius: 16,

          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,

          child: Text(
            _initial(student.name),

            style: TextStyle(
              fontSize: 11.5,

              fontWeight: FontWeight.w700,

              color: textDark,
            ),
          ),
        ),

        SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                student.name,

                style: TextStyle(
                  fontWeight: FontWeight.w700,

                  fontSize: 13,

                  color: textDark,
                ),
              ),

              SizedBox(height: 3),

              Text(
                student.reasons.join(' '),

                style: TextStyle(
                  fontSize: 10.8,

                  height: 1.4,

                  color: red,

                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 8),

        TextButton(
          onPressed: () {
            _showAttentionDetails(student);
          },

          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),

            minimumSize: Size(0, 32),

            tapTargetSize: MaterialTapTargetSize.shrinkWrap,

            backgroundColor: blue.withValues(alpha: 0.09),

            foregroundColor: AppColors.resolve(context, AppColors.link),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          child: Text(
            'View',

            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MODULE ENGAGEMENT
  // ============================================================

  Widget _buildEngagementCard(_InstructorAnalyticsData analytics) {
    if (analytics.moduleEngagement.isEmpty) {
      return _buildSmallEmptyCard(
        icon: Icons.menu_book_outlined,
        title: 'No published modules',
        message: 'Publish modules to begin tracking student engagement.',
      );
    }

    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(18),

      decoration: _cardDecoration(),

      child: Column(
        children: analytics.moduleEngagement.asMap().entries.expand((
          MapEntry<int, _ModuleEngagement> entry,
        ) sync* {
          if (entry.key > 0) {
            yield SizedBox(height: 16);
          }

          yield _buildEngagementBar(entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildEngagementBar(_ModuleEngagement module) {
    final Color color = module.percentage < 50 ? orange : primaryTeal;

    return Row(
      children: [
        SizedBox(
          width: 105,

          child: Text(
            _moduleDisplayLabel(module),

            style: TextStyle(
              fontSize: 11.3,

              fontWeight: FontWeight.w700,

              color: textDark,
            ),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,
          ),
        ),

        SizedBox(width: 10),

        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: LinearProgressIndicator(
              value: (module.percentage / 100).clamp(0, 1).toDouble(),

              backgroundColor: borderColor,

              valueColor: AlwaysStoppedAnimation<Color>(color),

              minHeight: 14,
            ),
          ),
        ),

        SizedBox(width: 10),

        SizedBox(
          width: 42,

          child: Text(
            '${module.percentage.round()}%',

            style: TextStyle(
              fontSize: 11.5,

              fontWeight: FontWeight.w700,

              color: color,
            ),

            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WEAKEST TOPICS
  // ============================================================

  Widget _buildTopicWeaknessItem(_WeakTopic topic, int index) {
    final Color color = index == 0
        ? red
        : index == 1
        ? orange
        : Color(0xFFD6A000);

    return Container(
      width: double.infinity,

      margin: EdgeInsets.only(bottom: 11),

      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 14),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.5),
      ),

      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: color, size: 18),

          SizedBox(width: 11),

          Expanded(
            child: Text(
              topic.title,

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                fontWeight: FontWeight.w700,

                fontSize: 12.5,

                color: textDark,
              ),
            ),
          ),

          SizedBox(width: 10),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(8),
            ),

            child: Text(
              'Avg: ${topic.averageScore.round()}%',

              style: TextStyle(
                color: color,

                fontWeight: FontWeight.w700,

                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAILS DIALOG
  // ============================================================

  Future<void> _showAttentionDetails(_AtRiskStudent student) async {
    await showDialog<void>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(student.name),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Reasons this student may need attention:',

                style: TextStyle(fontWeight: FontWeight.w700),
              ),

              SizedBox(height: 10),

              ...student.reasons.map(
                (String reason) => Padding(
                  padding: EdgeInsets.only(bottom: 7),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 5),

                        child: Icon(Icons.circle, size: 6, color: red),
                      ),

                      SizedBox(width: 8),

                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ERROR / EMPTY / LOADING UI
  // ============================================================

  Widget _buildFullPageError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.error_outline_rounded, color: red, size: 52),

            SizedBox(height: 14),

            Text(
              message,

              textAlign: TextAlign.center,

              style: TextStyle(color: textGrey, fontSize: 13, height: 1.45),
            ),

            SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: () {
                _loadCourses(keepSelectedCourse: true);
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,

                foregroundColor: Colors.white,
              ),

              icon: Icon(Icons.refresh_rounded),

              label: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.07),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: red.withValues(alpha: 0.20)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.error_outline_rounded, color: red, size: 19),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              message,

              style: TextStyle(color: textDark, fontSize: 11.5, height: 1.4),
            ),
          ),

          IconButton(
            onPressed: _refresh,

            visualDensity: VisualDensity.compact,

            icon: Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCourses() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              width: 68,

              height: 68,

              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.08),

                borderRadius: BorderRadius.circular(20),
              ),

              child: Icon(
                Icons.analytics_outlined,

                color: primaryTeal,

                size: 32,
              ),
            ),

            SizedBox(height: 15),

            Text(
              'No active classes',

              style: TextStyle(
                color: textDark,

                fontSize: 16,

                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 6),

            Text(
              'Create or activate a class before viewing cohort analytics.',

              textAlign: TextAlign.center,

              style: TextStyle(color: textGrey, fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.symmetric(vertical: 55),

      decoration: _cardDecoration(),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          CircularProgressIndicator(color: primaryTeal),

          SizedBox(height: 13),

          Text(
            'Calculating class analytics...',

            style: TextStyle(color: textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAnalytics() {
    return _buildSmallEmptyCard(
      icon: Icons.analytics_outlined,
      title: 'No analytics available',
      message: 'Pull down to refresh the selected class.',
    );
  }

  Widget _buildSmallEmptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(22),

      decoration: _cardDecoration(),

      child: Column(
        children: [
          Icon(icon, color: textGrey, size: 28),

          SizedBox(height: 9),

          Text(
            title,

            textAlign: TextAlign.center,

            style: TextStyle(
              color: textDark,

              fontSize: 13,

              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 4),

          Text(
            message,

            textAlign: TextAlign.center,

            style: TextStyle(color: textGrey, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,

      style: TextStyle(
        fontSize: 17,

        fontWeight: FontWeight.w700,

        color: textDark,

        letterSpacing: -0.25,
      ),
    );
  }

  // ============================================================
  // GENERIC HELPERS
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,

      borderRadius: BorderRadius.circular(18),

      border: Border.all(color: borderColor, width: 1.5),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: primaryTeal,

        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic>? _courseById(String courseId) {
    for (final course in _courses) {
      if (_courseId(course) == courseId) {
        return course;
      }
    }

    return null;
  }

  String _courseId(Map<String, dynamic> course) {
    return (course['courseId'] ?? course['id'] ?? '').toString().trim();
  }

  String _courseLabel(Map<String, dynamic> course) {
    final String title = (course['title'] ?? course['name'] ?? 'Course')
        .toString()
        .trim();

    final String code = (course['code'] ?? '').toString().trim();

    final String section =
        (course['section'] ?? course['classSection'] ?? course['block'] ?? '')
            .toString()
            .trim();

    if (section.isNotEmpty) {
      return '$title - $section';
    }

    if (code.isNotEmpty) {
      return '$code • $title';
    }

    return title.isEmpty ? 'Course' : title;
  }

  String _studentName({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> enrollment,
  }) {
    final String name =
        (profile['name'] ??
                profile['displayName'] ??
                enrollment['studentName'] ??
                '')
            .toString()
            .trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'Student';
  }

  String _initial(String name) {
    final String clean = name.trim();

    if (clean.isEmpty) {
      return '?';
    }

    return clean[0].toUpperCase();
  }

  int _moduleOrder(Map<String, dynamic> module) {
    return (module['order'] ?? module['moduleOrder'] ?? module['number']) is num
        ? ((module['order'] ?? module['moduleOrder'] ?? module['number'])
                  as num)
              .toInt()
        : 0;
  }

  String _moduleTitle(Map<String, dynamic> module) {
    final String title = (module['title'] ?? module['name'] ?? 'Module')
        .toString()
        .trim();

    return title.isEmpty ? 'Module' : title;
  }

  String _moduleDisplayLabel(_ModuleEngagement module) {
    if (module.order > 0) {
      return 'Mod ${module.order}: ${module.title}';
    }

    return module.title;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return null;
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final DateTime first = a.toLocal();

    final DateTime second = b.toLocal();

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  double _progressPercentage(Map<String, dynamic> progress) {
    final List<dynamic> possibleValues = [
      progress['completionPercentage'],
      progress['percentage'],
      progress['progressPercent'],
      progress['progress'],
    ];

    for (final dynamic value in possibleValues) {
      if (value is! num) {
        continue;
      }

      double number = value.toDouble();

      if (number >= 0 && number <= 1) {
        number *= 100;
      }

      return number.clamp(0, 100).toDouble();
    }

    if (progress['completed'] == true || progress['isCompleted'] == true) {
      return 100;
    }

    final String status = (progress['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (status == 'completed' || status == 'complete') {
      return 100;
    }

    if (status == 'in_progress' ||
        status == 'in-progress' ||
        status == 'started') {
      // If the schema only tells us the learner started the
      // module but provides no percentage, use a conservative
      // partial-engagement value.
      return 25;
    }

    return 0;
  }

  double? _submissionPercentage(
    Map<String, dynamic> submission, {
    required Map<String, Map<String, dynamic>> assessmentById,
  }) {
    final dynamic directPercentage = submission['percentage'];

    if (directPercentage is num) {
      return directPercentage.toDouble().clamp(0, 100).toDouble();
    }

    final num? score = submission['score'] as num?;

    if (score == null) {
      return null;
    }

    num? totalPoints = submission['totalPoints'] as num?;

    final String assessmentId = (submission['assessmentId'] ?? '')
        .toString()
        .trim();

    totalPoints ??= assessmentById[assessmentId]?['totalPoints'] as num?;

    if (totalPoints == null || totalPoints <= 0) {
      return null;
    }

    return ((score.toDouble() / totalPoints.toDouble()) * 100)
        .clamp(0, 100)
        .toDouble();
  }
}

// ============================================================
// ANALYTICS MODELS
// ============================================================

class _InstructorAnalyticsData {
  const _InstructorAnalyticsData({
    required this.courseId,
    required this.courseLabel,
    required this.totalStudents,
    required this.activeToday,
    required this.classAverage,
    required this.moduleEngagement,
    required this.weakTopics,
    required this.atRiskStudents,
    required this.gradedSubmissionCount,
  });

  final String courseId;
  final String courseLabel;

  final int totalStudents;
  final int activeToday;
  final int gradedSubmissionCount;

  final double? classAverage;

  final List<_ModuleEngagement> moduleEngagement;

  final List<_WeakTopic> weakTopics;

  final List<_AtRiskStudent> atRiskStudents;
}

class _ModuleEngagement {
  const _ModuleEngagement({
    required this.moduleId,
    required this.title,
    required this.order,
    required this.percentage,
  });

  final String moduleId;
  final String title;
  final int order;
  final double percentage;
}

class _WeakTopic {
  const _WeakTopic({
    required this.assessmentId,
    required this.title,
    required this.averageScore,
  });

  final String assessmentId;
  final String title;
  final double averageScore;
}

class _AtRiskStudent {
  const _AtRiskStudent({
    required this.studentId,
    required this.name,
    required this.reasons,
    required this.severity,
  });

  final String studentId;
  final String name;
  final List<String> reasons;
  final int severity;
}
