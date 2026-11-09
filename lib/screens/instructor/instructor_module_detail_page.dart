import '../shared/page_loading_state.dart';
import 'instructor_task_widgets.dart';
import '../../services/instructor_workspace_context.dart';
import '../shared/workspace_widgets.dart';
import '../../core/app_colors.dart';
import '../shared/grading_ui.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/material.dart';

import '../../services/assessment_service.dart';
import '../../services/course_section_service.dart';
import '../../services/section_audience_service.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/learning_material_service.dart';
import '../../services/notification_service.dart';

import 'instructor_add_learning_material_page.dart';
import 'instructor_assessment_grading_page.dart';
import 'instructor_ai_quiz_editor_page.dart';
import 'instructor_create_assessment_page.dart';

class InstructorModuleDetailScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String courseCode;
  final String courseTitle;
  final String moduleTitle;
  final String focusResourceId;
  final String focusAssessmentId;
  final int initialTab;

  const InstructorModuleDetailScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.courseCode,
    required this.courseTitle,
    required this.moduleTitle,
    this.focusResourceId = '',
    this.focusAssessmentId = '',
    this.initialTab = 0,
  });

  @override
  State<InstructorModuleDetailScreen> createState() =>
      _InstructorModuleDetailScreenState();
}

class _InstructorModuleDetailScreenState
    extends State<InstructorModuleDetailScreen> {
  bool _retryingNotifications = false;

  Future<void> _retryNotifications() async {
    if (_retryingNotifications) return;
    setState(() => _retryingNotifications = true);
    try {
      await NotificationService().retryModuleNotifications(
        moduleId: widget.moduleId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing module notifications delivered.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(
          'Notification delivery was interrupted. Retry when connected: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _retryingNotifications = false);
    }
  }
  // ============================================================
  // DESIGN
  // ============================================================

  Color get primaryTeal => AppColors.resolve(context, AppColors.primaryBlue);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);

  Color get green => AppColors.resolve(context, AppColors.green);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get red => AppColors.resolve(context, AppColors.error);
  Color get blue => AppColors.resolve(context, AppColors.primaryBlue);
  Color get purple => AppColors.resolve(context, AppColors.purple);

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AssessmentService _assessmentService = AssessmentService();

  final FirebaseAiService _firebaseAiService = FirebaseAiService();

  final LearningMaterialService _learningMaterialService =
      LearningMaterialService();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _module;

  List<Map<String, dynamic>> _materials = [];

  List<Map<String, dynamic>> _assessments = [];
  String? _activeSectionId;
  List<Map<String, dynamic>> _activeSections = [];
  String get _sectionLabel => _activeSectionId == null
      ? 'All sections'
      : _activeSections
            .firstWhere((s) => s['id'] == _activeSectionId)['name']
            .toString();
  String get _assignedSectionLabel {
    final module = _module;
    if (module == null) return 'Unavailable';
    try {
      return SectionAudienceService.label(
        SectionAudienceService.stored(module),
        _activeSections,
      );
    } on FormatException {
      return 'Invalid audience';
    }
  }

  List<Map<String, dynamic>> get _visibleAssessments => _assessments
      .where(
        (a) =>
            _activeSectionId == null ||
            (a['sectionId'] ?? '').toString().isEmpty ||
            a['sectionId'] == _activeSectionId,
      )
      .toList();

  final Set<String> _busyMaterialIds = {};

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

  Future<void> _loadPage({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final sections = await CourseSectionService().getSections(
        widget.courseId,
      );
      if (!mounted ||
          uid == null ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final selection = InstructorWorkspaceContext.instance;
      final activeSections = sections
          .where((row) => row['status'] == 'active')
          .toList();
      final requested =
          selection.userId == uid && selection.courseId == widget.courseId
          ? selection.sectionId
          : null;
      final activeSectionId = activeSections.any((s) => s['id'] == requested)
          ? requested
          : null;
      // ========================================================
      // MODULE
      // ========================================================

      final DocumentSnapshot<Map<String, dynamic>> moduleDocument =
          await _firestore.collection('modules').doc(widget.moduleId).get();

      if (!moduleDocument.exists || moduleDocument.data() == null) {
        throw Exception('Module could not be found.');
      }

      final Map<String, dynamic> moduleData = moduleDocument.data()!;

      final String moduleCourseId = (moduleData['courseId'] ?? '')
          .toString()
          .trim();

      if (moduleCourseId != widget.courseId) {
        throw Exception('This module does not belong to the selected course.');
      }

      // ========================================================
      // PHASE 7C-6: PREPARE EXISTING MATERIALS FOR AI
      //
      // Older materials uploaded before the AI metadata update
      // are safely backfilled here. Materials that are already
      // prepared are skipped by the service.
      // ========================================================

      await _learningMaterialService.prepareModuleMaterialsForAi(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
      );

      // ========================================================
      // LEARNING MATERIALS
      //
      // Instructors must see both Published and Draft resources.
      // ========================================================

      final List<Map<String, dynamic>> materials =
          await _learningMaterialService.getModuleMaterials(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
            publishedOnly: false,
          );

      // ========================================================
      // ASSESSMENTS
      // ========================================================

      final List<Map<String, dynamic>> assessments = await _assessmentService
          .getModuleAssessments(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeSections = activeSections;
        _activeSectionId = activeSectionId;
        _module = {
          ...moduleData,
          'id': moduleDocument.id,
          'moduleId': moduleDocument.id,
        };

        _materials = List<Map<String, dynamic>>.from(materials);
        _assessments = List<Map<String, dynamic>>.from(assessments);
        if (widget.focusResourceId.isNotEmpty) {
          _materials.sort(
            (a, b) =>
                ((b['resourceId'] ?? b['materialId'] ?? b['id']) ==
                            widget.focusResourceId
                        ? 1
                        : 0)
                    .compareTo(
                      (a['resourceId'] ?? a['materialId'] ?? a['id']) ==
                              widget.focusResourceId
                          ? 1
                          : 0,
                    ),
          );
        }
        if (widget.focusAssessmentId.isNotEmpty) {
          _assessments.sort(
            (a, b) =>
                ((b['assessmentId'] ?? b['id']) == widget.focusAssessmentId
                        ? 1
                        : 0)
                    .compareTo(
                      (a['assessmentId'] ?? a['id']) == widget.focusAssessmentId
                          ? 1
                          : 0,
                    ),
          );
        }

        _isLoading = false;
        _errorMessage = null;
      });
    } on LearningMaterialException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } on AssessmentServiceException catch (e) {
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
  // ADD MATERIAL
  // ============================================================

  Future<void> _addLearningMaterial() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => InstructorAddLearningMaterialScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          moduleTitle: _moduleTitle,
          sections: _activeSections,
          moduleSectionIds: SectionAudienceService.stored(_module!),
          initialSectionId: _activeSectionId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _loadPage(showLoading: false);
    }
  }

  // ============================================================
  // MATERIAL ID
  // ============================================================

  String _materialId(Map<String, dynamic> material) {
    return (material['resourceId'] ??
            material['materialId'] ??
            material['id'] ??
            '')
        .toString()
        .trim();
  }

  // ============================================================
  // CHANGE MATERIAL STATUS
  // ============================================================

  Future<void> _changeMaterialStatus(
    Map<String, dynamic> material,
    String newStatus,
  ) async {
    final String materialId = _materialId(material);

    if (materialId.isEmpty) {
      _showError('Learning material ID is missing.');

      return;
    }

    if (_busyMaterialIds.contains(materialId)) {
      return;
    }

    setState(() {
      _busyMaterialIds.add(materialId);
    });

    try {
      // ========================================================
      // IMPORTANT:
      // LearningMaterialService expects resourceId:
      // ========================================================

      await _learningMaterialService.updateMaterialStatus(
        resourceId: materialId,
        status: newStatus,
      );

      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      if (!mounted) {
        return;
      }

      final String message = newStatus == 'published'
          ? 'Learning material published.'
          : 'Learning material moved to draft.';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on LearningMaterialException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to update learning material: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyMaterialIds.remove(materialId);
        });
      }
    }
  }

  // ============================================================
  // DELETE MATERIAL
  // ============================================================

  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    final String materialId = _materialId(material);

    if (materialId.isEmpty) {
      _showError('Learning material ID is missing.');

      return;
    }

    if (_busyMaterialIds.contains(materialId)) {
      return;
    }

    final String title =
        (material['title'] ?? material['fileName'] ?? 'Learning Material')
            .toString();

    final String deliveryType = _materialDeliveryType(material);

    final bool uploadedFile = deliveryType == 'uploaded_file';

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: red, size: 34),

          title: const Text('Delete Learning Material'),

          content: Text(
            uploadedFile
                ? 'Are you sure you want to delete "$title"?\n\n'
                      'The file will also be removed from Supabase Storage. '
                      'This action cannot be undone.'
                : 'Are you sure you want to delete "$title"?\n\n'
                      'This action cannot be undone.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              style: FilledButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _busyMaterialIds.add(materialId);
    });

    try {
      // For uploaded files:
      // Supabase file + Firestore metadata are removed.
      //
      // For external links:
      // Only the Firestore metadata document is removed.

      await _learningMaterialService.deleteMaterial(materialId);

      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Learning material deleted.'),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on LearningMaterialException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to delete learning material: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyMaterialIds.remove(materialId);
        });
      }
    }
  }

  // ============================================================
  // CREATE ASSESSMENT
  // ============================================================

  Future<void> _createAssessment() async {
    final dynamic result = await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) => InstructorCreateAssessmentScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          courseCode: widget.courseCode,
          courseTitle: widget.courseTitle,
          moduleTitle: _moduleTitle,
          sections: _activeSections,
          moduleSectionIds: SectionAudienceService.stored(_module!),
          initialSectionId: _activeSectionId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result is Map && result['created'] == true) {
      await _loadPage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment created successfully.'),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // PHASE 13C-3: REVIEW / EDIT AI QUIZ
  // ============================================================

  Future<void> _editAiQuizAssessment(Map<String, dynamic> assessment) async {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    final bool? updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InstructorAiQuizEditorScreen(
          assessmentId: assessmentId,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _loadPage(showLoading: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI quiz draft updated.'),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // OPEN GRADING
  // ============================================================

  Future<void> _openAssessmentGrading(Map<String, dynamic> assessment) async {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    await Navigator.push(
      context,

      GradeRoute(
        builder: (context) =>
            InstructorAssessmentGradingScreen(assessmentId: assessmentId),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadPage();
  }

  // ============================================================
  // PHASE 13C-4: VALIDATE AND PUBLISH AI QUIZ
  // ============================================================

  Future<void> _publishAiQuiz(Map<String, dynamic> assessment) async {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    try {
      // Always re-read the latest Firestore version before publishing.
      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('assessments')
          .doc(assessmentId)
          .get();

      if (!document.exists || document.data() == null) {
        throw AssessmentServiceException('AI quiz could not be found.');
      }

      final Map<String, dynamic> data = document.data()!;

      final String courseId = (data['courseId'] ?? '').toString().trim();

      final String moduleId = (data['moduleId'] ?? '').toString().trim();

      final String assessmentType = (data['assessmentType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String deliveryType = (data['deliveryType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String currentStatus = (data['status'] ?? 'draft')
          .toString()
          .trim()
          .toLowerCase();

      final String title = (data['title'] ?? '').toString().trim();

      final String instructions = (data['instructions'] ?? '')
          .toString()
          .trim();

      if (courseId != widget.courseId || moduleId != widget.moduleId) {
        throw AssessmentServiceException(
          'This quiz does not belong to the selected module.',
        );
      }

      if (assessmentType != 'quiz' || deliveryType != 'ai_generated') {
        throw AssessmentServiceException(
          'This publish flow is only for AI-generated quizzes.',
        );
      }

      if (currentStatus == 'published' &&
          (data['quizVersion'] ?? '').toString().trim().isNotEmpty) {
        throw AssessmentServiceException('This AI quiz is already published.');
      }

      if (currentStatus == 'closed') {
        throw AssessmentServiceException(
          'Move this assessment to Draft before publishing it again.',
        );
      }

      if (title.isEmpty) {
        throw AssessmentServiceException(
          'Quiz title is required before publishing.',
        );
      }

      if (instructions.isEmpty) {
        throw AssessmentServiceException(
          'Quiz instructions are required before publishing.',
        );
      }

      final dynamic rawQuestions = data['questions'];

      if (rawQuestions is! List || rawQuestions.isEmpty) {
        throw AssessmentServiceException(
          'Add at least one valid question before publishing.',
        );
      }

      int calculatedPoints = 0;

      for (int index = 0; index < rawQuestions.length; index++) {
        final dynamic rawQuestion = rawQuestions[index];

        if (rawQuestion is! Map) {
          throw AssessmentServiceException(
            'Question ${index + 1} has an invalid format.',
          );
        }

        final Map<String, dynamic> question = Map<String, dynamic>.from(
          rawQuestion,
        );

        final String questionText = (question['question'] ?? '')
            .toString()
            .trim();

        final dynamic rawOptions = question['options'];

        final int? correctAnswerIndex = (question['correctAnswerIndex'] as num?)
            ?.toInt();

        final int points = (question['points'] as num?)?.toInt() ?? 0;

        if (questionText.isEmpty) {
          throw AssessmentServiceException('Question ${index + 1} is empty.');
        }

        if (rawOptions is! List || rawOptions.length != 4) {
          throw AssessmentServiceException(
            'Question ${index + 1} must have exactly 4 choices.',
          );
        }

        final List<String> options = rawOptions
            .map((dynamic value) => value.toString().trim())
            .toList();

        if (options.any((String option) => option.isEmpty)) {
          throw AssessmentServiceException(
            'Question ${index + 1} contains an empty choice.',
          );
        }

        if (options.toSet().length != options.length) {
          throw AssessmentServiceException(
            'Question ${index + 1} contains duplicate choices.',
          );
        }

        if (correctAnswerIndex == null ||
            correctAnswerIndex < 0 ||
            correctAnswerIndex > 3) {
          throw AssessmentServiceException(
            'Question ${index + 1} does not have a valid correct answer.',
          );
        }

        if (points <= 0) {
          throw AssessmentServiceException(
            'Question ${index + 1} must have at least 1 point.',
          );
        }

        calculatedPoints += points;
      }

      // A published quiz should have a future deadline.
      final dynamic rawDueAt = data['dueAt'];

      DateTime? dueAt;

      if (rawDueAt is Timestamp) {
        dueAt = rawDueAt.toDate();
      } else if (rawDueAt is DateTime) {
        dueAt = rawDueAt;
      }

      if (dueAt == null) {
        throw AssessmentServiceException(
          'Set a due date before publishing the AI quiz.',
        );
      }

      if (!dueAt.isAfter(DateTime.now())) {
        throw AssessmentServiceException(
          'The quiz due date must be in the future.',
        );
      }

      final num storedTotalPoints = (data['totalPoints'] as num?) ?? 0;

      // Keep stored totals consistent with the edited questions.
      if (storedTotalPoints.toInt() != calculatedPoints) {
        await document.reference.update({
          'totalPoints': calculatedPoints,
          'questionCount': rawQuestions.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) {
        return;
      }

      // Load the course's existing active sections.
      final List<Map<String, dynamic>> activeSections =
          (await CourseSectionService().getSections(widget.courseId))
              .where((Map<String, dynamic> section) {
                final String id = (section['id'] ?? '').toString().trim();
                final String status = (section['status'] ?? 'active')
                    .toString()
                    .trim()
                    .toLowerCase();

                return id.isNotEmpty && status == 'active';
              })
              .toList();

      if (activeSections.isEmpty) {
        throw AssessmentServiceException(
          'This course has no active sections. '
          'Create a section before publishing the quiz.',
        );
      }

      if (!mounted) {
        return;
      }

      // Require the instructor to select the target section.
      final selection = InstructorWorkspaceContext.instance;
      final inheritedSection =
          selection.userId == FirebaseAuth.instance.currentUser?.uid &&
              selection.courseId == widget.courseId &&
              activeSections.any((row) => row['id'] == selection.sectionId)
          ? selection.sectionId
          : null;
      final String? selectedSectionId =
          inheritedSection ??
          await showDialog<String>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                icon: Icon(Icons.groups_rounded, color: primaryTeal),
                title: const Text('Select Quiz Section'),
                content: SizedBox(
                  width: 430,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: activeSections.map((section) {
                        final String id = (section['id'] ?? '')
                            .toString()
                            .trim();
                        final String name =
                            (section['name'] ?? 'Unnamed section')
                                .toString()
                                .trim();
                        final String identifier = (section['identifier'] ?? '')
                            .toString()
                            .trim();

                        return ListTile(
                          leading: Icon(
                            Icons.class_outlined,
                            color: primaryTeal,
                          ),
                          title: Text(name),
                          subtitle: identifier.isEmpty
                              ? null
                              : Text(identifier),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(dialogContext).pop(id);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );

      if (!mounted || selectedSectionId == null) {
        return;
      }

      final Map<String, dynamic> selectedSection = activeSections.firstWhere(
        (section) => section['id'] == selectedSectionId,
      );

      final String selectedSectionName = (selectedSection['name'] ?? 'Section')
          .toString()
          .trim();

      final String selectedSectionIdentifier =
          (selectedSection['identifier'] ?? '').toString().trim();

      final String selectedSectionLabel = selectedSectionIdentifier.isEmpty
          ? selectedSectionName
          : '$selectedSectionName ($selectedSectionIdentifier)';
      final bool? confirmed = await showDialog<bool>(
        context: context,

        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: Icon(Icons.publish_rounded, color: primaryTeal, size: 34),

            title: const Text('Publish AI Quiz?'),

            content: SizedBox(
              width: 430,

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'CASLMS checked the quiz and found no blocking validation errors.',
                    style: TextStyle(color: textGrey, height: 1.45),
                  ),

                  const SizedBox(height: 18),

                  _publishSummaryRow('Quiz', title),

                  _publishSummaryRow('Section', selectedSectionLabel),

                  _publishSummaryRow('Questions', '${rawQuestions.length}'),

                  _publishSummaryRow('Total points', '$calculatedPoints'),

                  _publishSummaryRow(
                    'Due',
                    _formatDate(Timestamp.fromDate(dueAt!)),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'After publishing, enrolled students will be able to see this quiz. '
                      'The student quiz-taking screen is implemented in the next phase.',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },

                child: const Text('Cancel'),
              ),

              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },

                icon: const Icon(Icons.publish_rounded),

                label: const Text('Publish Quiz'),

                style: FilledButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) {
        return;
      }

      // Publish through the trusted backend.
      // The backend stores answer keys privately and publishes
      // sanitized questions in one Firestore transaction.
      final User? publishingUser = FirebaseAuth.instance.currentUser;

      if (publishingUser == null) {
        throw AssessmentServiceException(
          'Please sign in again before publishing.',
        );
      }

      final String? idToken = await publishingUser.getIdToken(true);
      final appCheck = await FirebaseAppCheck.instance.getToken(true);

      if (idToken == null ||
          idToken.isEmpty ||
          appCheck == null ||
          appCheck.isEmpty) {
        throw AssessmentServiceException(
          'Unable to verify your instructor account.',
        );
      }

      final response = await sb.Supabase.instance.client.functions.invoke(
        'assessment-submission',
        headers: <String, String>{
          'Authorization': 'Bearer $idToken',
          'X-Firebase-AppCheck': appCheck,
        },
        body: <String, dynamic>{
          'action': 'publish_ai_quiz',
          'sectionId': selectedSectionId,
          'assessmentId': assessmentId,
        },
      );

      final dynamic rawResponse = response.data;

      if (rawResponse is! Map) {
        throw AssessmentServiceException(
          'The publishing server returned an invalid response.',
        );
      }

      final Map<String, dynamic> result = Map<String, dynamic>.from(
        rawResponse,
      );

      if (result['success'] != true) {
        throw AssessmentServiceException(
          (result['error'] ?? 'Unable to publish this quiz.').toString(),
        );
      }

      // Preserve existing best-effort student notifications.
      // A notification error must not undo a successful publish.
      try {
        await NotificationService().createAssessmentNotifications(
          assessmentId: assessmentId,
        );
      } catch (notificationError) {
        debugPrint(
          'AI quiz published, but notifications require retry: '
          '$notificationError',
        );
      }

      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI quiz published successfully.'),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AssessmentServiceException catch (e) {
      _showError(e.message);
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Unable to publish the AI quiz.');
    } catch (e) {
      _showError('Unable to publish the AI quiz: $e');
    }
  }

  Widget _publishSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: textGrey,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHANGE ASSESSMENT STATUS
  // ============================================================

  Future<void> _changeStatus(
    Map<String, dynamic> assessment,
    String status,
  ) async {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    try {
      await _assessmentService.updateAssessmentStatus(
        assessmentId: assessmentId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      await _loadPage();

      if (!mounted) {
        return;
      }

      String message;

      switch (status) {
        case 'published':
          message = 'Assessment published.';
          break;

        case 'closed':
          message = 'Assessment closed.';
          break;

        default:
          message = 'Assessment moved to draft.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AssessmentServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to update assessment: $e');
    }
  }

  // ============================================================
  // DELETE ASSESSMENT
  // ============================================================

  Future<void> _deleteAssessment(Map<String, dynamic> assessment) async {
    final String assessmentId =
        (assessment['assessmentId'] ?? assessment['id'] ?? '')
            .toString()
            .trim();

    if (assessmentId.isEmpty) {
      _showError('Assessment ID is missing.');

      return;
    }

    final String title = (assessment['title'] ?? 'Assessment').toString();

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Assessment'),

          content: Text(
            'Are you sure you want to delete "$title"?\n\n'
            'This action cannot be undone.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: Text('Delete', style: TextStyle(color: red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _assessmentService.deleteAssessment(assessmentId);

      if (!mounted) {
        return;
      }

      await _loadPage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment deleted.'),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AssessmentServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to delete assessment: $e');
    }
  }

  // ============================================================
  // PHASE 13B: ANALYZE PDF WITH GEMINI
  // ============================================================

  Future<void> _showAiAnalysisDialog({
    required String title,
    required String analysis,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primaryTeal),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                analysis,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSavedAiAnalysis(Map<String, dynamic> material) async {
    final String analysis = (material['aiAnalysisSummary'] ?? '')
        .toString()
        .trim();

    final String title =
        (material['title'] ?? material['fileName'] ?? 'Learning Material')
            .toString();

    if (analysis.isEmpty) {
      _showError('No saved AI analysis is available yet.');

      return;
    }

    await _showAiAnalysisDialog(
      title: 'AI Analysis \u2014 $title',
      analysis: analysis,
    );
  }

  Future<void> _analyzeMaterialWithAi(
    Map<String, dynamic> material, {
    bool forceReanalyze = false,
  }) async {
    final String materialId = _materialId(material);

    if (materialId.isEmpty) {
      _showError('Learning material ID is missing.');

      return;
    }

    if (_busyMaterialIds.contains(materialId)) {
      return;
    }

    final String title =
        (material['title'] ?? material['fileName'] ?? 'Learning Material')
            .toString();

    final String typeLabel = _materialTypeLabel(material);

    final String existingAnalysis = (material['aiAnalysisSummary'] ?? '')
        .toString()
        .trim();

    final bool alreadyReady =
        _materialAiStatus(material) == 'ready' && existingAnalysis.isNotEmpty;

    // Important quota protection:
    // Clicking Analyze on an already-ready material simply opens
    // the saved result unless the instructor explicitly chooses
    // Re-analyze with AI.
    if (alreadyReady && !forceReanalyze) {
      await _showSavedAiAnalysis(material);

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(Icons.auto_awesome_rounded, color: primaryTeal, size: 34),
          title: Text(
            forceReanalyze
                ? 'Re-analyze Material with AI?'
                : 'Analyze Material with AI',
          ),
          content: Text(
            forceReanalyze
                ? '"$title" already has a saved AI analysis.\n\n'
                      'Re-analyzing sends another request to Gemini and '
                      'uses more of your AI quota.\n\nContinue?'
                : 'Gemini will analyze "$title" as a $typeLabel learning '
                      'material and create a short analysis based only on '
                      'its supported content.\n\n'
                      'DOCX, PPTX, and XLSX are converted to readable text '
                      'inside CASLMS before being sent to Gemini. '
                      'PDFs, supported images, and supported videos are '
                      'analyzed as multimodal input.\n\nContinue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(forceReanalyze ? 'Re-analyze' : 'Analyze'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _busyMaterialIds.add(materialId);
    });

    try {
      final AiMaterialAnalysisResult result = await _firebaseAiService
          .analyzeMaterial(
            material: material,
            courseTitle: widget.courseTitle,
            moduleTitle: _moduleTitle,
          );

      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      if (!mounted) {
        return;
      }

      await _showAiAnalysisDialog(
        title: 'AI Material Analysis',
        analysis: result.analysis,
      );
    } on FirebaseAiServiceException catch (e) {
      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      _showError(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }

      await _loadPage(showLoading: false);

      _showError('Unable to analyze learning material: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyMaterialIds.remove(materialId);
        });
      }
    }
  }

  // ============================================================
  // PHASE 13C-1: GENERATE AI QUIZ DRAFT
  // ============================================================

  Future<void> _generateAiQuizDraft(Map<String, dynamic> material) async {
    final String materialId = _materialId(material);

    if (materialId.isEmpty) {
      _showError('Learning material ID is missing.');

      return;
    }

    if (_busyMaterialIds.contains(materialId)) {
      return;
    }

    int questionCount = 5;
    String difficulty = 'medium';

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  icon: Icon(Icons.quiz_rounded, color: primaryTeal, size: 34),

                  title: const Text('Generate AI Quiz Draft'),

                  content: SizedBox(
                    width: 430,

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'Gemini will create multiple-choice questions using only this PDF.',
                          style: TextStyle(color: textGrey, height: 1.45),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Number of questions',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<int>(
                          initialValue: questionCount,

                          items: const [
                            DropdownMenuItem(
                              value: 5,
                              child: Text('5 questions'),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text('10 questions'),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text('15 questions'),
                            ),
                          ],

                          onChanged: (int? value) {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              questionCount = value;
                            });
                          },

                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.format_list_numbered_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Difficulty',
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: difficulty,

                          items: const [
                            DropdownMenuItem(
                              value: 'easy',
                              child: Text('Easy'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'hard',
                              child: Text('Hard'),
                            ),
                          ],

                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              difficulty = value;
                            });
                          },

                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.psychology_alt_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },

                      child: const Text('Cancel'),
                    ),

                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(true);
                      },

                      icon: const Icon(Icons.auto_awesome_rounded),

                      label: const Text('Generate'),

                      style: FilledButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary,
                      ),
                    ),
                  ],
                );
              },
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _busyMaterialIds.add(materialId);
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gemini is generating the quiz draft...'),
        backgroundColor: primaryTeal,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final AiQuizDraft draft = await _firebaseAiService.generateQuizDraft(
        material: material,
        courseTitle: widget.courseTitle,
        moduleTitle: _moduleTitle,
        questionCount: questionCount,
        difficulty: difficulty,
      );

      if (!mounted) {
        return;
      }

      await _showAiQuizDraft(draft);
    } on FirebaseAiServiceException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unable to generate AI quiz: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyMaterialIds.remove(materialId);
        });
      }
    }
  }

  // ============================================================
  // AI QUIZ DRAFT PREVIEW
  // ============================================================

  // ============================================================
  // PHASE 13C-2: SAVE AI QUIZ AS A DRAFT ASSESSMENT
  // ============================================================

  Future<String> _saveAiQuizDraftAsAssessment(AiQuizDraft draft) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw AssessmentServiceException('No instructor is currently logged in.');
    }

    // Verify that the signed-in account is an active instructor.
    final DocumentSnapshot<Map<String, dynamic>> userDocument = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDocument.exists || userDocument.data() == null) {
      throw AssessmentServiceException(
        'Instructor profile could not be found.',
      );
    }

    final Map<String, dynamic> userData = userDocument.data()!;

    final String role = (userData['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final String accountStatus = (userData['status'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();

    if (role != 'instructor') {
      throw AssessmentServiceException(
        'Only instructors can save AI-generated assessments.',
      );
    }

    if (accountStatus != 'active') {
      throw AssessmentServiceException(
        'This instructor account is not active.',
      );
    }

    // Verify the loaded module still belongs to this course.
    final String moduleCourseId = (_module?['courseId'] ?? '')
        .toString()
        .trim();

    if (moduleCourseId != widget.courseId) {
      throw AssessmentServiceException(
        'This module does not belong to the selected course.',
      );
    }

    if (draft.title.trim().isEmpty || draft.questions.isEmpty) {
      throw AssessmentServiceException(
        'The generated quiz draft is incomplete.',
      );
    }

    final List<Map<String, dynamic>> questions = draft.questions
        .asMap()
        .entries
        .map((MapEntry<int, AiQuizQuestion> entry) {
          final AiQuizQuestion question = entry.value;

          return {
            'order': entry.key + 1,
            'questionType': 'multiple_choice',
            'question': question.question.trim(),
            'options': question.options
                .map((String option) => option.trim())
                .toList(),
            'correctAnswerIndex': question.correctAnswerIndex,
            'explanation': question.explanation.trim(),
            'points': 1,
          };
        })
        .toList();

    final DocumentReference<Map<String, dynamic>> assessmentReference =
        _firestore.collection('assessments').doc();

    final String assessmentId = assessmentReference.id;

    await assessmentReference.set({
      'assessmentId': assessmentId,
      'courseId': widget.courseId,
      'moduleId': widget.moduleId,
      'createdBy': user.uid,

      'title': draft.title.trim(),
      'instructions': draft.instructions.trim(),

      'assessmentType': 'quiz',
      'deliveryType': 'ai_generated',
      'externalUrl': null,

      'totalPoints': draft.totalPoints,
      'dueAt': null,

      // Keep it hidden from students until instructor review.
      'status': 'draft',

      // AI-generated quiz content.
      'questions': questions,
      'questionCount': questions.length,
      'aiGenerated': true,
      'aiModel': 'gemini-3.7-flash',
      'aiDifficulty': draft.difficulty,
      'aiSourceResourceId': draft.sourceResourceId,
      'aiSourceFileName': draft.sourceFileName,

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return assessmentId;
  }

  Future<void> _showAiQuizDraft(AiQuizDraft draft) async {
    await showDialog<void>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primaryTeal),

              SizedBox(width: 10),

              Expanded(child: Text('AI Quiz Draft')),
            ],
          ),

          content: SizedBox(
            width: 650,
            height: 580,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  draft.title,

                  style: TextStyle(
                    color: textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  draft.instructions,

                  style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
                ),

                const SizedBox(height: 8),

                Text(
                  '${draft.questions.length} questions \u2022 '
                  '${_capitalize(draft.difficulty)} \u2022 '
                  '${draft.totalPoints} points',

                  style: TextStyle(
                    color: primaryTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 14),

                const Divider(height: 1),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    itemCount: draft.questions.length,

                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 14),

                    itemBuilder: (BuildContext context, int index) {
                      final AiQuizQuestion question = draft.questions[index];

                      return Container(
                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                            context,
                            AppColors.background,
                          ),

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(color: borderColor),
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              '${index + 1}. ${question.question}',

                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 10),

                            ...List.generate(question.options.length, (
                              int optionIndex,
                            ) {
                              final bool correct =
                                  optionIndex == question.correctAnswerIndex;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),

                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Icon(
                                      correct
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,

                                      size: 17,

                                      color: correct ? green : textGrey,
                                    ),

                                    const SizedBox(width: 8),

                                    Expanded(
                                      child: Text(
                                        question.options[optionIndex],

                                        style: TextStyle(
                                          color: correct ? green : textDark,

                                          fontWeight: correct
                                              ? FontWeight.w700
                                              : FontWeight.w500,

                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            if (question.explanation.isNotEmpty) ...[
                              const SizedBox(height: 4),

                              Text(
                                'Explanation: ${question.explanation}',

                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 10.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: const Text('Close'),
            ),

            FilledButton.icon(
              onPressed: () async {
                try {
                  final String assessmentId =
                      await _saveAiQuizDraftAsAssessment(draft);

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();

                  await _loadPage(showLoading: false);

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'AI quiz saved as Draft Assessment. '
                        'ID: $assessmentId',
                      ),
                      backgroundColor: primaryTeal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } on AssessmentServiceException catch (e) {
                  _showError(e.message);
                } on FirebaseException catch (e) {
                  _showError(e.message ?? 'Unable to save the AI quiz.');
                } catch (e) {
                  _showError('Unable to save the AI quiz: $e');
                }
              },

              icon: const Icon(Icons.save_outlined),

              label: const Text('Save as Draft'),

              style: FilledButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
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
  // MODULE VALUES
  // ============================================================

  String get _moduleTitle {
    return (_module?['title'] ?? widget.moduleTitle).toString();
  }

  String get _moduleDescription {
    return (_module?['description'] ?? '').toString().trim();
  }

  int get _moduleOrder {
    return (_module?['order'] as num?)?.toInt() ?? 0;
  }

  String get _moduleStatus {
    return (_module?['status'] ?? '').toString().trim().toLowerCase();
  }

  // ============================================================
  // DATE
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
      return 'No due date';
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
        '${local.day}, ${local.year} \u2022 '
        '$hour:$minute $period';
  }

  // ============================================================
  // GENERIC HELPERS
  // ============================================================

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }

  String _formatFileSize(dynamic value) {
    final int bytes = value is num ? value.toInt() : 0;

    if (bytes <= 0) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    final double kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final double mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} MB';
  }

  // ============================================================
  // MATERIAL HELPERS
  // ============================================================

  String _materialResourceType(Map<String, dynamic> material) {
    return (material['resourceType'] ?? 'file').toString().trim().toLowerCase();
  }

  String _materialDeliveryType(Map<String, dynamic> material) {
    return (material['deliveryType'] ?? 'uploaded_file')
        .toString()
        .trim()
        .toLowerCase();
  }

  String _materialStatus(Map<String, dynamic> material) {
    return (material['status'] ?? 'draft').toString().trim().toLowerCase();
  }

  // ============================================================
  // AI PREPARATION HELPERS
  // ============================================================

  String _materialAiStatus(Map<String, dynamic> material) {
    final bool eligible = material['aiEligible'] == true;

    if (!eligible) {
      return 'unsupported';
    }

    final String status = (material['aiProcessingStatus'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();

    switch (status) {
      case 'processing':
      case 'ready':
      case 'failed':
      case 'pending':
        return status;

      // Accept "completed" too in case an older/future backend
      // uses that wording. Display it as READY in the UI.
      case 'completed':
        return 'ready';

      default:
        return 'pending';
    }
  }

  String _materialAiStatusLabel(Map<String, dynamic> material) {
    switch (_materialAiStatus(material)) {
      case 'ready':
        return 'AI READY';

      case 'processing':
        return 'AI PROCESSING';

      case 'failed':
        return 'AI FAILED';

      case 'unsupported':
        return 'AI UNSUPPORTED';

      default:
        return 'AI PENDING';
    }
  }

  Color _materialAiStatusColor(Map<String, dynamic> material) {
    switch (_materialAiStatus(material)) {
      case 'ready':
        return green;

      case 'processing':
        return blue;

      case 'failed':
        return red;

      case 'unsupported':
        return textGrey;

      default:
        return purple;
    }
  }

  IconData _materialAiStatusIcon(Map<String, dynamic> material) {
    switch (_materialAiStatus(material)) {
      case 'ready':
        return Icons.check_circle_outline_rounded;

      case 'processing':
        return Icons.sync_rounded;

      case 'failed':
        return Icons.error_outline_rounded;

      case 'unsupported':
        return Icons.block_rounded;

      default:
        return Icons.auto_awesome_rounded;
    }
  }

  IconData _materialIcon(Map<String, dynamic> material) {
    final String deliveryType = _materialDeliveryType(material);

    if (deliveryType == 'external_link') {
      if (_materialResourceType(material) == 'video') {
        return Icons.play_circle_outline_rounded;
      }

      return Icons.link_rounded;
    }

    switch (_materialResourceType(material)) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;

      case 'document':
        return Icons.description_rounded;

      case 'presentation':
        return Icons.slideshow_rounded;

      case 'spreadsheet':
        return Icons.table_chart_rounded;

      case 'image':
        return Icons.image_rounded;

      case 'video':
        return Icons.video_file_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _materialColor(Map<String, dynamic> material) {
    final String deliveryType = _materialDeliveryType(material);

    if (deliveryType == 'external_link') {
      return blue;
    }

    switch (_materialResourceType(material)) {
      case 'pdf':
        return red;

      case 'document':
        return blue;

      case 'presentation':
        return orange;

      case 'spreadsheet':
        return green;

      case 'image':
        return purple;

      case 'video':
        return blue;

      default:
        return primaryTeal;
    }
  }

  String _materialTypeLabel(Map<String, dynamic> material) {
    if (_materialDeliveryType(material) == 'external_link') {
      if (_materialResourceType(material) == 'video') {
        return 'Video Link';
      }

      return 'External Link';
    }

    switch (_materialResourceType(material)) {
      case 'pdf':
        return 'PDF';

      case 'document':
        return 'Document';

      case 'presentation':
        return 'Presentation';

      case 'spreadsheet':
        return 'Spreadsheet';

      case 'image':
        return 'Image';

      case 'video':
        return 'Video';

      default:
        return 'File';
    }
  }

  // ============================================================
  // ASSESSMENT HELPERS
  // ============================================================

  IconData _assessmentIcon(String type) {
    switch (type.toLowerCase()) {
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return green;

      case 'closed':
        return red;

      default:
        return orange;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Module')),
        body: _buildErrorState(),
      );
    }
    return InstructorTaskScaffold(
      title: _moduleTitle,
      highlightHeading: true,
      subtitle: [
        'Viewing: $_sectionLabel',
        widget.courseCode,
        widget.courseTitle,
        _moduleStatus,
      ].where((value) => value.isNotEmpty).join(' • '),
      actions: [
        IconButton(
          tooltip: 'Refresh module',
          onPressed: () => _loadPage(showLoading: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Module information',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Module information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    _buildModuleHeader(),
                    const SizedBox(height: 20),
                    _buildFutureAiCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Retry missing notifications',
          onPressed: _retryingNotifications ? null : _retryNotifications,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
      ],
      body: ListView(
        padding: InstructorTaskScaffold.paddingOf(context),
        children: [
          InstructorFormSection(
            title: 'Viewing section: $_sectionLabel',
            description:
                'Module assigned to: $_assignedSectionLabel. The selector below '
                'only filters this instructor view; it does not change who can access the module.',
            child: DropdownButtonFormField<String>(
              key: ValueKey(_activeSectionId),
              initialValue: _activeSectionId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'View section'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All sections')),
                for (final row in _activeSections)
                  DropdownMenuItem(
                    value: row['id'].toString(),
                    child: Text(row['name'].toString()),
                  ),
              ],
              onChanged: (value) async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                final selection = InstructorWorkspaceContext.instance;
                final revision = selection.beginCourse(uid, widget.courseId);
                try {
                  final verified = await CourseSectionService().getSections(
                    widget.courseId,
                  );
                  if (!mounted ||
                      FirebaseAuth.instance.currentUser?.uid != uid) {
                    return;
                  }
                  if (!selection.commitSections(
                    revision,
                    uid,
                    widget.courseId,
                    verified,
                    requested: value,
                  )) {
                    return;
                  }
                  setState(() {
                    _activeSections = verified
                        .where((r) => r['status'] == 'active')
                        .toList();
                    _activeSectionId = selection.sectionId;
                  });
                } catch (_) {
                  if (mounted) {
                    _showError(
                      'Unable to validate this section. Please refresh.',
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          for (final assessmentFirst
              in (widget.focusAssessmentId.isNotEmpty || widget.initialTab == 1
                  ? [true, false]
                  : [false, true])) ...[
            Text(
              assessmentFirst
                  ? 'Assessments'
                  : 'Learning materials • All sections',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (assessmentFirst) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _createAssessment,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create assessment'),
                ),
              ),
              const SizedBox(height: 16),
              if (_visibleAssessments.isEmpty)
                _buildEmptyAssessments()
              else
                ..._visibleAssessments.map(_buildAssessmentCard),
            ] else ...[
              _buildLearningMaterialHeader(),
              const SizedBox(height: 16),
              if (_materials.isEmpty)
                _buildEmptyMaterials()
              else
                ..._materials.map(_buildMaterialCard),
            ],
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_moduleTitle, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(widget.courseTitle),
      const SizedBox(height: 8),
      Text(
        'Module $_moduleOrder • $_moduleStatus',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (_moduleDescription.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(_moduleDescription),
      ],
    ],
  );

  Widget _buildLearningMaterialHeader() => Align(
    alignment: Alignment.centerRight,
    child: FilledButton.icon(
      onPressed: _addLearningMaterial,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add material'),
    ),
  );

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final String materialId = _materialId(material);

    final bool busy = _busyMaterialIds.contains(materialId);

    final String title =
        (material['title'] ?? material['fileName'] ?? 'Learning Material')
            .toString();

    final String description = (material['description'] ?? '')
        .toString()
        .trim();

    final String status = _materialStatus(material);

    final String fileName = (material['fileName'] ?? '').toString().trim();

    final String externalUrl = (material['externalUrl'] ?? '')
        .toString()
        .trim();

    final String deliveryType = _materialDeliveryType(material);

    final Color materialColor = _materialColor(material);

    final Color statusColor = _statusColor(status);

    final String typeLabel = _materialTypeLabel(material);

    final String size = _formatFileSize(material['sizeBytes']);

    final String aiStatusLabel = _materialAiStatusLabel(material);

    final Color aiStatusColor = _materialAiStatusColor(material);

    final IconData aiStatusIcon = _materialAiStatusIcon(material);

    final List<String> details = [typeLabel, if (size.isNotEmpty) size];

    final bool canAnalyzeMaterial =
        material['aiEligible'] == true && deliveryType == 'uploaded_file';

    final bool aiReady = _materialAiStatus(material) == 'ready';

    final String savedAiAnalysis = (material['aiAnalysisSummary'] ?? '')
        .toString()
        .trim();

    final bool hasSavedAiAnalysis = aiReady && savedAiAnalysis.isNotEmpty;

    final bool canGenerateAiQuiz = canAnalyzeMaterial && aiReady;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: borderColor),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ====================================================
          // MATERIAL ICON
          // ====================================================

          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: materialColor.withValues(alpha: 0.10),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              _materialIcon(material),
              color: materialColor,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          // ====================================================
          // MATERIAL INFO
          // ====================================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        status.toUpperCase(),

                        style: TextStyle(
                          color: statusColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  details.join(' \u2022 '),

                  style: TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 7),

                // ==============================================
                // PHASE 7C-6 AI READINESS
                // ==============================================
                Align(
                  alignment: Alignment.centerLeft,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),

                    decoration: BoxDecoration(
                      color: aiStatusColor.withValues(alpha: 0.10),

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(aiStatusIcon, color: aiStatusColor, size: 12),

                        const SizedBox(width: 5),

                        Text(
                          aiStatusLabel,

                          style: TextStyle(
                            color: aiStatusColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 7),

                  Text(
                    description,

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: textGrey,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],

                if (deliveryType == 'uploaded_file' && fileName.isNotEmpty) ...[
                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        color: textGrey,
                        size: 14,
                      ),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          fileName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(color: textGrey, fontSize: 9.5),
                        ),
                      ),
                    ],
                  ),
                ],

                if (deliveryType == 'external_link' &&
                    externalUrl.isNotEmpty) ...[
                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Icon(Icons.link_rounded, color: blue, size: 14),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          externalUrl,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            color: blue,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          // ====================================================
          // MANAGEMENT MENU
          // ====================================================
          if (busy)
            Padding(
              padding: EdgeInsets.all(11),

              child: SizedBox(
                width: 20,
                height: 20,

                child: CircularProgressIndicator(
                  color: primaryTeal,
                  strokeWidth: 2.2,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Material options',

              onSelected: (value) {
                switch (value) {
                  case 'publish':
                    _changeMaterialStatus(material, 'published');
                    break;

                  case 'draft':
                    _changeMaterialStatus(material, 'draft');
                    break;

                  case 'analyze_ai':
                    _analyzeMaterialWithAi(material);
                    break;

                  case 'view_ai_analysis':
                    _showSavedAiAnalysis(material);
                    break;

                  case 'reanalyze_ai':
                    _analyzeMaterialWithAi(material, forceReanalyze: true);
                    break;

                  case 'generate_ai_quiz':
                    _generateAiQuizDraft(material);
                    break;

                  case 'delete':
                    _deleteMaterial(material);
                    break;
                }
              },

              itemBuilder: (context) => [
                if (status != 'published')
                  PopupMenuItem(
                    value: 'publish',

                    child: Row(
                      children: [
                        Icon(Icons.visibility_rounded, color: green, size: 19),

                        SizedBox(width: 10),

                        Text('Publish'),
                      ],
                    ),
                  ),

                if (status != 'draft')
                  PopupMenuItem(
                    value: 'draft',

                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          color: orange,
                          size: 19,
                        ),

                        SizedBox(width: 10),

                        Text('Move to Draft'),
                      ],
                    ),
                  ),

                if (canAnalyzeMaterial && !hasSavedAiAnalysis)
                  PopupMenuItem(
                    value: 'analyze_ai',

                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: primaryTeal,
                          size: 19,
                        ),

                        SizedBox(width: 10),

                        Text('Analyze with AI'),
                      ],
                    ),
                  ),

                if (hasSavedAiAnalysis)
                  PopupMenuItem(
                    value: 'view_ai_analysis',

                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: primaryTeal,
                          size: 19,
                        ),

                        SizedBox(width: 10),

                        Text('View AI Analysis'),
                      ],
                    ),
                  ),

                if (hasSavedAiAnalysis)
                  PopupMenuItem(
                    value: 'reanalyze_ai',

                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: orange, size: 19),

                        SizedBox(width: 10),

                        Expanded(
                          child: Text('Re-analyze with AI (uses quota)'),
                        ),
                      ],
                    ),
                  ),

                if (canGenerateAiQuiz)
                  PopupMenuItem(
                    value: 'generate_ai_quiz',

                    child: Row(
                      children: [
                        Icon(Icons.quiz_rounded, color: purple, size: 19),

                        SizedBox(width: 10),

                        Text('Generate AI Quiz Draft'),
                      ],
                    ),
                  ),

                const PopupMenuDivider(),

                PopupMenuItem(
                  value: 'delete',

                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: red, size: 19),

                      SizedBox(width: 10),

                      Text('Delete Material', style: TextStyle(color: red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY MATERIALS
  // ============================================================

  Widget _buildEmptyMaterials() => const WorkspaceEmptyState(
    icon: Icons.description_outlined,
    title: 'No learning materials yet',
    message: 'Use Add material to upload a file or attach a learning resource.',
  );

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final String title = (assessment['title'] ?? 'Assessment').toString();

    final String type = (assessment['assessmentType'] ?? 'assessment')
        .toString()
        .toLowerCase();

    final String status = (assessment['status'] ?? 'draft')
        .toString()
        .toLowerCase();

    final String deliveryType = (assessment['deliveryType'] ?? 'external_link')
        .toString();

    final String url = (assessment['externalUrl'] ?? '').toString();

    final String submissionMethod = (assessment['submissionMethod'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final bool isGoogleForm =
        submissionMethod == 'google_form' ||
        (submissionMethod.isEmpty &&
            (url.contains('docs.google.com/forms') ||
                url.contains('forms.gle')));

    final bool isArtifact =
        submissionMethod == 'artifact' || deliveryType == 'artifact_submission';

    final num points = (assessment['totalPoints'] as num?) ?? 0;

    final bool isAiGeneratedQuiz =
        deliveryType == 'ai_generated' && type == 'quiz';

    final Color statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: borderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(
                  _assessmentIcon(type),

                  color: primaryTeal,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,

                            style: TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),

                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),

                            borderRadius: BorderRadius.circular(8),
                          ),

                          child: Text(
                            status.toUpperCase(),

                            style: TextStyle(
                              color: statusColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${_capitalize(type)} \u2022 '
                      '$points points',

                      style: TextStyle(
                        color: textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Due ${_formatDate(assessment['dueAt'])}',

                      style: TextStyle(color: textGrey, fontSize: 10.5),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Icon(
                          isAiGeneratedQuiz
                              ? Icons.auto_awesome_rounded
                              : isGoogleForm
                              ? Icons.description_outlined
                              : Icons.upload_file_rounded,

                          color: primaryTeal,
                          size: 14,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            isAiGeneratedQuiz
                                ? 'AI Generated Assessment'
                                : isGoogleForm
                                ? (url.isEmpty ? 'Google Form' : url)
                                : isArtifact
                                ? 'GitHub / File Submission'
                                : 'External Assessment',

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              color: primaryTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                tooltip: 'Assessment options',

                onSelected: (value) {
                  switch (value) {
                    case 'edit_ai_quiz':
                      _editAiQuizAssessment(assessment);
                      break;

                    case 'grading':
                      _openAssessmentGrading(assessment);
                      break;

                    case 'publish':
                      if (isAiGeneratedQuiz) {
                        _publishAiQuiz(assessment);
                      } else {
                        _changeStatus(assessment, 'published');
                      }
                      break;

                    case 'draft':
                      _changeStatus(assessment, 'draft');
                      break;

                    case 'close':
                      _changeStatus(assessment, 'closed');
                      break;

                    case 'delete':
                      _deleteAssessment(assessment);
                      break;
                  }
                },

                itemBuilder: (context) => [
                  if (isAiGeneratedQuiz)
                    PopupMenuItem(
                      value: 'edit_ai_quiz',

                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 19,
                            color: purple,
                          ),

                          SizedBox(width: 10),

                          Text('Review & Edit AI Quiz'),
                        ],
                      ),
                    ),

                  if (isAiGeneratedQuiz) const PopupMenuDivider(),

                  PopupMenuItem(
                    value: 'grading',

                    child: Row(
                      children: [
                        Icon(
                          Icons.grading_rounded,
                          size: 19,
                          color: primaryTeal,
                        ),

                        SizedBox(width: 10),

                        Text('Submissions & Grading'),
                      ],
                    ),
                  ),

                  const PopupMenuDivider(),

                  if (status != 'published' ||
                      (isAiGeneratedQuiz &&
                          (assessment['quizVersion'] ?? '')
                              .toString()
                              .trim()
                              .isEmpty))
                    PopupMenuItem(
                      value: 'publish',
                      child: Text(
                        isAiGeneratedQuiz
                            ? 'Validate & Publish AI Quiz'
                            : 'Publish',
                      ),
                    ),

                  if (status != 'draft')
                    const PopupMenuItem(
                      value: 'draft',
                      child: Text('Move to Draft'),
                    ),

                  if (status != 'closed')
                    const PopupMenuItem(
                      value: 'close',
                      child: Text('Close Assessment'),
                    ),

                  const PopupMenuDivider(),

                  PopupMenuItem(
                    value: 'delete',

                    child: Text('Delete', style: TextStyle(color: red)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          Divider(height: 1, color: borderColor),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            height: 45,

            child: OutlinedButton.icon(
              onPressed: () {
                if (isAiGeneratedQuiz) {
                  _editAiQuizAssessment(assessment);
                } else {
                  _openAssessmentGrading(assessment);
                }
              },

              icon: Icon(
                isAiGeneratedQuiz
                    ? Icons.edit_note_rounded
                    : Icons.grading_rounded,
                size: 18,
              ),

              label: Text(
                isAiGeneratedQuiz
                    ? 'Review & Edit Quiz'
                    : 'Submissions & Grading',

                style: const TextStyle(fontWeight: FontWeight.w700),
              ),

              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.resolve(context, AppColors.link),

                side: BorderSide(color: primaryTeal, width: 1.3),

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
  // EMPTY ASSESSMENTS
  // ============================================================

  Widget _buildEmptyAssessments() => const WorkspaceEmptyState(
    icon: Icons.assignment_outlined,
    title: 'No assessments yet',
    message: 'Create an assessment to define its instructions, grading, and availability.',
  );

  Widget _buildFutureAiCard() {
    final int eligibleCount = _materials
        .where((material) => material['aiEligible'] == true)
        .length;

    final int readyCount = _materials
        .where((material) => _materialAiStatus(material) == 'ready')
        .length;

    final int pendingCount = _materials
        .where((material) => _materialAiStatus(material) == 'pending')
        .length;

    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: primaryTeal.withValues(alpha: 0.06),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: primaryTeal.withValues(alpha: 0.15)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.auto_awesome_rounded, color: primaryTeal, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'AI Source Preparation',

                  style: TextStyle(
                    color: primaryTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$eligibleCount AI-eligible material${eligibleCount == 1 ? '' : 's'} \u2022 '
                  '$pendingCount pending \u2022 $readyCount ready',

                  style: TextStyle(
                    color: textDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'AI analysis and quiz drafting support PDF, TXT, DOCX, PPTX, XLSX, '
                  'JPG/JPEG, PNG, WEBP, MP4, and WEBM. Open a material menu (\u22EE), '
                  'analyze it once, then reuse the saved analysis or generate a quiz. '
                  'Use Re-analyze only when you really need a fresh result because it '
                  'uses another Gemini request.',

                  style: TextStyle(color: textGrey, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryTeal,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(30),

        children: [
          const SizedBox(height: 100),

          Icon(Icons.error_outline_rounded, color: red, size: 48),

          const SizedBox(height: 12),

          Text(
            _errorMessage ?? 'Unable to load module.',

            textAlign: TextAlign.center,

            style: TextStyle(color: textGrey, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 18),

          Center(
            child: ElevatedButton.icon(
              onPressed: _loadPage,

              icon: const Icon(Icons.refresh_rounded, color: Colors.white),

              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),

              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
            ),
          ),
        ],
      ),
    );
  }
}
