import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/enrollment_service.dart';
import '../../services/progress_service.dart';
import '../shared/live_classes_page.dart';

import 'student_module_detail_page.dart';

class StudentCourseModulesScreen extends StatefulWidget {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String instructorName;

  const StudentCourseModulesScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.instructorName,
  });

  @override
  State<StudentCourseModulesScreen> createState() =>
      _StudentCourseModulesScreenState();
}

class _StudentCourseModulesScreenState
    extends State<StudentCourseModulesScreen> {
  static const Color primaryBlue = Color(0xFF1769FF);

  static const Color background = Color(0xFFF7F9FC);

  static const Color darkText = Color(0xFF10182F);

  static const Color greyText = Color(0xFF68738A);

  static const Color green = Color(0xFF26A65B);

  static const Color borderColor = Color(0xFFE6EAF0);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final EnrollmentService _enrollmentService = EnrollmentService();

  final ProgressService _progressService = ProgressService();

  bool _isLoading = true;

  String? _errorMessage;

  List<Map<String, dynamic>> _modules = [];

  Map<String, dynamic> _progress = {};

  @override
  void initState() {
    super.initState();

    _loadModules();
  }

  Future<void> _loadModules() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bool enrolled = await _enrollmentService.isEnrolled(
        courseId: widget.courseId,
      );

      if (!enrolled) {
        throw EnrollmentServiceException(
          'You are not enrolled in this course.',
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('modules')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      final List<Map<String, dynamic>> modules = [];

      for (final document in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status = (data['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status != 'published') {
          continue;
        }

        modules.add({...data, 'id': document.id, 'moduleId': document.id});
      }

      modules.sort((a, b) {
        final int orderA = (a['order'] as num?)?.toInt() ?? 0;

        final int orderB = (b['order'] as num?)?.toInt() ?? 0;

        return orderA.compareTo(orderB);
      });

      final Map<String, dynamic> progress = await _progressService
          .getCourseModuleProgress(courseId: widget.courseId);

      if (!mounted) {
        return;
      }

      setState(() {
        _modules = modules;
        _progress = progress;
        _isLoading = false;
      });
    } on EnrollmentServiceException catch (e) {
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
        _errorMessage = 'Unable to load course modules.';
      });
    }
  }

  Future<void> _openModule(Map<String, dynamic> module) async {
    final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
        .toString();

    if (moduleId.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentModuleDetailScreen(
          courseId: widget.courseId,
          courseCode: widget.courseCode,
          courseTitle: widget.courseTitle,
          moduleId: moduleId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadModules();
  }

  @override
  Widget build(BuildContext context) {
    final int completed = (_progress['completedModules'] as num?)?.toInt() ?? 0;

    final int total = (_progress['totalModules'] as num?)?.toInt() ?? 0;

    final double progress = ((_progress['progress'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkText,
            size: 20,
          ),
        ),
        title: Column(
          children: [
            Text(
              widget.courseCode.isEmpty
                  ? widget.courseTitle
                  : widget.courseCode,
              style: const TextStyle(
                color: darkText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.courseTitle,
              style: const TextStyle(color: greyText, fontSize: 10),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Live Classes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LiveClassesScreen(courseId: widget.courseId),
              ),
            ),
            icon: const Icon(Icons.video_call_outlined, color: primaryBlue),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : _errorMessage != null
            ? _buildError()
            : RefreshIndicator(
                onRefresh: _loadModules,
                color: primaryBlue,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.courseTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.instructorName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Text(
                                'Module Progress',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$completed / $total',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      'Published Modules',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (_modules.isEmpty)
                      _buildEmptyModules()
                    else
                      ..._modules.map(_buildModuleCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module) {
    final String moduleId = (module['moduleId'] ?? module['id'] ?? '')
        .toString();

    final String title = (module['title'] ?? 'Module').toString();

    final String description = (module['description'] ?? '').toString();

    final int order = (module['order'] as num?)?.toInt() ?? 0;

    return StreamBuilder<bool>(
      stream: _progressService.watchModuleCompleted(moduleId: moduleId),
      initialData: false,
      builder: (context, snapshot) {
        final bool completed = snapshot.data ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: completed ? green.withValues(alpha: 0.5) : borderColor,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                _openModule(module);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: completed
                            ? green.withValues(alpha: 0.1)
                            : primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        order > 0 ? '$order' : '•',
                        style: TextStyle(
                          color: completed ? green : primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: darkText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (description.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: greyText,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Tooltip(
                      message: completed
                          ? 'Completed automatically'
                          : 'Complete every task to finish this module',
                      child: Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : Icons.pending_outlined,
                        color: completed ? green : greyText,
                        size: 24,
                      ),
                    ),

                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9BA4B4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyModules() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, color: greyText, size: 40),
          SizedBox(height: 10),
          Text(
            'No published modules yet.',
            style: TextStyle(color: darkText, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 46),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: greyText),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadModules,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
