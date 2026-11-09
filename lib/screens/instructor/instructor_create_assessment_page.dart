import '../../core/app_colors.dart';

import 'package:flutter/material.dart';

import 'instructor_task_widgets.dart';

import '../../services/assessment_service.dart';
import '../../services/section_audience_service.dart';
import 'section_audience_picker.dart';

class InstructorCreateAssessmentScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;

  final String courseCode;
  final String courseTitle;
  final String moduleTitle;
  final AssessmentService? assessmentService;
  final List<Map<String, dynamic>> sections;
  final List<String> moduleSectionIds;
  final String? initialSectionId;

  const InstructorCreateAssessmentScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.courseCode,
    required this.courseTitle,
    required this.moduleTitle,
    required this.sections,
    required this.moduleSectionIds,
    this.initialSectionId,
    this.assessmentService,
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

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  // ============================================================
  // FORM
  // ============================================================

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _instructionsController = TextEditingController();

  final TextEditingController _urlController = TextEditingController();

  final TextEditingController _pointsController = TextEditingController();

  late final AssessmentService _assessmentService =
      widget.assessmentService ?? AssessmentService();

  String _assessmentType = 'quiz';

  String _submissionMethod = 'artifact';

  bool _allowGitHub = true;
  bool _allowZip = true;
  bool _allowTechnicalDocument = true;

  DateTime? _dueAt;

  bool _isSaving = false;

  String? _savingStatus;
  late List<String> _sectionIds;

  @override
  void initState() {
    super.initState();
    final parent = SectionAudienceService.validate(widget.moduleSectionIds);
    final initial = widget.initialSectionId?.trim() ?? '';
    _sectionIds =
        initial.isNotEmpty && SectionAudienceService.allows(parent, initial)
        ? <String>[initial]
        : List<String>.from(parent);
  }

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
          data: Theme.of(context)
              .copyWith(colorScheme: Theme.of(context).colorScheme),
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
          data: Theme.of(context)
              .copyWith(colorScheme: Theme.of(context).colorScheme),
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
    if (_sectionIds.isEmpty) {
      _showError('Choose the sections assigned to this assessment.');
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
            sectionIds: _sectionIds,
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
  Widget build(BuildContext context) => InstructorTaskScaffold(
    title: 'Create assessment',
    subtitle:
        'Choose a submission method, add the details, and set the grading.',
    contextLabel: [
      widget.courseCode,
      widget.moduleTitle,
    ].where((v) => v.trim().isNotEmpty).join(' · '),
    busy: _isSaving,
    body: _buildAssessmentForm(),
    footer: InstructorTaskActions(
      children: [
        OutlinedButton(
          onPressed: _isSaving ? null : () => _saveAssessment(status: 'draft'),
          child: Text(
            _isSaving && _savingStatus == 'draft'
                ? 'Saving draft…'
                : 'Save draft',
          ),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () => _saveAssessment(status: 'published'),
          child: Text(
            _isSaving && _savingStatus == 'published'
                ? 'Publishing…'
                : 'Publish assessment',
          ),
        ),
      ],
    ),
  );

  Widget _buildAssessmentForm() => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),

        child: Form(
          key: _formKey,

          child: ListView(
            physics: const BouncingScrollPhysics(),

            padding: InstructorTaskScaffold.paddingOf(context),

            children: [
              InstructorFormColumns(
                primary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InstructorFormSection(
                      title: 'Assessment Type',
                      description:
                          'Choose what kind of task you are publishing.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _assessmentType,

                            decoration: _inputDecoration(
                              label: 'Type',
                              icon: Icons.category_outlined,
                            ),

                            items: const [
                              DropdownMenuItem(
                                value: 'quiz',
                                child: Text('Quiz'),
                              ),
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
                              DropdownMenuItem(
                                value: 'exam',
                                child: Text('Exam'),
                              ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    InstructorFormSection(
                      title: 'Submission Method',
                      description:
                          'Students will see only the method selected here.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    InstructorFormSection(
                      title: 'Assessment Details',
                      description: 'Enter the information students will see.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_submissionMethod == 'google_form')
                      InstructorFormSection(
                        title: 'Google Form',
                        description:
                            'Paste the form link where students will answer.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                final text = value?.trim() ?? '';
                                final uri = Uri.tryParse(text);
                                if (text.isEmpty) {
                                  return 'Enter the Google Form URL.';
                                }
                                if (uri == null ||
                                    uri.scheme != 'https' ||
                                    !uri.hasAuthority) {
                                  return 'Enter a valid HTTPS Google Form URL.';
                                }
                                final host = uri.host.toLowerCase();
                                if (!(host == 'forms.gle' ||
                                    (host == 'docs.google.com' &&
                                        uri.path.toLowerCase().contains(
                                          '/forms/',
                                        )))) {
                                  return 'Use a forms.gle or docs.google.com/forms link.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            const InstructorTaskNotice(
                              text: 'GitHub and file options are hidden for this method. Verify each student response as Complied to mark completion.',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                secondary: InstructorFormSection(
                  title: 'Grading & Deadline',
                  description: 'Set the points and due date.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Assigned sections',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Defaults to the module audience and can only be narrowed.',
                      ),
                      SectionAudiencePicker(
                        sections: widget.sections,
                        parentAudience: widget.moduleSectionIds,
                        value: _sectionIds,
                        enabled: !_isSaving,
                        onChanged: (value) =>
                            setState(() => _sectionIds = value),
                      ),
                      const Divider(height: 28),
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

                              Icon(
                                Icons.chevron_right_rounded,
                                color: textGrey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ============================================================
  // MODULE BANNER
  // ============================================================

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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
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
            style: TextStyle(
              color: textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

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
      fillColor: Theme.of(context).colorScheme.surface,

      labelStyle: TextStyle(color: textGrey, fontWeight: FontWeight.w600),

      hintStyle: const TextStyle(color: Color(0xFFA0A8B7), fontSize: 13),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryTeal, width: 1.7),
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
