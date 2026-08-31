import 'package:flutter/material.dart';

import '../../services/assignment_service.dart';

class CodeReviewScreen extends StatefulWidget {
  final String submissionId;
  final String studentName;
  final String assignmentTitle;

  const CodeReviewScreen({
    super.key,
    this.submissionId = '',
    required this.studentName,
    required this.assignmentTitle,
  });

  @override
  State<CodeReviewScreen> createState() =>
      _CodeReviewScreenState();
}

class _CodeReviewScreenState
    extends State<CodeReviewScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color green = Color(0xFF26A65B);

  // ============================================================
  // SERVICE
  // ============================================================

  final AssignmentService _assignmentService =
      AssignmentService();

  // ============================================================
  // CONTROLLER
  // ============================================================

  final TextEditingController _feedbackController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  Map<String, dynamic>? _submission;

  bool _isLoading = true;

  bool _isSaving = false;

  String? _errorMessage;

  double _currentGrade = 0;

  int _maximumPoints = 100;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadSubmission();
  }

  @override
  void dispose() {
    _feedbackController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD REAL SUBMISSION
  // ============================================================

  Future<void> _loadSubmission() async {
    if (widget.submissionId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Submission information is missing.';
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
      final Map<String, dynamic>? submission =
          await _assignmentService
              .getSubmissionById(
        widget.submissionId,
      );

      if (submission == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage =
              'Submission could not be found.';
        });

        return;
      }

      final int maximumPoints =
          submission['assignmentPoints'] is num
              ? (submission['assignmentPoints'] as num)
                  .toInt()
              : 100;

      final int existingScore =
          submission['score'] is num
              ? (submission['score'] as num)
                  .toInt()
              : 0;

      final String existingFeedback =
          (submission['feedback'] ?? '')
              .toString();

      if (!mounted) return;

      _feedbackController.text =
          existingFeedback;

      setState(() {
        _submission = submission;

        _maximumPoints =
            maximumPoints > 0
                ? maximumPoints
                : 100;

        _currentGrade =
            existingScore
                .clamp(
                  0,
                  _maximumPoints,
                )
                .toDouble();

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
            'Unable to load submission.';
      });
    }
  }

  // ============================================================
  // SAVE GRADE
  // ============================================================

  Future<void> _saveGrade() async {
    if (_submission == null) {
      return;
    }

    final int score =
        _currentGrade.round();

    setState(() {
      _isSaving = true;
    });

    try {
      await _assignmentService
          .gradeSubmission(
        submissionId:
            widget.submissionId,
        score: score,
        feedback:
            _feedbackController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Grade and feedback saved successfully.',
          ),
          backgroundColor: green,
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      // Return to Pending Grading.
      // That screen reloads and removes this graded submission.
      Navigator.pop(
        context,
        true,
      );
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
            'Unable to save grade.',
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
          _isSaving = false;
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

      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        foregroundColor: Colors.white,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Reviewing: ${widget.studentName}',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            Text(
              widget.assignmentTitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryTeal,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin:
              const EdgeInsets.all(24),
          constraints:
              const BoxConstraints(
            maxWidth: 500,
          ),
          padding:
              const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color:
                  const Color(0xFFE6EAF0),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 46,
                color:
                    Colors.redAccent,
              ),

              const SizedBox(height: 12),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 14),

              if (widget.submissionId
                  .trim()
                  .isNotEmpty)
                TextButton.icon(
                  onPressed:
                      _loadSubmission,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Try Again',
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final Map<String, dynamic>? submission =
        _submission;

    if (submission == null) {
      return const Center(
        child: Text(
          'Submission unavailable.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final bool desktop =
            constraints.maxWidth >= 850;

        if (desktop) {
          return _buildDesktopLayout(
            submission,
          );
        }

        return _buildMobileLayout(
          submission,
        );
      },
    );
  }

  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _buildDesktopLayout(
    Map<String, dynamic> submission,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 1300,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child:
                    _buildSubmissionPanel(
                  submission,
                ),
              ),

              const SizedBox(width: 24),

              Expanded(
                flex: 5,
                child:
                    _buildGradingPanel(
                  submission,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _buildMobileLayout(
    Map<String, dynamic> submission,
  ) {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildSubmissionPanel(
            submission,
          ),

          const SizedBox(height: 18),

          _buildGradingPanel(
            submission,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT SUBMISSION PANEL
  // ============================================================

  Widget _buildSubmissionPanel(
    Map<String, dynamic> submission,
  ) {
    final String answerText =
        (submission['answerText'] ?? '')
            .toString();

    final String fileUrl =
        (submission['fileUrl'] ?? '')
            .toString();

    final String studentName =
        (submission['studentName'] ??
                widget.studentName)
            .toString();

    final String studentEmail =
        (submission['studentEmail'] ?? '')
            .toString();

    final String assignmentTitle =
        (submission['assignmentTitle'] ??
                widget.assignmentTitle)
            .toString();

    final String assignmentDescription =
        (submission[
                    'assignmentDescription'] ??
                '')
            .toString();

    final String assignmentInstructions =
        (submission[
                    'assignmentInstructions'] ??
                '')
            .toString();

    final String courseCode =
        (submission['courseCode'] ?? '')
            .toString();

    final String courseTitle =
        (submission['courseTitle'] ??
                'Course')
            .toString();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFE3E7EE),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================================
          // STUDENT
          // ======================================================

          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    primaryTeal.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  studentName
                          .trim()
                          .isEmpty
                      ? '?'
                      : studentName
                          .trim()[0]
                          .toUpperCase(),
                  style: const TextStyle(
                    color: primaryTeal,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    if (studentEmail
                        .trim()
                        .isNotEmpty)
                      Text(
                        studentEmail,
                        style: const TextStyle(
                          color: textGrey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Divider(),

          const SizedBox(height: 18),

          Text(
            courseCode.isEmpty
                ? courseTitle
                : '$courseCode • $courseTitle',
            style: const TextStyle(
              color: primaryTeal,
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            assignmentTitle,
            style: const TextStyle(
              color: textDark,
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          if (assignmentDescription
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              assignmentDescription,
              style: const TextStyle(
                color: textGrey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],

          if (assignmentInstructions
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 20),

            const Text(
              'Assignment Instructions',
              style: TextStyle(
                color: textDark,
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              assignmentInstructions,
              style: const TextStyle(
                color: textGrey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ======================================================
          // ANSWER
          // ======================================================

          const Text(
            'Student Submission',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            constraints:
                const BoxConstraints(
              minHeight: 160,
            ),
            padding:
                const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFF7F9FC),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color:
                    const Color(0xFFE3E7EE),
              ),
            ),
            child: SelectableText(
              answerText.trim().isEmpty
                  ? 'The student did not provide a written answer.'
                  : answerText,
              style: TextStyle(
                color:
                    answerText.trim().isEmpty
                        ? textGrey
                        : textDark,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),

          if (fileUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 16),

            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    primaryTeal.withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    color: primaryTeal,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: SelectableText(
                      fileUrl,
                      style: const TextStyle(
                        color: primaryTeal,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GRADING PANEL
  // ============================================================

  Widget _buildGradingPanel(
    Map<String, dynamic> submission,
  ) {
    final String currentStatus =
        (submission['status'] ??
                'submitted')
            .toString();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFE3E7EE),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Grade Submission',
            style: TextStyle(
              color: textDark,
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Current status: $currentStatus',
            style: const TextStyle(
              color: textGrey,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 28),

          // ======================================================
          // SCORE
          // ======================================================

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Final Score',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              Text(
                '${_currentGrade.round()} / $_maximumPoints',
                style: const TextStyle(
                  color: primaryTeal,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Slider(
            value: _currentGrade,
            min: 0,
            max:
                _maximumPoints.toDouble(),
            divisions:
                _maximumPoints > 0
                    ? _maximumPoints
                    : null,
            activeColor:
                primaryTeal,
            inactiveColor:
                primaryTeal.withValues(
              alpha: 0.15,
            ),
            label:
                _currentGrade.round().toString(),
            onChanged:
                _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _currentGrade =
                              value;
                        });
                      },
          ),

          const SizedBox(height: 24),

          // ======================================================
          // FEEDBACK
          // ======================================================

          const Text(
            'Instructor Feedback',
            style: TextStyle(
              color: textDark,
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller:
                _feedbackController,
            enabled: !_isSaving,
            maxLines: 6,
            minLines: 4,
            decoration:
                InputDecoration(
              hintText:
                  'Add feedback for the student...',
              hintStyle:
                  const TextStyle(
                color:
                    Color(0xFFA0A8B7),
                fontSize: 13,
              ),
              filled: true,
              fillColor:
                  const Color(
                0xFFF8FAFD,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
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
                    BorderRadius.circular(
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
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      primaryTeal,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // SAVE
          // ======================================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                ElevatedButton.icon(
              onPressed:
                  _isSaving
                      ? null
                      : _saveGrade,

              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .check_circle_rounded,
                      color:
                          Colors.white,
                      size: 19,
                    ),

              label: Text(
                _isSaving
                    ? 'Saving...'
                    : 'Submit Grade & Feedback',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryTeal,
                disabledBackgroundColor:
                    primaryTeal
                        .withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Submitting the grade will mark this submission as graded.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: textGrey,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}