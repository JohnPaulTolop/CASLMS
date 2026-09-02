import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() =>
      _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  static const Color adminTheme = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedStatusFilter = 'Active';

  final List<String> _statusOptions = const [
    'All',
    'Active',
    'Archived',
  ];

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _instructors = [];

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
      final courseSnapshot =
          await _firestore.collection('courses').get();

      final instructorSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'instructor')
          .get();

      final instructors = instructorSnapshot.docs
          .map(
            (document) => <String, dynamic>{
              ...document.data(),
              'uid': document.id,
            },
          )
          .where(
            (user) =>
                (user['status'] ?? 'active')
                    .toString()
                    .trim()
                    .toLowerCase() ==
                'active',
          )
          .toList();

      final List<Map<String, dynamic>> courses = [];

      for (final document in courseSnapshot.docs) {
        final data = document.data();

        final enrollmentSnapshot = await _firestore
            .collection('enrollments')
            .where('courseId', isEqualTo: document.id)
            .get();

        final Set<String> activeStudents = {};

        for (final enrollmentDocument
            in enrollmentSnapshot.docs) {
          final enrollment = enrollmentDocument.data();
          final status = (enrollment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          final studentId =
              (enrollment['studentId'] ?? '').toString().trim();

          if (status == 'active' && studentId.isNotEmpty) {
            activeStudents.add(studentId);
          }
        }

        courses.add({
          ...data,
          'id': document.id,
          'courseId': document.id,
          'studentCount': activeStudents.length,
        });
      }

      courses.sort(
        (a, b) =>
            _courseCode(a).compareTo(_courseCode(b)),
      );

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _instructors = instructors;
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.message ?? 'Unable to load courses.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    final query = _searchQuery.trim().toLowerCase();

    return _courses.where((course) {
      final status = _courseStatus(course);

      final statusMatches =
          _selectedStatusFilter == 'All' ||
              status == _selectedStatusFilter.toLowerCase();

      if (!statusMatches) return false;

      if (query.isEmpty) return true;

      return _courseCode(course).toLowerCase().contains(query) ||
          _courseTitle(course).toLowerCase().contains(query) ||
          _instructorName(course).toLowerCase().contains(query);
    }).toList();
  }

  int get _activeCourseCount => _courses
      .where((course) => _courseStatus(course) == 'active')
      .length;

  int get _archivedCourseCount => _courses
      .where((course) => _courseStatus(course) == 'archived')
      .length;

  int get _totalEnrollments => _courses.fold<int>(
        0,
        (total, course) =>
            total +
            ((course['studentCount'] as num?)?.toInt() ?? 0),
      );

  Future<void> _toggleCourseStatus(
    Map<String, dynamic> course,
  ) async {
    if (_isBusy) return;

    final courseId = _courseId(course);
    if (courseId.isEmpty) return;

    final current = _courseStatus(course);
    final next = current == 'active' ? 'archived' : 'active';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            next == 'archived'
                ? 'Archive Course?'
                : 'Reactivate Course?',
          ),
          content: Text(
            next == 'archived'
                ? 'The course will no longer be treated as active. Existing modules, assessments, and enrollment records will be preserved.'
                : 'The course will become active again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    next == 'archived' ? orange : green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                next == 'archived' ? 'Archive' : 'Reactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await _firestore.collection('courses').doc(courseId).update({
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadCourses();

      if (!mounted) return;

      _showMessage(
        '${_courseCode(course)} is now ${_capitalize(next)}.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? 'Unable to update course status.');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _editCourse(
    Map<String, dynamic> course,
  ) async {
    if (_isBusy) return;

    final codeController =
        TextEditingController(text: _courseCode(course));

    final titleController =
        TextEditingController(text: _courseTitle(course));

    final classCodeController = TextEditingController(
      text: (course['classCode'] ?? '').toString(),
    );

    String selectedInstructorId =
        (course['instructorId'] ?? '').toString();

    if (selectedInstructorId.isEmpty &&
        _instructors.isNotEmpty) {
      selectedInstructorId =
          (_instructors.first['uid'] ?? '').toString();
    }

    final result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasSelectedInstructor = _instructors.any(
              (item) =>
                  (item['uid'] ?? '').toString() ==
                  selectedInstructorId,
            );

            return AlertDialog(
              title: const Text(
                'Edit Course',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Course Code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Course Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: classCodeController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Class Code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_instructors.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: hasSelectedInstructor
                            ? selectedInstructorId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Instructor',
                        ),
                        items: _instructors.map((instructor) {
                          return DropdownMenuItem<String>(
                            value:
                                (instructor['uid'] ?? '').toString(),
                            child: Text(
                              (instructor['name'] ?? 'Instructor')
                                  .toString(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedInstructorId = value;
                          });
                        },
                      )
                    else
                      const Text(
                        'No active instructors are available.',
                        style: TextStyle(color: textGrey),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      <String, String>{
                        'code': codeController.text,
                        'title': titleController.text,
                        'classCode': classCodeController.text,
                        'instructorId': selectedInstructorId,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: adminTheme,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    titleController.dispose();
    classCodeController.dispose();

    if (result == null) return;

    final code =
        (result['code'] ?? '').trim().toUpperCase();
    final title = (result['title'] ?? '').trim();
    final classCode =
        (result['classCode'] ?? '').trim().toUpperCase();
    final instructorId =
        (result['instructorId'] ?? '').trim();

    if (code.isEmpty || title.isEmpty) {
      _showError('Course code and title are required.');
      return;
    }

    String instructorName = '';

    for (final instructor in _instructors) {
      if ((instructor['uid'] ?? '').toString() ==
          instructorId) {
        instructorName =
            (instructor['name'] ?? '').toString();
        break;
      }
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _firestore
          .collection('courses')
          .doc(_courseId(course))
          .update({
        'code': code,
        'title': title,
        'classCode': classCode,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadCourses();

      if (!mounted) return;

      _showMessage('Course updated successfully.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? 'Unable to update course.');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_filteredCourses.isEmpty) {
      _showError('There are no courses to export.');
      return;
    }

    final csv = StringBuffer(
      'Course Code,Title,Class Code,Instructor,Active Students,Status\n',
    );

    for (final course in _filteredCourses) {
      csv.writeln(
        '${_csv(_courseCode(course))},'
        '${_csv(_courseTitle(course))},'
        '${_csv((course['classCode'] ?? '').toString())},'
        '${_csv(_instructorName(course))},'
        '${(course['studentCount'] as num?)?.toInt() ?? 0},'
        '${_csv(_capitalize(_courseStatus(course)))}',
      );
    }

    await Clipboard.setData(
      ClipboardData(text: csv.toString()),
    );

    if (!mounted) return;

    _showMessage('Course CSV copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: background,
        elevation: 0,
        titleSpacing: 24,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Course Administration',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: textDark,
              ),
            ),
            Text(
              'Live Courses & Enrollment',
              style: TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _exportCsv,
            tooltip: 'Copy CSV',
            icon: const Icon(Icons.download_rounded, color: textDark),
          ),
          IconButton(
            onPressed: _isBusy ? null : _loadCourses,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
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
        child: CircularProgressIndicator(color: adminTheme),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: red, size: 50),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGrey, height: 1.45),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadCourses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminTheme,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildSearchAndFilter(),
          const SizedBox(height: 18),
          if (_filteredCourses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: Text(
                  'No courses match this filter.',
                  style: TextStyle(
                    color: textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ..._filteredCourses.map(_buildCourseCard),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            'Active',
            '$_activeCourseCount',
            Icons.library_books_rounded,
            adminTheme,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Archived',
            '$_archivedCourseCount',
            Icons.inventory_2_outlined,
            orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            'Enrollments',
            '$_totalEnrollments',
            Icons.groups_rounded,
            green,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search course, code, or instructor',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderColor),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusOptions.map((status) {
              final selected =
                  _selectedStatusFilter == status;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(status),
                  selectedColor:
                      adminTheme.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: selected ? adminTheme : textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedStatusFilter = status;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final status = _courseStatus(course);
    final active = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (active ? adminTheme : Colors.grey)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            _courseCode(course),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? adminTheme : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _courseTitle(course),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color:
                    (active ? green : orange).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _capitalize(status),
                style: TextStyle(
                  color: active ? green : orange,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${_courseCode(course)} • ${_instructorName(course)}\n'
            'Class code: ${(course['classCode'] ?? 'Not set')} • '
            '${(course['studentCount'] as num?)?.toInt() ?? 0} active student(s)',
            style: const TextStyle(
              color: textGrey,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_isBusy,
          onSelected: (action) {
            if (action == 'edit') {
              _editCourse(course);
            } else if (action == 'status') {
              _toggleCourseStatus(course);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit Course'),
            ),
            PopupMenuItem(
              value: 'status',
              child: Text(
                active ? 'Archive Course' : 'Reactivate Course',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _courseId(Map<String, dynamic> course) {
    return (course['courseId'] ?? course['id'] ?? '')
        .toString()
        .trim();
  }

  String _courseCode(Map<String, dynamic> course) {
    final value = (course['code'] ?? '').toString().trim();
    return value.isEmpty ? 'COURSE' : value;
  }

  String _courseTitle(Map<String, dynamic> course) {
    final value = (course['title'] ?? '').toString().trim();
    return value.isEmpty ? 'Untitled Course' : value;
  }

  String _courseStatus(Map<String, dynamic> course) {
    final value =
        (course['status'] ?? 'active').toString().trim().toLowerCase();

    return value.isEmpty ? 'active' : value;
  }

  String _instructorName(Map<String, dynamic> course) {
    final direct =
        (course['instructorName'] ?? '').toString().trim();

    if (direct.isNotEmpty) return direct;

    final instructorId =
        (course['instructorId'] ?? '').toString();

    for (final instructor in _instructors) {
      if ((instructor['uid'] ?? '').toString() ==
          instructorId) {
        return (instructor['name'] ?? 'Instructor').toString();
      }
    }

    return 'Unassigned';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _csv(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminTheme,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
