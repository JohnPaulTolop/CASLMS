import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/course_section_service.dart';
import 'instructor_class_details_page.dart';

class InstructorCourseSectionsScreen extends StatefulWidget {
  const InstructorCourseSectionsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<InstructorCourseSectionsScreen> createState() =>
      _InstructorCourseSectionsScreenState();
}

class _InstructorCourseSectionsScreenState
    extends State<InstructorCourseSectionsScreen> {
  static const teal = Color(0xFF00897B);
  static const background = Color(0xFFF7F9FC);

  final _service = CourseSectionService();

  late Future<List<Map<String, dynamic>>> _sectionsFuture;
  String _courseTitle = 'Course Details';
  String _courseCode = '';

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _load();
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
    setState(() => _sectionsFuture = _load());
    try {
      await _sectionsFuture;
    } catch (_) {
      // FutureBuilder displays the loading error.
    }
  }

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _editSection([Map<String, dynamic>? section]) async {
    String name = _text(section?['name']);
    String identifier = _text(section?['identifier']);

    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(section == null ? 'Add Section' : 'Edit Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Section Name',
                hintText: 'BSIT 1A',
              ),
              onChanged: (value) => name = value,
            ),
            TextFormField(
              initialValue: identifier,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Section Identifier',
                hintText: 'BSIT-1A',
              ),
              onChanged: (value) => identifier = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialog, [name.trim(), identifier.trim()]),
            child: Text(section == null ? 'Create Section' : 'Save'),
          ),
        ],
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
        title: const Text('Archive Section?'),
        content: Text(
          'Archive ${_text(section['name'])}? '
          'Active students must be transferred first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
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

  void _showSection(Map<String, dynamic> section) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(_text(section['name'])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identifier: ${_text(section['identifier'])}'),
            const SizedBox(height: 12),
            const Text('Class Code'),
            SelectableText(
              _text(section['classCode']),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Section-specific students, assessments, '
              'and grades will be connected next.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(Map<String, dynamic> section) {
    final archived = section['status'] == 'archived';
    final legacy = section['legacy'] == true;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0F2F1),
          child: Icon(Icons.groups_rounded, color: teal),
        ),
        title: Text(
          _text(section['name']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_text(section['identifier'])}\n'
          '${archived ? 'Archived' : 'Active'}'
          '${legacy ? ' \u2022 Original Section' : ''}',
        ),
        isThreeLine: true,
        onTap: () => _showSection(section),
        trailing: PopupMenuButton<String>(
          tooltip: 'Section options',
          onSelected: (action) {
            if (action == 'edit') {
              _editSection(section);
            } else if (action == 'archive') {
              _archive(section);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Section')),
            if (!legacy && !archived)
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive Section'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Course Details'),
        backgroundColor: background,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to load sections: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final sections = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      _courseCode,
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _courseTitle,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
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
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Open Course Tools & Materials'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Sections (${sections.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _editSection(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Section'),
                          style: FilledButton.styleFrom(backgroundColor: teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (sections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No sections yet. Add your first section.'),
                      ),
                    ...sections.map(_sectionCard),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
