import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/assignment_service.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final String assignmentId;

  const AssignmentDetailsScreen({
    super.key,
    this.assignmentId = '',
  });

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState
    extends State<AssignmentDetailsScreen> {
  // ============================================================
  // CASLMS DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue = Color(0xFF1769FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);

  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color purple = Color(0xFF7B4DFF);

  // ============================================================
  // SERVICE
  // ============================================================

  final AssignmentService _assignmentService =
      AssignmentService();

  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _answerController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  Map<String, dynamic>? _assignment;

  Map<String, dynamic>? _submission;

  bool _isLoading = true;

  bool _isSubmitting = false;

  String? _errorMessage;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadAssignment();
  }

  @override
  void dispose() {
    _answerController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD ASSIGNMENT + STUDENT SUBMISSION
  // ============================================================

  Future<void> _loadAssignment() async {
    if (widget.assignmentId
        .trim()
        .isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Assignment information is missing.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic>? assignment =
          await _assignmentService
              .getAssignmentById(
        widget.assignmentId,
      );

      if (assignment == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Assignment could not be found.';
        });

        return;
      }

      final Map<String, dynamic>? submission =
          await _assignmentService
              .getMySubmission(
        widget.assignmentId,
      );

      if (!mounted) return;

      _answerController.text =
          (submission?['answerText'] ?? '')
              .toString();

      setState(() {
        _assignment = assignment;
        _submission = submission;

        _isLoading = false;
        _errorMessage = null;
      });
    } on AssignmentServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load assignment.';
      });
    }
  }

  // ============================================================
  // SUBMIT / UPDATE ASSIGNMENT
  // ============================================================

  Future<void> _submitAssignment() async {
    final Map<String, dynamic>? assignment =
        _assignment;

    if (assignment == null) {
      return;
    }

    final String answer =
        _answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your answer or repository link.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final String courseId =
        (assignment['courseId'] ?? '')
            .toString()
            .trim();

    if (courseId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Course information is missing.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _assignmentService
          .submitAssignment(
        assignmentId:
            widget.assignmentId,
        courseId: courseId,
        answerText: answer,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Assignment submitted successfully.',
          ),
          backgroundColor: green,
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      await _loadAssignment();
    } on AssignmentServiceException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
          backgroundColor:
              Colors.redAccent,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to submit assignment.',
          ),
          backgroundColor:
              Colors.redAccent,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ==========================================================
      // HEADER
      // ==========================================================

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textDark,

        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Assignment Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.w800,
            color: textDark,
          ),
        ),

        centerTitle: true,

        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
            ),
            onPressed:
                _showMoreOptions,
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment:
              Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1000,
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    // ------------------------------------------------------------
    // LOADING
    // ------------------------------------------------------------

    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(
          color: primaryBlue,
        ),
      );
    }

    // ------------------------------------------------------------
    // ERROR
    // ------------------------------------------------------------

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                size: 48,
                color:
                    Colors.redAccent,
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: textGrey,
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              if (widget.assignmentId
                  .trim()
                  .isNotEmpty)
                TextButton.icon(
                  onPressed:
                      _loadAssignment,
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Try Again',
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic>? assignment =
        _assignment;

    if (assignment == null) {
      return const Center(
        child: Text(
          'Assignment unavailable.',
        ),
      );
    }

    // ==========================================================
    // ASSIGNMENT VALUES
    // ==========================================================

    final String title =
        (assignment['title'] ??
                'Untitled Assignment')
            .toString();

    final String description =
        (assignment['description'] ??
                '')
            .toString();

    final String instructions =
        (assignment['instructions'] ??
                '')
            .toString();

    final int points =
        assignment['points'] is num
            ? (assignment['points']
                    as num)
                .toInt()
            : 0;

    final DateTime? dueDate =
        _timestampToDate(
      assignment['dueAt'],
    );

    final String submissionStatus =
        (_submission?['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final bool isGraded =
        submissionStatus == 'graded' ||
            submissionStatus ==
                'completed';

    // ==========================================================
    // PAGE
    // ==========================================================

    return RefreshIndicator(
      color: primaryBlue,
      onRefresh: _loadAssignment,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        padding:
            const EdgeInsets.fromLTRB(
          24,
          20,
          24,
          40,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ====================================================
            // ASSIGNMENT HEADER
            // ====================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                24,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xFFE6EAF0,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          primaryBlue
                              .withValues(
                        alpha:
                            0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        8,
                      ),
                    ),
                    child:
                        const Text(
                      'ASSIGNMENT',
                      style:
                          TextStyle(
                        color:
                            primaryBlue,
                        fontSize:
                            10,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            0.8,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 27,
                      fontWeight:
                          FontWeight
                              .w800,
                      color: textDark,
                      letterSpacing:
                          -0.6,
                    ),
                  ),

                  if (description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      description,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        color: textGrey,
                        height: 1.5,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 24,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _buildInfoItem(
                          icon: Icons
                              .schedule_rounded,
                          label:
                              'Due Date',
                          value: dueDate ==
                                  null
                              ? 'No due date'
                              : _formatDate(
                                  dueDate,
                                ),
                        ),
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      Expanded(
                        child:
                            _buildInfoItem(
                          icon: Icons
                              .stars_outlined,
                          label:
                              'Points',
                          value:
                              '$points pts',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ====================================================
            // INSTRUCTIONS
            // ====================================================

            const Text(
              'Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                20,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xFFE6EAF0,
                  ),
                ),
              ),
              child: Text(
                instructions
                        .trim()
                        .isEmpty
                    ? 'No additional instructions were provided.'
                    : instructions,
                style:
                    const TextStyle(
                  color: textGrey,
                  fontSize: 14,
                  height: 1.65,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ====================================================
            // SUBMISSION HEADER
            // ====================================================

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your Submission',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight
                              .w800,
                      color:
                          textDark,
                    ),
                  ),
                ),

                if (_submission != null)
                  _buildSubmissionBadge(),
              ],
            ),

            const SizedBox(height: 12),

            // ====================================================
            // GRADED RESULT
            // ====================================================

            if (isGraded) ...[
              _buildGradedResult(),

              const SizedBox(
                height: 18,
              ),
            ],

            // ====================================================
            // ANSWER / SUBMISSION SECTION
            // ====================================================

            Container(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xFFE6EAF0,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Answer / Repository Link',
                    style:
                        TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  const Text(
                    'Enter your written response or GitHub repository link below.',
                    style:
                        TextStyle(
                      color: textGrey,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  TextField(
                    controller:
                        _answerController,
                    enabled:
                        !isGraded,
                    maxLines: 7,
                    minLines: 4,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Example: https://github.com/username/project',
                      hintStyle:
                          const TextStyle(
                        color:
                            Color(
                          0xFFA0A8B7,
                        ),
                        fontSize:
                            13,
                      ),
                      filled: true,
                      fillColor:
                          const Color(
                        0xFFF8FAFD,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE1E5EC,
                          ),
                        ),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE1E5EC,
                          ),
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              primaryBlue,
                          width: 1.5,
                        ),
                      ),
                      disabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE1E5EC,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==============================================
                  // FILE UPLOAD PLACEHOLDER
                  // ==============================================

                  OutlinedButton.icon(
                    onPressed: isGraded
                        ? null
                        : () {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'File upload will be connected to Supabase Storage later.',
                                ),
                                behavior:
                                    SnackBarBehavior
                                        .floating,
                              ),
                            );
                          },
                    icon: const Icon(
                      Icons
                          .upload_file_rounded,
                    ),
                    label:
                        const Text(
                      'Attach File',
                    ),
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          primaryBlue,
                      side:
                          const BorderSide(
                        color:
                            Color(
                          0xFFD8E4FF,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==============================================
                  // SUBMIT / UPDATE
                  // ==============================================

                  if (!isGraded)
                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton
                              .icon(
                        onPressed:
                            _isSubmitting
                                ? null
                                : _submitAssignment,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width:
                                    20,
                                height:
                                    20,
                                child:
                                    CircularProgressIndicator(
                                  color:
                                      Colors.white,
                                  strokeWidth:
                                      2.2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .send_rounded,
                                color:
                                    Colors.white,
                                size:
                                    18,
                              ),
                        label: Text(
                          _submission ==
                                  null
                              ? 'Submit Assignment'
                              : 'Update Submission',
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              primaryBlue,
                          disabledBackgroundColor:
                              primaryBlue
                                  .withValues(
                            alpha:
                                0.55,
                          ),
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color:
            primaryBlue.withValues(
          alpha: 0.055,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryBlue,
            size: 20,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color: textDark,
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMISSION BADGE
  // ============================================================

  Widget _buildSubmissionBadge() {
    final String status =
        (_submission?['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    Color color;
    String text;

    if (status == 'graded' ||
        status == 'completed') {
      color = green;
      text = 'Graded';
    } else if (status == 'late') {
      color = orange;
      text = 'Late';
    } else {
      color = purple;
      text = 'Submitted';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // GRADED RESULT
  // ============================================================

  Widget _buildGradedResult() {
    final Map<String, dynamic>? assignment =
        _assignment;

    final Map<String, dynamic>? submission =
        _submission;

    if (assignment == null ||
        submission == null) {
      return const SizedBox.shrink();
    }

    final int score =
        submission['score'] is num
            ? (submission['score']
                    as num)
                .toInt()
            : 0;

    final int points =
        assignment['points'] is num
            ? (assignment['points']
                    as num)
                .toInt()
            : 0;

    final String feedback =
        (submission['feedback'] ?? '')
            .toString();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: green.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: green.withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Grade',
            style: TextStyle(
              color: green,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '$score / $points',
            style: const TextStyle(
              color: textDark,
              fontSize: 27,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          if (feedback
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height: 14,
            ),

            const Text(
              'Instructor Feedback',
              style: TextStyle(
                color: textDark,
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              feedback,
              style:
                  const TextStyle(
                color: textGrey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MORE OPTIONS
  // ============================================================

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            20,
          ),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.only(
            top: 12,
            bottom: 24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade300,
                  borderRadius:
                      BorderRadius
                          .circular(
                    2,
                  ),
                ),
              ),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .assignment_turned_in_rounded,
                ),
                title:
                    const Text(
                  'View Submission Status',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );
                },
              ),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .chat_bubble_outline_rounded,
                ),
                title:
                    const Text(
                  'Message Instructor',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Instructor messaging will be connected during the Chat phase.',
                      ),
                      behavior:
                          SnackBarBehavior
                              .floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _timestampToDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(
    DateTime date,
  ) {
    final String month =
        _monthName(
      date.month,
    );

    final int displayHour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final String minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$month ${date.day}, ${date.year}\n'
        '$displayHour:$minute $period';
  }

  String _monthName(
    int month,
  ) {
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

    if (month < 1 ||
        month > 12) {
      return '';
    }

    return months[
        month - 1];
  }
}