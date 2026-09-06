import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import 'instructor_chat_page.dart';
import 'instructor_module_builder_page.dart';
import 'instructor_module_detail_page.dart';

class InstructorClassDetailsScreen extends StatefulWidget {
  // ============================================================
  // DYNAMIC COURSE PARAMETERS
  // ============================================================

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String classCode;
  final String instructorName;

  // ============================================================
  // LEGACY PARAMETERS
  //
  // Kept so older pages using:
  //
  // InstructorClassDetailsScreen(
  //   title: ...,
  //   section: ...,
  // )
  //
  // will still compile.
  // ============================================================

  final String title;
  final String section;

  final int? studentCount;
  final Map<String, dynamic>? course;

  const InstructorClassDetailsScreen({
    super.key,
    this.courseId = '',
    this.courseCode = '',
    this.courseTitle = '',
    this.classCode = '',
    this.instructorName = '',
    this.title = '',
    this.section = '',
    this.studentCount,
    this.course,
  });

  @override
  State<InstructorClassDetailsScreen> createState() =>
      _InstructorClassDetailsScreenState();
}

class _InstructorClassDetailsScreenState
    extends State<InstructorClassDetailsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  static const Color red = Color(0xFFFF4B4B);
  static const Color orange = Color(0xFFFF9418);
  static const Color green = Color(0xFF26A65B);

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  int _selectedTab = 1;

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _course;

  List<Map<String, dynamic>> _modules = [];

  List<Map<String, dynamic>> _students = [];

  List<Map<String, dynamic>> _assessments = [];

  List<Map<String, dynamic>> _assessmentSubmissions = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadCourseData();
  }

  // ============================================================
  // RESOLVE REAL COURSE ID
  // ============================================================

  Future<String> _resolveCourseId() async {
    // Preferred source.
    final String directId = widget.courseId.trim();

    if (directId.isNotEmpty) {
      return directId;
    }

    // Course Map fallback.
    final String mapId =
        (widget.course?['courseId'] ?? widget.course?['id'] ?? '')
            .toString()
            .trim();

    if (mapId.isNotEmpty) {
      return mapId;
    }

    // Compatibility fallback for older screens.
    final String? instructorId = _auth.currentUser?.uid;

    if (instructorId == null || instructorId.isEmpty) {
      throw Exception('You must be logged in as an instructor.');
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('courses')
        .where('instructorId', isEqualTo: instructorId)
        .get();

    final String requestedCode = widget.courseCode.trim().toLowerCase();

    final String requestedTitle =
        (widget.courseTitle.trim().isNotEmpty
                ? widget.courseTitle
                : widget.title)
            .trim()
            .toLowerCase();

    for (final document in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String code = (data['code'] ?? '').toString().trim().toLowerCase();

      final String title = (data['title'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (requestedCode.isNotEmpty && code == requestedCode) {
        return document.id;
      }

      if (requestedTitle.isNotEmpty && title == requestedTitle) {
        return document.id;
      }
    }

    throw Exception('The selected course could not be found in Firestore.');
  }

  // ============================================================
  // LOAD COURSE
  // ============================================================

  Future<void> _loadCourseData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final String? instructorId = _auth.currentUser?.uid;

      if (instructorId == null || instructorId.isEmpty) {
        throw Exception('No instructor is currently logged in.');
      }

      final String courseId = await _resolveCourseId();

      // ========================================================
      // COURSE
      // ========================================================

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await _firestore.collection('courses').doc(courseId).get();

      if (!courseDocument.exists || courseDocument.data() == null) {
        throw Exception('Course could not be found.');
      }

      final Map<String, dynamic> courseData = courseDocument.data()!;

      final String ownerId = (courseData['instructorId'] ?? '')
          .toString()
          .trim();

      if (ownerId != instructorId) {
        throw Exception('You can only manage your own courses.');
      }

      // ========================================================
      // MODULES
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> moduleSnapshot =
          await _firestore
              .collection('modules')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> modules = moduleSnapshot.docs
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'moduleId': document.id,
            },
          )
          .toList();

      modules.sort((a, b) {
        final int aOrder = (a['order'] as num?)?.toInt() ?? 0;

        final int bOrder = (b['order'] as num?)?.toInt() ?? 0;

        return aOrder.compareTo(bOrder);
      });

      // ========================================================
      // ENROLLMENTS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> enrollmentSnapshot =
          await _firestore
              .collection('enrollments')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> students = [];

      for (final enrollmentDocument in enrollmentSnapshot.docs) {
        final Map<String, dynamic> enrollment = enrollmentDocument.data();

        final String enrollmentStatus = (enrollment['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (enrollmentStatus != 'active') {
          continue;
        }

        final String studentId = (enrollment['studentId'] ?? '')
            .toString()
            .trim();

        if (studentId.isEmpty) {
          continue;
        }

        Map<String, dynamic>? userData;

        try {
          final DocumentSnapshot<Map<String, dynamic>> userDocument =
              await _firestore.collection('users').doc(studentId).get();

          userData = userDocument.data();
        } catch (_) {
          userData = null;
        }

        students.add({
          ...enrollment,
          if (userData != null) ...userData,
          'studentId': studentId,
          'enrollmentId': enrollmentDocument.id,
        });
      }

      students.sort((a, b) {
        final String aName = (a['name'] ?? a['studentName'] ?? '')
            .toString()
            .toLowerCase();

        final String bName = (b['name'] ?? b['studentName'] ?? '')
            .toString()
            .toLowerCase();

        return aName.compareTo(bName);
      });

      // ========================================================
      // EXTERNAL ASSESSMENTS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> assessmentSnapshot =
          await _firestore
              .collection('assessments')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> assessments = assessmentSnapshot.docs
          .map(
            (document) => {
              ...document.data(),
              'id': document.id,
              'assessmentId': document.id,
            },
          )
          .toList();

      // ========================================================
      // EXTERNAL ASSESSMENT SUBMISSIONS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> submissionSnapshot =
          await _firestore
              .collection('assessmentSubmissions')
              .where('courseId', isEqualTo: courseId)
              .get();

      final List<Map<String, dynamic>> assessmentSubmissions =
          submissionSnapshot.docs
              .map(
                (document) => {
                  ...document.data(),
                  'id': document.id,
                  'submissionId': document.id,
                },
              )
              .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _course = {
          ...courseData,
          'id': courseDocument.id,
          'courseId': courseDocument.id,
        };

        _modules = modules;

        _students = students;

        _assessments = assessments;

        _assessmentSubmissions = assessmentSubmissions;

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
  // DYNAMIC VALUES
  // ============================================================

  String get _courseId {
    return (_course?['courseId'] ?? _course?['id'] ?? widget.courseId)
        .toString()
        .trim();
  }

  String get _courseCode {
    return (_course?['code'] ?? widget.courseCode).toString().trim();
  }

  String get _courseTitle {
    return (_course?['title'] ??
            (widget.courseTitle.isNotEmpty ? widget.courseTitle : widget.title))
        .toString()
        .trim();
  }

  String get _classCode {
    return (_course?['classCode'] ??
            (widget.classCode.isNotEmpty ? widget.classCode : widget.section))
        .toString()
        .trim();
  }

  String get _semester {
    return (_course?['semester'] ?? '').toString().trim();
  }

  String get _academicYear {
    return (_course?['academicYear'] ?? '').toString().trim();
  }

  String get _courseDescription {
    return (_course?['description'] ?? '').toString().trim();
  }

  // ============================================================
  // FIX: DYNAMIC INSTRUCTOR NAME
  // ============================================================

  String get _instructorName {
    return (_course?['instructorName'] ?? widget.instructorName)
        .toString()
        .trim();
  }

  String get _courseStatus {
    return (_course?['status'] ?? '').toString().trim().toLowerCase();
  }

  // ============================================================
  // CREATE MODULE
  // ============================================================

  Future<void> _createModule() async {
    if (_courseId.isEmpty) {
      _showError('Course information is missing.');

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorModuleBuilderScreen(
          courseId: _courseId,
          courseCode: _courseCode,
          courseTitle: _courseTitle,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadCourseData();
  }

  // ============================================================
  // OPEN MODULE MANAGEMENT
  // ============================================================

  Future<void> _openModule(Map<String, dynamic> module) async {
    final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
        .toString()
        .trim();

    if (moduleId.isEmpty || _courseId.isEmpty) {
      _showError(
        'Unable to open this module because its ID information is missing.',
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorModuleDetailScreen(
          courseId: _courseId,
          moduleId: moduleId,
          courseCode: _courseCode,
          courseTitle: _courseTitle,
          moduleTitle: (module['title'] ?? '').toString(),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadCourseData();
  }

  // ============================================================
  // OPEN STUDENT CHAT
  // ============================================================

  Future<void> _openStudentChat(Map<String, dynamic> student) async {
    final String studentId = (student['studentId'] ?? student['uid'] ?? '')
        .toString()
        .trim();

    final String studentName = (student['name'] ?? student['studentName'] ?? '')
        .toString()
        .trim();

    final String studentEmail = (student['email'] ?? '').toString().trim();

    final String? instructorId = _auth.currentUser?.uid;

    if (studentId.isEmpty) {
      _showError('Student ID is missing.');

      return;
    }

    if (instructorId == null || instructorId.isEmpty) {
      _showError('Instructor account information is missing.');

      return;
    }

    if (_courseId.isEmpty) {
      _showError('Course information is missing.');

      return;
    }

    if (_instructorName.isEmpty) {
      _showError('Instructor name is missing.');

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorChatScreen(
          // Required by current dynamic chat.
          courseId: _courseId,
          instructorId: instructorId,
          instructorName: _instructorName,
          studentId: studentId,

          studentName: studentName.isEmpty ? studentEmail : studentName,

          studentEmail: studentEmail,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR MESSAGE
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
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textDark,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _courseTitle.isEmpty ? 'Course' : _courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              '${_students.length} enrolled',
              style: const TextStyle(
                fontSize: 11,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCourseData,
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),

          const SizedBox(width: 6),
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

    return Column(
      children: [
        // ======================================================
        // COURSE HEADER
        // ======================================================

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: _buildCourseHeader(),
        ),

        // ======================================================
        // TABS
        // ======================================================
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(maxWidth: 650),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEFF3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(child: _buildSegmentTab('Roster', 0)),
              Expanded(child: _buildSegmentTab('Modules', 1)),
              Expanded(child: _buildSegmentTab('Grades', 2)),
              Expanded(child: _buildSegmentTab('Settings', 3)),
            ],
          ),
        ),

        // ======================================================
        // SELECTED TAB
        // ======================================================
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCourseData,
            color: primaryTeal,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              children: [_buildSelectedTabContent()],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COURSE HEADER
  // ============================================================

  Widget _buildCourseHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_courseCode.isNotEmpty)
                  Text(
                    _courseCode,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),

                if (_courseCode.isNotEmpty) const SizedBox(height: 4),

                Text(
                  _courseTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (_courseDescription.isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Text(
                    _courseDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (_classCode.isNotEmpty)
                      _buildHeaderChip(Icons.key_rounded, _classCode),

                    if (_semester.isNotEmpty)
                      _buildHeaderChip(
                        Icons.calendar_today_outlined,
                        _semester,
                      ),

                    if (_academicYear.isNotEmpty)
                      _buildHeaderChip(Icons.school_outlined, _academicYear),

                    _buildHeaderChip(
                      Icons.people_alt_outlined,
                      '${_students.length} students',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildSegmentTab(String title, int index) {
    final bool selected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? primaryTeal : textGrey,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildRosterContent();

      case 1:
        return _buildModulesContent();

      case 2:
        return _buildGradesContent();

      case 3:
        return _buildSettingsContent();

      default:
        return _buildModulesContent();
    }
  }

  // ============================================================
  // ROSTER
  // ============================================================

  Widget _buildRosterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Roster',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Students currently enrolled in this course.',
                    style: TextStyle(color: textGrey, fontSize: 11.5),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_students.length}',
                style: const TextStyle(
                  color: primaryTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_students.isEmpty)
          _buildEmptyState(
            icon: Icons.group_outlined,
            title: 'No students enrolled',
            message: 'Students who join this class will appear here.',
          )
        else
          ..._students.map(_buildStudentCard),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final String name = (student['name'] ?? student['studentName'] ?? '')
        .toString()
        .trim();

    final String email = (student['email'] ?? '').toString().trim();

    final String universityId = (student['universityId'] ?? '')
        .toString()
        .trim();

    final String displayName = name.isNotEmpty ? name : universityId;

    final String initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: primaryTeal.withValues(alpha: 0.10),
            child: Text(
              initial,
              style: const TextStyle(
                color: primaryTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : email,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),

                  Text(
                    email,
                    style: const TextStyle(color: textGrey, fontSize: 10.5),
                  ),
                ],

                if (universityId.isNotEmpty) ...[
                  const SizedBox(height: 2),

                  Text(
                    universityId,
                    style: const TextStyle(color: textGrey, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),

          IconButton(
            tooltip: 'Message student',
            onPressed: () {
              _openStudentChat(student);
            },
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: primaryTeal,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODULES
  // ============================================================

  Widget _buildModulesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course Modules',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Open a module to manage its assessments.',
                    style: TextStyle(color: textGrey, fontSize: 11.5),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            ElevatedButton.icon(
              onPressed: _createModule,
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Add Module',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_modules.isEmpty)
          _buildEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No modules yet',
            message: 'Create the first module for this course.',
          )
        else
          ..._modules.map(_buildModuleCard),
      ],
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module) {
    final String title = (module['title'] ?? '').toString().trim();

    final String description = (module['description'] ?? '').toString().trim();

    final String status = (module['status'] ?? 'draft')
        .toString()
        .trim()
        .toLowerCase();

    final int order = (module['order'] as num?)?.toInt() ?? 0;

    final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
        .toString();

    final int assessmentCount = _assessments.where((assessment) {
      return (assessment['moduleId'] ?? '').toString() == moduleId;
    }).length;

    final bool published = status == 'published';

    final Color statusColor = published ? green : orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _openModule(module);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryTeal.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: primaryTeal,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order > 0)
                        Text(
                          'MODULE $order',
                          style: const TextStyle(
                            color: primaryTeal,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),

                      if (order > 0) const SizedBox(height: 3),

                      Text(
                        title,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),

                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textGrey,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ],

                      const SizedBox(height: 7),

                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          _buildSmallBadge(
                            text:
                                '$assessmentCount assessment${assessmentCount == 1 ? '' : 's'}',
                            color: primaryTeal,
                          ),
                          _buildSmallBadge(
                            text: status.toUpperCase(),
                            color: statusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9BA4B4),
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // GRADES
  // ============================================================

  Widget _buildGradesContent() {
    final int submitted = _assessmentSubmissions.where((submission) {
      final String status = (submission['status'] ?? '')
          .toString()
          .toLowerCase();

      return status == 'submitted';
    }).length;

    final int graded = _assessmentSubmissions.where((submission) {
      return (submission['status'] ?? '').toString().toLowerCase() == 'graded';
    }).length;

    final int published = _assessments.where((assessment) {
      return (assessment['status'] ?? '').toString().toLowerCase() ==
          'published';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assessment Grading',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'External assessment submissions and grades.',
          style: TextStyle(color: textGrey, fontSize: 11.5),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Published',
                value: '$published',
                icon: Icons.assignment_turned_in_outlined,
                color: primaryTeal,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildStatCard(
                title: 'To Grade',
                value: '$submitted',
                icon: Icons.pending_actions_rounded,
                color: orange,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _buildStatCard(
                title: 'Graded',
                value: '$graded',
                icon: Icons.verified_outlined,
                color: green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        if (_assessmentSubmissions.isEmpty)
          _buildEmptyState(
            icon: Icons.grade_outlined,
            title: 'No assessment submissions yet',
            message: 'Student submissions will appear here after the student external-assessment workflow is connected.',
          )
        else
          ..._assessmentSubmissions.map(_buildSubmissionCard),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textGrey, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final String studentName = (submission['studentName'] ?? '').toString();

    final String status = (submission['status'] ?? 'submitted')
        .toString()
        .toLowerCase();

    final dynamic score = submission['score'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            status == 'graded'
                ? Icons.check_circle_outline_rounded
                : Icons.pending_actions_rounded,
            color: status == 'graded' ? green : orange,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              studentName,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Text(
            score is num ? '$score' : status.toUpperCase(),
            style: TextStyle(
              color: status == 'graded' ? green : orange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Information',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'Current information stored in Firestore.',
          style: TextStyle(color: textGrey, fontSize: 11.5),
        ),

        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.tag_rounded,
                title: 'Course Code',
                value: _courseCode,
              ),

              const Divider(height: 1, color: borderColor),

              _buildSettingTile(
                icon: Icons.key_rounded,
                title: 'Class Code',
                value: _classCode,
              ),

              const Divider(height: 1, color: borderColor),

              _buildSettingTile(
                icon: Icons.person_outline_rounded,
                title: 'Instructor',
                value: _instructorName,
              ),

              const Divider(height: 1, color: borderColor),

              _buildSettingTile(
                icon: Icons.calendar_today_outlined,
                title: 'Semester',
                value: _semester,
              ),

              const Divider(height: 1, color: borderColor),

              _buildSettingTile(
                icon: Icons.school_outlined,
                title: 'Academic Year',
                value: _academicYear,
              ),

              const Divider(height: 1, color: borderColor),

              _buildSettingTile(
                icon: Icons.visibility_outlined,
                title: 'Status',
                value: _courseStatus,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
      leading: Icon(icon, color: primaryTeal, size: 21),
      title: Text(
        title,
        style: const TextStyle(
          color: textDark,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: SizedBox(
        width: 160,
        child: Text(
          value.isEmpty ? '—' : value,
          textAlign: TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
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
              color: primaryTeal.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryTeal, size: 28),
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
            style: const TextStyle(color: textGrey, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _loadCourseData,
      color: primaryTeal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 110),

          const Icon(Icons.error_outline_rounded, color: red, size: 50),

          const SizedBox(height: 13),

          Text(
            _errorMessage ?? 'Unable to load course information.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: ElevatedButton.icon(
              onPressed: _loadCourseData,
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
