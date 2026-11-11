import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'dart:async';

import '../../services/admin_catalog.dart';
import '../../models/admin_records.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({super.key});

  @override
  State<AdminCoursesScreen> createState() => _AdminCoursesScreenState();
}

class _AdminCoursesScreenState extends State<AdminCoursesScreen> {
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get blueTint => AppColors.resolve(context, AppColors.blueTint);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedStatusFilter = 'Active';

  final List<String> _statusOptions = const ['All', 'Active', 'Archived'];

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _instructors = [];

  AdminCatalog? _catalog;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _enrollmentChanges;
  List<Map<String, dynamic>> _enrollmentRows = [];
  bool _rosterReady = false, _started = false;
  String? _rosterError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalog = context
        .dependOnInheritedWidgetOfExactType<AdminScope>()
        ?.notifier;
    if (_catalog != null) {
      if (_enrollmentChanges == null) _watchEnrollments();
      _syncDirectory();
    } else if (!_started) {
      _started = true;
      _loadCourses();
    }
  }

  void _watchEnrollments() {
    _enrollmentChanges?.cancel();
    _rosterReady = false;
    _rosterError = null;
    _enrollmentChanges = _firestore
        .collection('enrollments')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            _enrollmentRows = snapshot.docs
                .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
                .toList();
            _rosterReady = true;
            _rosterError = null;
            setState(_syncDirectory);
          },
          onError: (Object error) {
            if (!mounted) return;
            _rosterReady = true;
            _rosterError = 'Unable to sync enrollment counts. Please retry.';
            setState(_syncDirectory);
          },
        );
  }

  void _syncDirectory() {
    final catalog = _catalog!;
    final counts = adminEnrollmentCounts(_enrollmentRows);
    _courses =
        catalog.courses.entries
            .map(
              (entry) => <String, dynamic>{
                ...entry.value,
                'id': entry.key,
                'courseId': entry.key,
                'studentCount': counts[entry.key] ?? 0,
                if (catalog.users[adminText(
                      entry.value['instructorId'],
                    )]?['name'] !=
                    null)
                  'instructorName': catalog
                      .users[adminText(entry.value['instructorId'])]!['name'],
              },
            )
            .toList()
          ..sort((a, b) => _courseCode(a).compareTo(_courseCode(b)));
    _instructors = catalog.users.values
        .where((u) => u['role'] == 'instructor' && u['status'] == 'active')
        .toList();
    _isLoading = catalog.loading || !_rosterReady;
    _errorMessage = catalog.error ?? _rosterError;
  }

  @override
  void dispose() {
    _enrollmentChanges?.cancel();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    if (_catalog != null) {
      if (_catalog!.error != null) await _catalog!.start();
      if (_rosterError != null) _watchEnrollments();
      if (mounted) setState(_syncDirectory);
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final courseSnapshot = await _firestore.collection('courses').get();

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
                (user['status'] ?? 'active').toString().trim().toLowerCase() ==
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

        for (final enrollmentDocument in enrollmentSnapshot.docs) {
          final enrollment = enrollmentDocument.data();
          final status = (enrollment['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          final studentId = (enrollment['studentId'] ?? '').toString().trim();

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

      courses.sort((a, b) => _courseCode(a).compareTo(_courseCode(b)));

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
        _errorMessage = e.message ?? 'Unable to load courses.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

  int get _activeCourseCount =>
      _courses.where((course) => _courseStatus(course) == 'active').length;

  int get _archivedCourseCount =>
      _courses.where((course) => _courseStatus(course) == 'archived').length;

  int get _totalEnrollments => _courses.fold<int>(
    0,
    (total, course) => total + ((course['studentCount'] as num?)?.toInt() ?? 0),
  );

  Future<void> _toggleCourseStatus(Map<String, dynamic> course) async {
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
            next == 'archived' ? 'Archive Course?' : 'Reactivate Course?',
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
                backgroundColor: next == 'archived' ? orange : green,
                foregroundColor: Colors.white,
              ),
              child: Text(next == 'archived' ? 'Archive' : 'Reactivate'),
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

      _showMessage('${_courseCode(course)} is now ${_capitalize(next)}.');
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

  Future<void> _editCourse(Map<String, dynamic> course) async {
    if (_isBusy) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AdminCourseEditDialog(
        initialCode: _courseCode(course),
        initialTitle: _courseTitle(course),
        initialClassCode: (course['classCode'] ?? '').toString(),
        initialInstructorId: (course['instructorId'] ?? '').toString(),
        instructors: _instructors,
      ),
    );

    if (result == null) return;

    final code = (result['code'] ?? '').trim().toUpperCase();
    final title = (result['title'] ?? '').trim();
    final classCode = (result['classCode'] ?? '').trim().toUpperCase();
    final instructorId = (result['instructorId'] ?? '').trim();

    if (code.isEmpty || title.isEmpty || instructorId.isEmpty) {
      _showError('Course code, title, and instructor are required.');
      return;
    }

    String instructorName = '';

    for (final instructor in _instructors) {
      if ((instructor['uid'] ?? '').toString() == instructorId) {
        instructorName = (instructor['name'] ?? '').toString();
        break;
      }
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _firestore.collection('courses').doc(_courseId(course)).update({
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

    await Clipboard.setData(ClipboardData(text: csv.toString()));

    if (!mounted) return;

    _showMessage('Course CSV copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    final width = MediaQuery.sizeOf(context).width;
    final inset = workspaceInset(width);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: WorkspaceScrollingBody(
              header: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                    child: WorkspaceHeading(
                      showEyebrow: false,
                      title: 'Courses',
                      subtitle: 'Live academic courses, assigned instructors, and student enrollment counts.',
                      eyebrow: 'ADMINISTRATION',
                      actions: [
                        IconButton(
                          onPressed: _isBusy ? null : _exportCsv,
                          tooltip: 'Copy CSV',
                          icon: Icon(Icons.download_rounded, color: textDark),
                        ),
                        IconButton(
                          onPressed: _isBusy ? null : _loadCourses,
                          tooltip: 'Refresh',
                          icon: Icon(Icons.refresh_rounded, color: textDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              body: _buildBody(inset),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double inset) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: adminTheme));
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: WorkspaceErrorState(
          message: _errorMessage!,
          onRetry: _loadCourses,
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
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 40),
        children: [
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildSearchAndFilter(),
          const SizedBox(height: 18),
          if (_filteredCourses.isEmpty)
            const WorkspaceEmptyState(
              title: 'No courses match this filter.',
              message: 'Try adjusting your search query or status filter.',
              icon: Icons.menu_book_outlined,
            )
          else
            ..._filteredCourses.asMap().entries.map(
              (entry) => _buildCourseCard(entry.value, entry.key),
            ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = [
          (
            Icons.library_books_rounded,
            '$_activeCourseCount',
            'Active courses',
            adminTheme,
            blueTint,
          ),
          (
            Icons.inventory_2_outlined,
            '$_archivedCourseCount',
            'Archived courses',
            orange,
            AppColors.resolve(context, AppColors.amberTint),
          ),
          (
            Icons.groups_rounded,
            '$_totalEnrollments',
            'Total enrollments',
            green,
            AppColors.resolve(context, AppColors.greenTint),
          ),
        ];
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 760 * scale
            ? 3
            : constraints.maxWidth >= 380 * scale
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: WorkspaceSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WorkspaceIconTile(
                            icon: stat.$1,
                            color: stat.$4,
                            background: stat.$5,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stat.$2,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        stat.$3,
                        style: TextStyle(fontSize: 12, color: textGrey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search course, code, or instructor',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusOptions.map((status) {
              final selected = _selectedStatusFilter == status;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(status),
                  selectedColor: adminTheme.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: selected ? adminTheme : textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? adminTheme : borderColor,
                    ),
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedStatusFilter = status),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    final status = _courseStatus(course);
    final active = status == 'active';
    final summary = courseSummary(course, index);
    final accent = AppColors.resolve(context, summary.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkspaceSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: active ? accent : textGrey.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(summary.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _courseCode(course),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (active ? green : orange).withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _capitalize(status),
                                style: TextStyle(
                                  color: active ? green : orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _courseTitle(course),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Instructor: ${_instructorName(course)}',
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                            Text(
                              'Class code: ${course['classCode'] ?? 'Not set'}',
                              style: TextStyle(color: textGrey, fontSize: 12),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: 14,
                                  color: textGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(course['studentCount'] as num?)?.toInt() ?? 0} active students',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_isBusy,
                    icon: Icon(Icons.more_vert_rounded, color: textGrey),
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
                        child: Text('Edit course'),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(
                          active ? 'Archive course' : 'Reactivate course',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _courseId(Map<String, dynamic> course) {
    return (course['courseId'] ?? course['id'] ?? '').toString().trim();
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
    final value = (course['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    return value.isEmpty ? 'active' : value;
  }

  String _instructorName(Map<String, dynamic> course) {
    final direct = (course['instructorName'] ?? '').toString().trim();

    if (direct.isNotEmpty) return direct;

    final instructorId = (course['instructorId'] ?? '').toString();

    for (final instructor in _instructors) {
      if ((instructor['uid'] ?? '').toString() == instructorId) {
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

class _AdminCourseEditDialog extends StatefulWidget {
  const _AdminCourseEditDialog({
    required this.initialCode,
    required this.initialTitle,
    required this.initialClassCode,
    required this.initialInstructorId,
    required this.instructors,
  });

  final String initialCode;
  final String initialTitle;
  final String initialClassCode;
  final String initialInstructorId;
  final List<Map<String, dynamic>> instructors;

  @override
  State<_AdminCourseEditDialog> createState() => _AdminCourseEditDialogState();
}

class _AdminCourseEditDialogState extends State<_AdminCourseEditDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _titleController;
  late final TextEditingController _classCodeController;
  late final List<Map<String, dynamic>> _instructors;

  String? _selectedInstructorId;

  @override
  void initState() {
    super.initState();

    _codeController = TextEditingController(text: widget.initialCode);
    _titleController = TextEditingController(text: widget.initialTitle);
    _classCodeController = TextEditingController(text: widget.initialClassCode);

    final Map<String, Map<String, dynamic>> uniqueInstructors = {};

    for (final instructor in widget.instructors) {
      final String uid = (instructor['uid'] ?? '').toString().trim();

      if (uid.isNotEmpty) {
        uniqueInstructors[uid] = instructor;
      }
    }

    _instructors = uniqueInstructors.values.toList();

    final String initialId = widget.initialInstructorId.trim();
    final bool initialIdIsAvailable = _instructors.any(
      (instructor) => (instructor['uid'] ?? '').toString().trim() == initialId,
    );

    if (initialIdIsAvailable) {
      _selectedInstructorId = initialId;
    } else if (_instructors.isNotEmpty) {
      _selectedInstructorId = (_instructors.first['uid'] ?? '')
          .toString()
          .trim();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _classCodeController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, <String, String>{
      'code': _codeController.text,
      'title': _titleController.text,
      'classCode': _classCodeController.text,
      'instructorId': _selectedInstructorId ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.resolve(context, Colors.white);
    final textDark = AppColors.resolve(context, AppColors.darkText);
    final textGrey = AppColors.resolve(context, AppColors.secondaryText);

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Edit Course',
        style: TextStyle(fontWeight: FontWeight.w700, color: textDark),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Course Code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Course Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _classCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Class Code'),
            ),
            const SizedBox(height: 12),
            if (_instructors.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedInstructorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Instructor'),
                items: _instructors.map((instructor) {
                  final String uid = (instructor['uid'] ?? '')
                      .toString()
                      .trim();

                  return DropdownMenuItem<String>(
                    value: uid,
                    child: Text(
                      (instructor['name'] ?? 'Instructor').toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInstructorId = value;
                  });
                },
              )
            else
              Text(
                'No active instructors are available.',
                style: TextStyle(color: textGrey),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _instructors.isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
