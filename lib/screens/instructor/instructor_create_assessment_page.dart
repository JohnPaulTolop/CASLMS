import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import '../../services/assessment_service.dart';

class InstructorCreateAssessmentScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;

  final String courseCode;
  final String courseTitle;
  final String moduleTitle;

  const InstructorCreateAssessmentScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.courseCode,
    required this.courseTitle,
    required this.moduleTitle,
  });

  @override
  State<InstructorCreateAssessmentScreen> createState() =>
      _InstructorCreateAssessmentScreenState();
}

class _InstructorCreateAssessmentScreenState
    extends State<InstructorCreateAssessmentScreen> {
  // ============================================================
  // DESIGN
  // ============================================================

  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _instructionsController = TextEditingController();

  final TextEditingController _urlController = TextEditingController();

  final TextEditingController _pointsController = TextEditingController();

  final AssessmentService _assessmentService = AssessmentService();

  String _assessmentType = 'quiz';

  String _submissionMethod = 'artifact';

  bool _allowGitHub = true;
  bool _allowZip = true;
  bool _allowTechnicalDocument = true;

  DateTime? _dueAt;

  bool _isSaving = false;

  String? _savingStatus;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _urlController.dispose();
    _pointsController.dispose();

    super.dispose();
  }

  // ============================================================
  // SELECT DUE DATE + TIME
  // ============================================================

  Future<void> _selectDueDateTime() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTeal,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final TimeOfDay initialTime = _dueAt != null
        ? TimeOfDay.fromDateTime(_dueAt!)
        : const TimeOfDay(hour: 23, minute: 59);

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTeal,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    final DateTime combined = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      _dueAt = combined;
    });
  }

  // ============================================================
  // SAVE / PUBLISH
  // ============================================================

  Future<void> _saveAssessment({required String status}) async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dueAt == null) {
      _showError('Please select the due date and time.');

      return;
    }

    if (!_dueAt!.isAfter(DateTime.now())) {
      _showError('The due date must be in the future.');

      return;
    }

    final double? totalPoints = double.tryParse(_pointsController.text.trim());

    if (totalPoints == null || totalPoints <= 0) {
      _showError('Enter valid total points.');

      return;
    }

    final List<String> allowedSubmissionTypes = [
      if (_allowGitHub) 'github_repository',
      if (_allowZip) 'zip_file',
      if (_allowTechnicalDocument) 'technical_document',
    ];

    if (_submissionMethod == 'artifact' && allowedSubmissionTypes.isEmpty) {
      _showError('Select at least one student submission option.');
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = status;
    });

    try {
      final Map<String, dynamic> assessment = await _assessmentService
          .createExternalAssessment(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
            title: _titleController.text,
            instructions: _instructionsController.text,
            assessmentType: _assessmentType,
            submissionMethod: _submissionMethod,
            externalUrl: _urlController.text,
            allowedSubmissionTypes: allowedSubmissionTypes,
            totalPoints: totalPoints,
            dueAt: _dueAt!,
            status: status,
          );

      if (!mounted) {
        return;
      }

      final String title = (assessment['title'] ?? 'Assessment').toString();

      Navigator.pop(context, {'created': true, 'assessment': assessment});

      // Parent screen will refresh after Navigator.pop().
      debugPrint('Assessment created successfully: $title');
    } on AssessmentServiceException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showError('Unable to create assessment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingStatus = null;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDueDate() {
    if (_dueAt == null) {
      return 'Select due date and time';
    }

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

    final DateTime date = _dueAt!;

    int hour = date.hour;

    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final String minute = date.minute.toString().padLeft(2, '0');

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year} • '
        '$hour:$minute $period';
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
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: textDark,
          ),
        ),

        title: const Text(
          'Create Assessment',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),

            child: Form(
              key: _formKey,

              child: ListView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(24, 12, 24, 130),

                children: [
                  // ==================================================
                  // CURRENT MODULE
                  // ==================================================

                  _buildModuleBanner(),

                  const SizedBox(height: 28),

                  // ==================================================
                  // ASSESSMENT TYPE
                  // ==================================================
                  _buildSectionTitle(
                    'Assessment Type',
                    'Choose what kind of task you are publishing.',
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _assessmentType,

                    decoration: _inputDecoration(
                      label: 'Type',
                      icon: Icons.category_outlined,
                    ),

                    items: const [
                      DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                      DropdownMenuItem(
                        value: 'unit_test',
                        child: Text('Unit Test'),
                      ),
                      DropdownMenuItem(
                        value: 'activity',
                        child: Text('Activity'),
                      ),
                      DropdownMenuItem(
                        value: 'assignment',
                        child: Text('Assignment'),
                      ),
                      DropdownMenuItem(value: 'exam', child: Text('Exam')),
                      DropdownMenuItem(
                        value: 'summative',
                        child: Text('Summative'),
                      ),
                    ],

                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _assessmentType = value;
                            });
                          },
                  ),

                  const SizedBox(height: 26),

                  // ==================================================
                  // SUBMISSION METHOD
                  // ==================================================
                  _buildSectionTitle(
                    'Submission Method',
                    'Students will see only the method selected here.',
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _submissionMethod,
                    decoration: _inputDecoration(
                      label: 'How students submit',
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'artifact',
                        child: Text('GitHub or file upload'),
                      ),
                      DropdownMenuItem(
                        value: 'google_form',
                        child: Text('Google Form'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _submissionMethod = value;
                            });
                          },
                  ),

                  const SizedBox(height: 16),

                  if (_submissionMethod == 'artifact') ...[
                    _buildArtifactOption(
                      value: _allowGitHub,
                      icon: Icons.link_rounded,
                      title: 'GitHub Repository Link',
                      onChanged: (value) {
                        setState(() {
                          _allowGitHub = value;
                        });
                      },
                    ),
                    _buildArtifactOption(
                      value: _allowZip,
                      icon: Icons.folder_zip_outlined,
                      title: 'ZIP File',
                      onChanged: (value) {
                        setState(() {
                          _allowZip = value;
                        });
                      },
                    ),
                    _buildArtifactOption(
                      value: _allowTechnicalDocument,
                      icon: Icons.description_outlined,
                      title: 'Technical Document',
                      onChanged: (value) {
                        setState(() {
                          _allowTechnicalDocument = value;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 26),

                  // ==================================================
                  // DETAILS
                  // ==================================================
                  _buildSectionTitle(
                    'Assessment Details',
                    'Enter the information students will see.',
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _titleController,

                    enabled: !_isSaving,

                    textCapitalization: TextCapitalization.sentences,

                    decoration: _inputDecoration(
                      label: 'Title',
                      icon: Icons.title_rounded,
                      hint: 'e.g. Quiz 1 - Flutter Fundamentals',
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the assessment title.';
                      }

                      if (value.trim().length < 3) {
                        return 'Title is too short.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _instructionsController,

                    enabled: !_isSaving,

                    maxLines: 5,

                    textCapitalization: TextCapitalization.sentences,

                    decoration: _inputDecoration(
                      label: 'Instructions',
                      icon: Icons.notes_rounded,
                      hint: 'Explain what students need to do.',
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the assessment instructions.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 26),

                  // ==================================================
                  // EXTERNAL LINK
                  // ==================================================
                  if (_submissionMethod == 'google_form') ...[
                    _buildSectionTitle(
                      'Google Form',
                      'Paste the form link where students will answer.',
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _urlController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: _inputDecoration(
                        label: 'Google Form URL',
                        icon: Icons.link_rounded,
                        hint: 'https://docs.google.com/forms/...',
                      ),
                      validator: (value) {
                        if (_submissionMethod != 'google_form') {
                          return null;
                        }

                        final String text = value?.trim() ?? '';
                        final Uri? uri = Uri.tryParse(text);

                        if (text.isEmpty) {
                          return 'Enter the Google Form URL.';
                        }

                        if (uri == null ||
                            uri.scheme != 'https' ||
                            !uri.hasAuthority) {
                          return 'Enter a valid HTTPS Google Form URL.';
                        }

                        final String host = uri.host.toLowerCase();
                        final bool isGoogleForm =
                            host == 'forms.gle' ||
                            (host == 'docs.google.com' &&
                                uri.path.toLowerCase().contains('/forms/'));

                        if (!isGoogleForm) {
                          return 'Use a forms.gle or docs.google.com/forms link.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: primaryTeal,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'GitHub and file options will be hidden. CASLMS '
                              'marks completion only after you verify the '
                              'student response as Complied.',
                              style: TextStyle(
                                color: textGrey,
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),
                  ],

                  // ==================================================
                  // GRADING / DEADLINE
                  // ==================================================
                  _buildSectionTitle(
                    'Grading & Deadline',
                    'Set the points and due date.',
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pointsController,

                    enabled: !_isSaving,

                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),

                    decoration: _inputDecoration(
                      label: 'Total Points',
                      icon: Icons.grade_outlined,
                      hint: 'e.g. 20',
                    ),

                    validator: (value) {
                      final double? points = double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (points == null || points <= 0) {
                        return 'Enter total points greater than zero.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _isSaving ? null : _selectDueDateTime,

                    borderRadius: BorderRadius.circular(16),

                    child: InputDecorator(
                      decoration: _inputDecoration(
                        label: 'Due Date & Time',
                        icon: Icons.event_rounded,
                      ),

                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDueDate(),
                              style: TextStyle(
                                color: _dueAt == null ? textGrey : textDark,
                                fontSize: 14,
                                fontWeight: _dueAt == null
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right_rounded,
                            color: textGrey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // CURRENT DELIVERY METHOD
                  // ==================================================
                  _buildDeliveryMethodCard(),
                ],
              ),
            ),
          ),
        ),
      ),

      // ============================================================
      // SAVE BUTTONS
      // ============================================================
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),

          decoration: BoxDecoration(
            color: Colors.white,

            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),

          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _saveAssessment(status: 'draft');
                        },

                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),

                    foregroundColor: primaryTeal,

                    side: const BorderSide(color: primaryTeal, width: 1.5),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),

                  child: _isSaving && _savingStatus == 'draft'
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: primaryTeal,
                          ),
                        )
                      : const Text(
                          'Save Draft',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          _saveAssessment(status: 'published');
                        },

                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),

                    backgroundColor: primaryTeal,

                    elevation: 0,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),

                  child: _isSaving && _savingStatus == 'published'
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Publish',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MODULE BANNER
  // ============================================================

  Widget _buildModuleBanner() {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: primaryTeal,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),

              borderRadius: BorderRadius.circular(15),
            ),

            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  widget.courseCode,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  widget.moduleTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  widget.courseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DELIVERY TYPE
  // ============================================================

  Widget _buildArtifactOption({
    required bool value,
    required IconData icon,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: _isSaving
            ? null
            : (selected) {
                onChanged(selected ?? false);
              },
        activeColor: primaryTeal,
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: Icon(icon, color: primaryTeal),
        title: Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryMethodCard() {
    final bool googleForm = _submissionMethod == 'google_form';

    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white,

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

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              googleForm ? Icons.description_outlined : Icons.upload_file,
              color: primaryTeal,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  googleForm
                      ? 'Google Form Assessment'
                      : 'GitHub / File Submission',
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  googleForm
                      ? 'You verify each student as Complied or Not Complied'
                      : 'Only selected submission options will be shown',
                  style: const TextStyle(color: textGrey, fontSize: 11),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(9),
            ),

            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: primaryTeal,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _buildSectionTitle(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          description,
          style: const TextStyle(color: textGrey, fontSize: 11.5),
        ),
      ],
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Icon(icon, color: primaryTeal, size: 21),

      filled: true,
      fillColor: Colors.white,

      labelStyle: const TextStyle(color: textGrey, fontWeight: FontWeight.w600),

      hintStyle: const TextStyle(color: Color(0xFFA0A8B7), fontSize: 13),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryTeal, width: 1.7),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.7),
      ),
    );
  }
}
