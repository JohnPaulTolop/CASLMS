import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';
import 'instructor_workspace_widgets.dart';

import '../../services/roster_service.dart';
import '../../services/instructor_course_service.dart';
import 'instructor_class_details_page.dart';
import 'instructor_create_course_page.dart';

class InstructorClassesScreen extends StatefulWidget {
  const InstructorClassesScreen({super.key});

  @override
  State<InstructorClassesScreen> createState() =>
      _InstructorClassesScreenState();
}

class _InstructorClassesScreenState extends State<InstructorClassesScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  // ============================================================
  // SERVICE
  // ============================================================

  final RosterService _rosterService = RosterService();

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _courses = [];

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  int _generation = 0;
  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _subscription = InstructorCourseService().watchInstructorCourses().listen(
      (courses) {
        if (!mounted) return;
        _generation++;
        setState(() {
          _courses = courses;
          _isLoading = false;
          _errorMessage = null;
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to sync courses. Please retry.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Map<String, dynamic>> courses = await _rosterService
          .getInstructorCourses();

      courses.sort((a, b) {
        int created(Map<String, dynamic> course) {
          final value = course['createdAt'] ?? course['updatedAt'];
          if (value is Timestamp) return value.millisecondsSinceEpoch;
          if (value is DateTime) return value.millisecondsSinceEpoch;
          return 0;
        }

        final byDate = created(b).compareTo(created(a));
        if (byDate != 0) return byDate;

        return (a['code'] ?? '').toString().compareTo(
          (b['code'] ?? '').toString(),
        );
      });

      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } on RosterServiceException catch (e) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load classes.';
      });
    }
  }

  Future<void> _openCreateCourse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InstructorCreateCourseScreen()),
    );

    if (mounted) {
      await _loadCourses();
    }
  }
  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredCourses {
    final String query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _courses;
    }

    return _courses.where((course) {
      final String code = (course['code'] ?? '').toString().toLowerCase();

      final String title = (course['title'] ?? '').toString().toLowerCase();

      final String semester = (course['semester'] ?? '')
          .toString()
          .toLowerCase();

      final String academicYear = (course['academicYear'] ?? '')
          .toString()
          .toLowerCase();

      return code.contains(query) ||
          title.contains(query) ||
          semester.contains(query) ||
          academicYear.contains(query);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) => instructorScaffold(
    loading: _isLoading,
    context: context,
    title: 'My courses',
    subtitle: 'Manage your sections, materials, and classroom activities.',
    actions: [
      IconButton(
        tooltip: 'Create course',
        onPressed: _openCreateCourse,
        icon: const Icon(Icons.add_rounded),
      ),
      IconButton(
        tooltip: 'Refresh courses',
        onPressed: _isLoading ? null : _loadCourses,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
    body: RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Search courses, codes, or semester',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Column(
              children: [
                Text(_errorMessage!),
                TextButton(
                  onPressed: _loadCourses,
                  child: const Text('Try again'),
                ),
              ],
            )
          else if (_courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 42),
                  const SizedBox(height: 14),
                  const Text(
                    'Your next course starts here',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a course, then add your sections and learning materials.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _openCreateCourse,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create course'),
                  ),
                ],
              ),
            )
          else if (_filteredCourses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No matching courses. Try another search.'),
            )
          else ...[
            const Text(
              'Course library',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            InstructorCourseGrid(
              courses: _filteredCourses,
              onOpen: (course) {
                final id = (course['id'] ?? course['courseId'] ?? '')
                    .toString();
                if (id.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstructorClassDetailsScreen(courseId: id),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}
