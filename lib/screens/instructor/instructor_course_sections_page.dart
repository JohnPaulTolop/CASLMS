import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import 'instructor_class_details_page.dart';
import 'instructor_section_details_page.dart';

class InstructorCourseSectionsScreen extends StatefulWidget {
  const InstructorCourseSectionsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<InstructorCourseSectionsScreen> createState() =>
      _InstructorCourseSectionsScreenState();
}

class _InstructorCourseSectionsScreenState
    extends State<InstructorCourseSectionsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color teal = Color(0xFF00897B);
  static const Color darkTeal = Color(0xFF00695C);
  static const Color background = Color(0xFFF5F8FC);
  static const Color heading = Color(0xFF172B4D);
  static const Color secondaryText = Color(0xFF6B7C93);
  static const Color borderColor = Color(0xFFE5ECF3);
  static const Color red = Color(0xFFFF4B4B);

  // ============================================================
  // STATE & SERVICES
  // ============================================================

  final _service = CourseSectionService();

  late Future<List<Map<String, dynamic>>> _sectionsFuture;
  String _courseTitle = 'Course Details';
  String _courseCode = '';
  StreamSubscription? _enrollmentChanges;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _load();
    _enrollmentChanges = FirebaseFirestore.instance
        .collection('enrollments')
        .where('courseId', isEqualTo: widget.courseId)
        .snapshots()
        .skip(1)
        .listen(
          (_) {
            _refreshTimer?.cancel();
            _refreshTimer = Timer(const Duration(milliseconds: 200), () {
              if (mounted) _refresh();
            });
          },
          onError: (Object error) =>
              _notice('Unable to update section counts. Pull to refresh.'),
        );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _enrollmentChanges?.cancel();
    super.dispose();
  }

  String _text(Object? value) => (value ?? '').toString().trim();

  Future<List<Map<String, dynamic>>> _load() async {
    final course = await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .get();

    if (!course.exists) {
      throw StateError('This course could not be found.');
    }

    final sections = await _service.getSections(widget.courseId);

    if (mounted) {
      setState(() {
        _courseTitle = _text(course.data()?['title']);
        _courseCode = _text(course.data()?['code']);
      });
    }

    return sections;
  }

  Future<void> _refresh() async {
    final nextLoad = _load();
    setState(() {
      _sectionsFuture = nextLoad;
    });
    try {
      await _sectionsFuture;
    } catch (_) {
      // FutureBuilder displays the loading error.
    }
  }

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: heading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _editSection([Map<String, dynamic>? section]) async {
    String name = _text(section?['name']);
    String identifier = _text(section?['identifier']);
    final formKey = GlobalKey<FormState>();

    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Dialog Header ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          section == null
                              ? Icons.library_add_rounded
                              : Icons.edit_note_rounded,
                          color: teal,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section == null ? 'Add Section' : 'Edit Section',
                              style: const TextStyle(
                                color: heading,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              section == null
                                  ? 'Create a new section for this course.'
                                  : 'Update the details for this section.',
                              style: const TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // --- Input Fields ---
                  TextFormField(
                    initialValue: name,
                    maxLength: 80,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: heading,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Section Name',
                      labelStyle: const TextStyle(color: secondaryText),
                      hintText: 'e.g., BSIT 1A',
                      hintStyle: TextStyle(
                        color: secondaryText.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.groups_outlined,
                        color: secondaryText,
                      ),
                      filled: true,
                      fillColor: background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: teal, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: red, width: 1.5),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Section name is required'
                        : null,
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: identifier,
                    maxLength: 30,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: heading,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Section Identifier',
                      labelStyle: const TextStyle(color: secondaryText),
                      hintText: 'e.g., BSIT-1A',
                      hintStyle: TextStyle(
                        color: secondaryText.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: secondaryText,
                      ),
                      filled: true,
                      fillColor: background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: teal, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: red, width: 1.5),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Identifier is required'
                        : null,
                    onChanged: (value) => identifier = value,
                  ),
                  const SizedBox(height: 32),

                  // --- Action Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() == true) {
                            Navigator.pop(dialogContext, [
                              name.trim(),
                              identifier.trim(),
                            ]);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          section == null ? 'Create Section' : 'Save Changes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (values == null || !mounted) return;

    try {
      if (section == null) {
        await _service.createSection(
          courseId: widget.courseId,
          name: values[0],
          identifier: values[1],
        );
        _notice('Section created successfully.');
      } else {
        await _service.renameSection(
          courseId: widget.courseId,
          sectionId: _text(section['id']),
          name: values[0],
          identifier: values[1],
        );
        _notice('Section updated successfully.');
      }

      await _refresh();
    } catch (error) {
      _notice('Unable to save section: $error');
    }
  }

  Future<void> _archive(Map<String, dynamic> section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text(
          'Archive Section?',
          style: TextStyle(color: heading, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Archive ${_text(section['name'])}?\n\n'
          'Active students must be transferred to another section before this action can be completed.',
          style: const TextStyle(color: secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: FilledButton.styleFrom(backgroundColor: red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.archiveSection(
        courseId: widget.courseId,
        sectionId: _text(section['id']),
      );

      _notice('Section archived.');
      await _refresh();
    } catch (error) {
      _notice('Unable to archive section: $error');
    }
  }

  Future<void> _openSection(Map<String, dynamic> section) async {
    final sectionId = _text(section['id']);
    if (sectionId.isEmpty) {
      _notice('Section ID is missing.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InstructorSectionDetailsScreen(
          courseId: widget.courseId,
          sectionId: sectionId,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  // ============================================================
  // SHARED DESIGN COMPONENTS
  // ============================================================

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: heading.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title, String subtitle, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: heading,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _pill(
    String label, {
    Color color = teal,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadingAvatar(String name, IconData fallbackIcon) {
    final displayName = name.trim();

    if (displayName.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F6F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(fallbackIcon, color: teal, size: 22),
      );
    }

    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDDF5F0), Color(0xFFB9E9DF)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: darkTeal,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _contentCard({
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: teal),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: heading,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: heading),
        ),
        title: const Text(
          'Course Details',
          style: TextStyle(
            color: heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: teal),
            onPressed: _refresh,
          ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: teal));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 42,
                        color: teal,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Unable to load sections',
                        style: TextStyle(
                          color: heading,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refresh,
                        style: FilledButton.styleFrom(backgroundColor: teal),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final sections = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            color: teal,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  children: [
                    _buildCourseOverview(),
                    const SizedBox(height: 20),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeading(
                            'Course Sections',
                            'Manage and monitor individual class sections.',
                            trailing: FilledButton.icon(
                              onPressed: () => _editSection(),
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('Add Section'),
                              style: FilledButton.styleFrom(
                                backgroundColor: teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (sections.isEmpty)
                            _emptyState(
                              icon: Icons.groups_outlined,
                              title: 'No sections yet',
                              message: 'Add your first section to start enrolling students.',
                            )
                          else
                            ...sections.map(_buildSectionCard),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCourseOverview() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pill(_courseCode.isNotEmpty ? _courseCode : 'Course', color: teal),
          const SizedBox(height: 12),
          Text(
            _courseTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: heading,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstructorClassDetailsScreen(
                      courseId: widget.courseId,
                      courseCode: _courseCode,
                      courseTitle: _courseTitle,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFB9DFD8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.folder_open_outlined, size: 19),
              label: const Text('Open Course Tools & Materials'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final archived = section['status'] == 'archived';
    final legacy = section['legacy'] == true;
    final String name = _text(section['name']);
    final String identifier = _text(section['identifier']);

    return _contentCard(
      leading: _leadingAvatar(name, Icons.groups_rounded),
      title: name.isEmpty ? 'Untitled Section' : name,
      subtitle: [
        if (identifier.isNotEmpty) identifier,
        'Status: ${archived ? 'Archived' : 'Active'}',
        '${section['studentCount'] ?? 0} students',
        if (legacy) 'Original Section',
      ].join(' • '),
      trailing: PopupMenuButton<String>(
        tooltip: 'Section options',
        icon: const Icon(Icons.more_vert_rounded, color: secondaryText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (action) {
          if (action == 'edit') {
            _editSection(section);
          } else if (action == 'archive') {
            _archive(section);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: heading),
                SizedBox(width: 8),
                Text('Edit Section'),
              ],
            ),
          ),
          if (!legacy && !archived)
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 18, color: red),
                  SizedBox(width: 8),
                  Text('Archive Section', style: TextStyle(color: red)),
                ],
              ),
            ),
        ],
      ),
      onTap: () => _openSection(section),
    );
  }
}
