import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/assessment_submission_service.dart';

class InstructorAssessmentGradingScreen extends StatefulWidget {
  final String assessmentId;

  const InstructorAssessmentGradingScreen({
    super.key,
    required this.assessmentId,
  });

  @override
  State<InstructorAssessmentGradingScreen> createState() =>
      _InstructorAssessmentGradingScreenState();
}

class _InstructorAssessmentGradingScreenState
    extends State<InstructorAssessmentGradingScreen> {
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
  static const Color purple = Color(0xFF7B4DFF);
  static const Color blue = Color(0xFF1769FF);

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AssessmentSubmissionService _submissionService =
      AssessmentSubmissionService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _assessment;
  Map<String, dynamic>? _course;
  Map<String, dynamic>? _module;

  List<Map<String, dynamic>> _submissions = [];

  String _selectedFilter = 'all';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadPage();
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
      final String assessmentId = widget.assessmentId.trim();

      if (assessmentId.isEmpty) {
        throw Exception('Assessment ID is missing.');
      }

      // ----------------------------------------------------------
      // ASSESSMENT
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> assessmentDocument =
          await _firestore.collection('assessments').doc(assessmentId).get();

      if (!assessmentDocument.exists || assessmentDocument.data() == null) {
        throw Exception('Assessment could not be found.');
      }

      final Map<String, dynamic> assessmentData = assessmentDocument.data()!;

      final String courseId = (assessmentData['courseId'] ?? '')
          .toString()
          .trim();

      final String moduleId = (assessmentData['moduleId'] ?? '')
          .toString()
          .trim();

      if (courseId.isEmpty || moduleId.isEmpty) {
        throw Exception('Assessment course or module information is missing.');
      }

      // ----------------------------------------------------------
      // SUBMISSIONS
      //
      // This service also validates that the current instructor
      // owns the course.
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> submissions = await _submissionService
          .getAssessmentSubmissions(assessmentId: assessmentId);

      // ----------------------------------------------------------
      // COURSE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> courseDocument =
          await _firestore.collection('courses').doc(courseId).get();

      // ----------------------------------------------------------
      // MODULE
      // ----------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> moduleDocument =
          await _firestore.collection('modules').doc(moduleId).get();

      // ----------------------------------------------------------
      // SORT
      //
      // Submitted items first.
      // Graded items after them.
      // ----------------------------------------------------------

      submissions.sort((a, b) {
        final String aStatus = (a['status'] ?? '').toString().toLowerCase();

        final String bStatus = (b['status'] ?? '').toString().toLowerCase();

        if (aStatus == 'submitted' && bStatus != 'submitted') {
          return -1;
        }

        if (aStatus != 'submitted' && bStatus == 'submitted') {
          return 1;
        }

        final String aName = (a['studentName'] ?? '').toString().toLowerCase();

        final String bName = (b['studentName'] ?? '').toString().toLowerCase();

        return aName.compareTo(bName);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _assessment = {
          ...assessmentData,
          'id': assessmentDocument.id,
          'assessmentId': assessmentDocument.id,
        };

        if (courseDocument.exists && courseDocument.data() != null) {
          _course = {...courseDocument.data()!, 'id': courseDocument.id};
        }

        if (moduleDocument.exists && moduleDocument.data() != null) {
          _module = {...moduleDocument.data()!, 'id': moduleDocument.id};
        }

        _submissions = submissions;

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

  String get _assessmentTitle {
    return (_assessment?['title'] ?? 'Assessment').toString();
  }

  String get _assessmentType {
    return (_assessment?['assessmentType'] ?? 'assessment')
        .toString()
        .toLowerCase();
  }

  num get _totalPoints {
    return (_assessment?['totalPoints'] as num?) ?? 0;
  }

  String get _courseCode {
    return (_course?['code'] ?? '').toString();
  }

  String get _courseTitle {
    return (_course?['title'] ?? '').toString();
  }

  String get _moduleTitle {
    return (_module?['title'] ?? '').toString();
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get _submittedCount {
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
  // FILTERED SUBMISSIONS
  // ============================================================

  List<Map<String, dynamic>> get _filteredSubmissions {
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
  // GRADE STUDENT
  // ============================================================

  Future<void> _openGradeDialog(Map<String, dynamic> submission) async {
    final String submissionId =
        (submission['submissionId'] ?? submission['id'] ?? '')
            .toString()
            .trim();

    if (submissionId.isEmpty) {
      _showError('Submission ID is missing.');

      return;
    }

    final String studentName = (submission['studentName'] ?? 'Student')
        .toString();

    final String status = (submission['status'] ?? '').toString().toLowerCase();

    final dynamic currentScore = submission['score'];

    final String currentFeedback = (submission['feedback'] ?? '').toString();

    final TextEditingController scoreController = TextEditingController(
      text: currentScore is num ? currentScore.toString() : '',
    );

    final TextEditingController feedbackController = TextEditingController(
      text: currentFeedback,
    );

    bool isSaving = false;

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveGrade() async {
              if (isSaving) {
                return;
              }

              final double? score = double.tryParse(
                scoreController.text.trim(),
              );

              if (score == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid score.'),
                    backgroundColor: red,
                  ),
                );

                return;
              }

              if (score < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Score cannot be negative.'),
                    backgroundColor: red,
                  ),
                );

                return;
              }

              if (score > _totalPoints) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Score cannot exceed $_totalPoints points.'),
                    backgroundColor: red,
                  ),
                );

                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _submissionService.gradeSubmission(
                  submissionId: submissionId,
                  score: score,
                  feedback: feedbackController.text,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(context, true);
              } on AssessmentSubmissionException catch (e) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: red),
                );

                setDialogState(() {
                  isSaving = false;
                });
              } catch (e) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to save grade: $e'),
                    backgroundColor: red,
                  ),
                );

                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: Text(
                status == 'graded' ? 'Update Grade' : 'Grade Submission',
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryTeal.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                studentName.isNotEmpty
                                    ? studentName[0].toUpperCase()
                                    : '?',
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
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _assessmentTitle,
                                    style: const TextStyle(
                                      color: textGrey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Score',
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: scoreController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter score',
                          suffixText: '/ $_totalPoints',
                          filled: true,
                          fillColor: background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Feedback',
                        style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: feedbackController,
                        minLines: 4,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Write feedback for the student...',
                          filled: true,
                          fillColor: background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'The student will see the score and feedback in the Grades tab.',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : saveGrade,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
                  icon: isSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    isSaving ? 'Saving...' : 'Save Grade',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    scoreController.dispose();
    feedbackController.dispose();

    if (saved == true && mounted) {
      await _loadPage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grade saved successfully.'),
          backgroundColor: green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
  // HELPERS
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
      return 'Unknown';
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

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }

  IconData _assessmentIcon() {
    switch (_assessmentType) {
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

  Color _assessmentColor() {
    switch (_assessmentType) {
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textDark,
          ),
        ),
        title: const Text(
          'Assessment Grading',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPage,
            icon: const Icon(Icons.refresh_rounded, color: textDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: primaryTeal));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryTeal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          _buildAssessmentHeader(),

          const SizedBox(height: 22),

          _buildStatistics(),

          const SizedBox(height: 24),

          const Text(
            'Student Submissions',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Select a submitted student to enter a score and feedback.',
            style: TextStyle(color: textGrey, fontSize: 11.5),
          ),

          const SizedBox(height: 14),

          _buildFilters(),

          const SizedBox(height: 16),

          if (_filteredSubmissions.isEmpty)
            _buildEmptyState()
          else
            ..._filteredSubmissions.map(_buildSubmissionCard),
        ],
      ),
    );
  }

  // ============================================================
  // ASSESSMENT HEADER
  // ============================================================

  Widget _buildAssessmentHeader() {
    final Color color = _assessmentColor();

    return Container(
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
            child: Icon(_assessmentIcon(), color: Colors.white, size: 29),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (_courseCode.isNotEmpty) _courseCode,
                    if (_moduleTitle.isNotEmpty) _moduleTitle,
                  ].join(' • '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _assessmentTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (_courseTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),

                  Text(
                    _courseTitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],

                const SizedBox(height: 12),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _buildHeaderChip(_capitalize(_assessmentType)),
                    _buildHeaderChip('$_totalPoints points'),
                    _buildHeaderChip(
                      'Due ${_formatDate(_assessment?['dueAt'])}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Total',
            value: '${_submissions.length}',
            icon: Icons.people_alt_outlined,
            color: primaryTeal,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildStatCard(
            label: 'To Grade',
            value: '$_submittedCount',
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
      ],
    );
  }

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
          Icon(icon, color: color, size: 21),

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

          Text(label, style: const TextStyle(color: textGrey, fontSize: 9.5)),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(value: 'all', label: 'All (${_submissions.length})'),

          const SizedBox(width: 8),

          _buildFilterChip(
            value: 'submitted',
            label: 'To Grade ($_submittedCount)',
          ),

          const SizedBox(width: 8),

          _buildFilterChip(value: 'graded', label: 'Graded ($_gradedCount)'),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String value, required String label}) {
    final bool selected = _selectedFilter == value;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      selectedColor: primaryTeal.withValues(alpha: 0.12),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? primaryTeal : borderColor),
      labelStyle: TextStyle(
        color: selected ? primaryTeal : textGrey,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 11,
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

    final String status = (submission['status'] ?? 'submitted')
        .toString()
        .toLowerCase();

    final bool graded = status == 'graded';

    final dynamic score = submission['score'];

    final String feedback = (submission['feedback'] ?? '').toString().trim();

    final String initial = studentName.isNotEmpty
        ? studentName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
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
                      studentName,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      graded
                          ? 'Graded ${_formatDate(submission['gradedAt'])}'
                          : 'Submitted ${_formatDate(submission['submittedAt'])}',
                      style: const TextStyle(color: textGrey, fontSize: 10.5),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: (graded ? green : orange).withValues(alpha: 0.10),
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

          if (graded) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grade_outlined, color: green, size: 20),

                  const SizedBox(width: 9),

                  Text(
                    score is num ? '$score / $_totalPoints' : 'No score',
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  if (feedback.isNotEmpty) ...[
                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        feedback,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: textGrey, fontSize: 10.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: () {
                _openGradeDialog(submission);
              },
              icon: Icon(
                graded ? Icons.edit_outlined : Icons.grading_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                graded ? 'Update Grade' : 'Grade Submission',
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
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    String title;
    String message;

    if (_selectedFilter == 'submitted') {
      title = 'Nothing to grade';
      message = 'There are currently no pending assessment submissions.';
    } else if (_selectedFilter == 'graded') {
      title = 'No graded submissions';
      message = 'Graded student submissions will appear here.';
    } else {
      title = 'No submissions yet';
      message = 'Students will appear here after they mark this assessment as submitted.';
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: primaryTeal,
              size: 29,
            ),
          ),

          const SizedBox(height: 13),

          Text(
            title,
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
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryTeal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 110),

          const Icon(Icons.error_outline_rounded, color: red, size: 50),

          const SizedBox(height: 13),

          Text(
            _errorMessage ?? 'Unable to load assessment.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: ElevatedButton.icon(
              onPressed: _loadPage,
              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
