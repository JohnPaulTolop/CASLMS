import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'instructor_ui.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../services/assessment_artifact_submission_service.dart';
import '../../services/assessment_submission_service.dart';
import '../../services/roster_service.dart';

class InstructorAssessmentGradingScreen extends StatefulWidget {
  const InstructorAssessmentGradingScreen({
    super.key,
    required this.assessmentId,
  });

  final String assessmentId;

  @override
  State<InstructorAssessmentGradingScreen> createState() =>
      _InstructorAssessmentGradingScreenState();
}

class _InstructorAssessmentGradingScreenState
    extends State<InstructorAssessmentGradingScreen> {
  static const Color primaryTeal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AssessmentSubmissionService _submissionService =
      AssessmentSubmissionService();

  final AssessmentArtifactSubmissionService _artifactService =
      AssessmentArtifactSubmissionService();

  final RosterService _rosterService = RosterService();

  bool _isLoading = true;
  bool _feedbackDialogOpen = false;

  String? _openingSubmissionId;
  String? _errorMessage;

  final Set<String> _busyComplianceStudentIds = <String>{};

  Map<String, dynamic>? _assessment;
  Map<String, dynamic>? _course;
  Map<String, dynamic>? _module;

  List<Map<String, dynamic>> _submissions = [];

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  String get _assessmentTitle =>
      (_assessment?['title'] ?? 'Assessment').toString();

  String get _assessmentType =>
      (_assessment?['assessmentType'] ?? 'assessment').toString();

  num get _totalPoints => (_assessment?['totalPoints'] as num?) ?? 0;

  bool _isGoogleForm(Map<String, dynamic>? assessment) {
    final String submissionMethod = (assessment?['submissionMethod'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (submissionMethod.isNotEmpty) {
      return submissionMethod == 'google_form';
    }

    final String url = (assessment?['externalUrl'] ?? '')
        .toString()
        .toLowerCase();

    return url.contains('docs.google.com/forms') || url.contains('forms.gle');
  }

  bool get _isGoogleFormAssessment => _isGoogleForm(_assessment);

  String _complianceStatus(Map<String, dynamic> submission) {
    final String stored = (submission['complianceStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (stored == 'complied' || stored == 'not_complied') {
      return stored;
    }

    return 'pending_verification';
  }

  String _status(Map<String, dynamic> submission) {
    return (submission['status'] ?? '').toString().trim().toLowerCase();
  }

  int get _gradedCount {
    return _submissions.where((submission) {
      return _status(submission) == 'graded';
    }).length;
  }

  int get _submittedCount {
    return _submissions.where((submission) {
      return _status(submission) == 'submitted';
    }).length;
  }

  int get _compliedCount => _submissions.where((submission) {
    return _complianceStatus(submission) == 'complied';
  }).length;

  int get _notCompliedCount => _submissions.where((submission) {
    return _complianceStatus(submission) == 'not_complied';
  }).length;

  int get _pendingVerificationCount => _submissions.where((submission) {
    return _complianceStatus(submission) == 'pending_verification';
  }).length;

  List<Map<String, dynamic>> get _filteredSubmissions {
    if (_selectedFilter == 'all') {
      return _submissions;
    }

    return _submissions.where((submission) {
      return _isGoogleFormAssessment
          ? _complianceStatus(submission) == _selectedFilter
          : _status(submission) == _selectedFilter;
    }).toList();
  }

  Future<void> _loadPage() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String assessmentId = widget.assessmentId.trim();

      if (assessmentId.isEmpty) {
        throw AssessmentSubmissionException('Assessment ID is missing.');
      }

      final assessmentDocument = await _firestore
          .collection('assessments')
          .doc(assessmentId)
          .get();

      final Map<String, dynamic>? assessment = assessmentDocument.data();

      if (assessment == null) {
        throw AssessmentSubmissionException('Assessment could not be found.');
      }

      final String courseId = (assessment['courseId'] ?? '').toString().trim();

      final String moduleId = (assessment['moduleId'] ?? '').toString().trim();

      if (courseId.isEmpty || moduleId.isEmpty) {
        throw AssessmentSubmissionException(
          'Course or module information is missing.',
        );
      }

      List<Map<String, dynamic>> submissions = await _submissionService
          .getAssessmentSubmissions(assessmentId: assessmentId);

      if (_isGoogleForm(assessment)) {
        final List<Map<String, dynamic>> students = await _rosterService
            .getCourseStudents(courseId);

        final Map<String, Map<String, dynamic>> submissionsByStudent = {
          for (final submission in submissions)
            (submission['studentId'] ?? '').toString(): submission,
        };

        submissions = students.map((student) {
          final String studentId = (student['studentId'] ?? student['id'] ?? '')
              .toString()
              .trim();
          final Map<String, dynamic>? existing =
              submissionsByStudent[studentId];

          return <String, dynamic>{
            'assessmentId': assessmentId,
            'courseId': courseId,
            'moduleId': moduleId,
            'studentId': studentId,
            'studentName': (student['name'] ?? 'Student').toString(),
            'studentEmail': (student['email'] ?? '').toString(),
            'submissionId': '${assessmentId}_$studentId',
            'id': '${assessmentId}_$studentId',
            'submissionType': 'google_form',
            'status': 'pending_verification',
            'complianceStatus': 'pending_verification',
            if (existing != null) ...existing,
          };
        }).toList();
      }

      final courseDocument = await _firestore
          .collection('courses')
          .doc(courseId)
          .get();

      final moduleDocument = await _firestore
          .collection('modules')
          .doc(moduleId)
          .get();

      submissions.sort((first, second) {
        if (_isGoogleForm(assessment)) {
          const Map<String, int> order = {
            'pending_verification': 0,
            'not_complied': 1,
            'complied': 2,
          };

          final int firstOrder = order[_complianceStatus(first)] ?? 3;
          final int secondOrder = order[_complianceStatus(second)] ?? 3;

          if (firstOrder != secondOrder) {
            return firstOrder.compareTo(secondOrder);
          }
        }

        final bool firstPending = _status(first) == 'submitted';

        final bool secondPending = _status(second) == 'submitted';

        if (firstPending != secondPending) {
          return firstPending ? -1 : 1;
        }

        return (first['studentName'] ?? '').toString().toLowerCase().compareTo(
          (second['studentName'] ?? '').toString().toLowerCase(),
        );
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _assessment = {...assessment, 'id': assessmentId};

        _course = courseDocument.data();

        _module = moduleDocument.data();

        _submissions = submissions;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = error is AssessmentSubmissionException
            ? error.message
            : error.toString();
      });
    }
  }

  num _submissionTotal(Map<String, dynamic> submission) {
    if (submission['totalPoints'] is num) {
      return submission['totalPoints'] as num;
    }

    return _totalPoints;
  }

  String _rating(Map<String, dynamic> submission) {
    final dynamic stored = submission['percentage'];

    if (stored is num && stored.isFinite) {
      return '${stored.toStringAsFixed(1)}%';
    }

    final dynamic score = submission['score'];

    final num total = _submissionTotal(submission);

    if (score is! num || total <= 0) {
      return 'Not available';
    }

    return '${(score / total * 100).toStringAsFixed(1)}%';
  }

  String _formatDate(dynamic value) {
    final DateTime? date = value is Timestamp
        ? value.toDate().toLocal()
        : value is DateTime
        ? value.toLocal()
        : null;

    if (date == null) {
      return 'Unknown';
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

    final int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final String minute = date.minute.toString().padLeft(2, '0');

    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year} '
        '• $hour:$minute $period';
  }

  String _submissionId(Map<String, dynamic> submission) {
    return (submission['submissionId'] ?? submission['id'] ?? '')
        .toString()
        .trim();
  }

  String _submissionType(Map<String, dynamic> submission) {
    return (submission['submissionType'] ?? '').toString().trim().toLowerCase();
  }

  String _submissionTypeLabel(Map<String, dynamic> submission) {
    switch (_submissionType(submission)) {
      case 'github_repository':
        return 'GitHub Repository';

      case 'zip_file':
        return 'ZIP Project File';

      case 'technical_document':
        return 'Technical Document';

      case 'google_form':
        return 'Google Form Response';

      default:
        return 'External Assessment';
    }
  }

  IconData _submissionTypeIcon(Map<String, dynamic> submission) {
    switch (_submissionType(submission)) {
      case 'github_repository':
        return Icons.link_rounded;

      case 'zip_file':
        return Icons.folder_zip_outlined;

      case 'technical_document':
        return Icons.description_outlined;

      case 'google_form':
        return Icons.fact_check_outlined;

      default:
        return Icons.assignment_turned_in_outlined;
    }
  }

  bool _canOpenSubmission(Map<String, dynamic> submission) {
    return const {
      'github_repository',
      'zip_file',
      'technical_document',
    }.contains(_submissionType(submission));
  }

  Future<void> _openSubmittedWork(Map<String, dynamic> submission) async {
    final String submissionId = _submissionId(submission);

    if (submissionId.isEmpty || _openingSubmissionId != null) {
      return;
    }

    setState(() {
      _openingSubmissionId = submissionId;
    });

    try {
      final String type = _submissionType(submission);

      late final Uri uri;

      if (type == 'github_repository') {
        final Uri? parsedUri = Uri.tryParse(
          (submission['repositoryUrl'] ?? '').toString().trim(),
        );

        if (parsedUri == null ||
            parsedUri.scheme != 'https' ||
            parsedUri.host.toLowerCase() != 'github.com') {
          throw AssessmentArtifactSubmissionException(
            'The submitted GitHub repository link is invalid.',
          );
        }

        uri = parsedUri;
      } else if (type == 'zip_file' || type == 'technical_document') {
        uri = await _artifactService.createFileDownloadUrl(
          submissionId: submissionId,
        );
      } else {
        throw AssessmentArtifactSubmissionException(
          'This older submission does not include a link or uploaded file.',
        );
      }

      bool opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (!opened) {
        throw AssessmentArtifactSubmissionException(
          'Unable to open the submitted work.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is AssessmentArtifactSubmissionException
          ? error.message
          : 'Unable to open the submitted work: $error';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingSubmissionId = null;
        });
      }
    }
  }

  Future<void> _setGoogleFormCompliance(
    Map<String, dynamic> student,
    bool complied,
  ) async {
    final String studentId = (student['studentId'] ?? '').toString().trim();
    final String studentName = (student['studentName'] ?? 'Student')
        .toString()
        .trim();

    if (studentId.isEmpty || _busyComplianceStudentIds.contains(studentId)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(complied ? 'Mark as Complied?' : 'Mark as Not Complied?'),
          content: Text(
            complied
                ? 'Confirm that you found a valid Google Form response for $studentName.'
                : 'Confirm that you could not verify a valid Google Form response for $studentName.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: complied ? green : red,
                foregroundColor: Colors.white,
              ),
              child: Text(complied ? 'Complied' : 'Not Complied'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busyComplianceStudentIds.add(studentId);
    });

    try {
      await _submissionService.setGoogleFormCompliance(
        assessmentId: widget.assessmentId,
        studentId: studentId,
        complied: complied,
      );

      if (!mounted) {
        return;
      }

      await _loadPage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$studentName was marked ${complied ? 'Complied' : 'Not Complied'}.',
          ),
          backgroundColor: complied ? green : red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AssessmentSubmissionException
                ? error.message
                : 'Unable to save the compliance decision: $error',
          ),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyComplianceStudentIds.remove(studentId);
        });
      }
    }
  }

  Future<void> _openFeedbackDialog(Map<String, dynamic> submission) async {
    if (!mounted || _feedbackDialogOpen) {
      return;
    }

    final String submissionId = _submissionId(submission);

    if (submissionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission ID is missing.')),
      );

      return;
    }

    _feedbackDialogOpen = true;

    try {
      final NavigatorState navigator = Navigator.of(
        context,
        rootNavigator: true,
      );

      final bool automaticWithoutFeedback =
          submission['gradingMode'] == 'automatic' &&
          submission['feedbackBy'] == null;

      final DialogRoute<bool> route = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return _AssessmentFeedbackDialog(
            service: _submissionService,
            submissionId: submissionId,
            studentName: (submission['studentName'] ?? 'Student').toString(),
            assessmentTitle: _assessmentTitle,
            score: submission['score'] is num
                ? submission['score'] as num
                : null,
            totalPoints: _submissionTotal(submission),
            rating: _rating(submission),
            feedback: automaticWithoutFeedback
                ? ''
                : (submission['feedback'] ?? '').toString(),
          );
        },
      );

      final bool? saved = await navigator.push<bool>(route);

      await route.completed;

      if (!mounted || saved != true) {
        return;
      }

      await _loadPage();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback saved successfully.'),
          backgroundColor: green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _feedbackDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return instructorScaffold(
      context: context,
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Assessment Grading',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadPage,
            icon: const Icon(Icons.refresh_rounded),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: red, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPage,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> visible = _filteredSubmissions;

    return RefreshIndicator(
      onRefresh: _loadPage,
      color: primaryTeal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _stat(
                  _isGoogleFormAssessment ? 'Complied' : 'Total',
                  _isGoogleFormAssessment
                      ? '$_compliedCount'
                      : '${_submissions.length}',
                  _isGoogleFormAssessment
                      ? Icons.check_circle_outline
                      : Icons.people_alt_outlined,
                  _isGoogleFormAssessment ? green : primaryTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  _isGoogleFormAssessment ? 'Pending' : 'Submitted',
                  _isGoogleFormAssessment
                      ? '$_pendingVerificationCount'
                      : '$_submittedCount',
                  _isGoogleFormAssessment
                      ? Icons.hourglass_empty_rounded
                      : Icons.pending_actions,
                  orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  _isGoogleFormAssessment ? 'Not Complied' : 'Graded',
                  _isGoogleFormAssessment
                      ? '$_notCompliedCount'
                      : '$_gradedCount',
                  _isGoogleFormAssessment
                      ? Icons.cancel_outlined
                      : Icons.verified_outlined,
                  _isGoogleFormAssessment ? red : green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _isGoogleFormAssessment
                ? 'Student Compliance'
                : 'Student Submissions',
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isGoogleFormAssessment
                ? 'Check the Google Form responses, then verify each enrolled student.'
                : 'Open submitted work, view scores and ratings, and provide feedback.',
            style: const TextStyle(color: textGrey, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filter('all', 'All (${_submissions.length})'),
              if (_isGoogleFormAssessment) ...[
                _filter('complied', 'Complied ($_compliedCount)'),
                _filter(
                  'pending_verification',
                  'Pending ($_pendingVerificationCount)',
                ),
                _filter('not_complied', 'Not Complied ($_notCompliedCount)'),
              ] else ...[
                _filter('submitted', 'Submitted ($_submittedCount)'),
                _filter('graded', 'Graded ($_gradedCount)'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    color: primaryTeal,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text('No submissions in this filter.'),
                ],
              ),
            )
          else
            ...visible.map((submission) {
              return _isGoogleFormAssessment
                  ? _googleFormComplianceCard(submission)
                  : _submissionCard(submission);
            }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String courseCode = (_course?['code'] ?? '').toString();

    final String moduleTitle = (_module?['title'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (courseCode.isNotEmpty) courseCode,
              if (moduleTitle.isNotEmpty) moduleTitle,
            ].join(' • '),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            _assessmentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            (_course?['title'] ?? '').toString(),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(_assessmentType),
              _headerChip('$_totalPoints points'),
              _headerChip('Due ${_formatDate(_assessment?['dueAt'])}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: const TextStyle(color: textGrey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _filter(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      selectedColor: primaryTeal.withValues(alpha: 0.12),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _googleFormComplianceCard(Map<String, dynamic> student) {
    final String studentId = (student['studentId'] ?? '').toString().trim();
    final String studentName = (student['studentName'] ?? 'Student')
        .toString()
        .trim();
    final String studentEmail = (student['studentEmail'] ?? '')
        .toString()
        .trim();
    final String decision = _complianceStatus(student);
    final bool complied = decision == 'complied';
    final bool notComplied = decision == 'not_complied';
    final bool busy = _busyComplianceStudentIds.contains(studentId);

    final String statusLabel = complied
        ? 'COMPLIED'
        : notComplied
        ? 'NOT COMPLIED'
        : 'PENDING';

    final Color statusColor = complied
        ? green
        : notComplied
        ? red
        : orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.10),
                child: Text(
                  studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
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
                      studentName.isEmpty ? 'Student' : studentName,
                      style: const TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (studentEmail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        studentEmail,
                        style: const TextStyle(color: textGrey, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            decision == 'pending_verification'
                ? 'Check Google Forms for a response using this student’s registered email.'
                : 'Decision recorded ${_formatDate(student['verifiedAt'])}. You can correct it if needed.',
            style: const TextStyle(color: textGrey, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy || complied
                      ? null
                      : () => _setGoogleFormCompliance(student, true),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Complied'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: complied
                        ? green.withValues(alpha: 0.55)
                        : Colors.grey.shade300,
                    minimumSize: const Size(0, 45),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy || notComplied
                      ? null
                      : () => _setGoogleFormCompliance(student, false),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Not Complied'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: red,
                    side: BorderSide(
                      color: notComplied ? red.withValues(alpha: 0.45) : red,
                    ),
                    minimumSize: const Size(0, 45),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submissionCard(Map<String, dynamic> submission) {
    final String studentName = (submission['studentName'] ?? 'Student')
        .toString();

    final bool graded = _status(submission) == 'graded';

    final dynamic score = submission['score'];

    final num total = _submissionTotal(submission);

    final String feedback = (submission['feedback'] ?? '').toString().trim();

    final String submissionId = _submissionId(submission);

    final String submissionType = _submissionType(submission);

    final String fileName = (submission['fileName'] ?? '').toString().trim();

    final String repositoryUrl = (submission['repositoryUrl'] ?? '')
        .toString()
        .trim();

    final String studentEmail = (submission['studentEmail'] ?? '')
        .toString()
        .trim();

    final String googleFormResponseId =
        (submission['googleFormResponseId'] ?? '').toString().trim();

    final bool opening = _openingSubmissionId == submissionId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryTeal.withValues(alpha: 0.10),
                child: Text(
                  studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                  style: const TextStyle(color: primaryTeal),
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
                    const SizedBox(height: 4),
                    Text(
                      graded
                          ? 'Graded ${_formatDate(submission['gradedAt'])}'
                          : 'Submitted ${_formatDate(submission['submittedAt'])}',
                      style: const TextStyle(color: textGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                graded ? 'GRADED' : 'SUBMITTED',
                style: TextStyle(
                  color: graded ? green : orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: primaryTeal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryTeal.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Icon(
                  _submissionTypeIcon(submission),
                  color: primaryTeal,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _submissionTypeLabel(submission),
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (fileName.isNotEmpty || repositoryUrl.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          submissionType == 'github_repository'
                              ? repositoryUrl
                              : fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: textGrey, fontSize: 11),
                        ),
                      ] else if (submissionType == 'google_form') ...[
                        const SizedBox(height: 3),
                        Text(
                          studentEmail.isNotEmpty
                              ? 'Verified response from $studentEmail'
                              : googleFormResponseId.isNotEmpty
                              ? 'Verified response ID: $googleFormResponseId'
                              : 'Verified by the Google Forms webhook',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: textGrey, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_canOpenSubmission(submission)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openingSubmissionId == null
                    ? () {
                        _openSubmittedWork(submission);
                      }
                    : null,
                icon: opening
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryTeal,
                        ),
                      )
                    : Icon(
                        submissionType == 'github_repository'
                            ? Icons.open_in_new_rounded
                            : Icons.download_rounded,
                      ),
                label: Text(
                  opening
                      ? 'Opening...'
                      : submissionType == 'github_repository'
                      ? 'Open GitHub Repository'
                      : 'Open Submitted File',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryTeal,
                  side: const BorderSide(color: primaryTeal),
                  minimumSize: const Size(0, 45),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            score is num ? 'Score: $score / $total' : 'Score: Not graded',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text('Rating: ${_rating(submission)}'),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              feedback,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textGrey),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _openFeedbackDialog(submission);
              },
              icon: const Icon(Icons.comment_outlined),
              label: const Text('View Score & Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentFeedbackDialog extends StatefulWidget {
  const _AssessmentFeedbackDialog({
    required this.service,
    required this.submissionId,
    required this.studentName,
    required this.assessmentTitle,
    required this.score,
    required this.totalPoints,
    required this.rating,
    required this.feedback,
  });

  final AssessmentSubmissionService service;

  final String submissionId;
  final String studentName;
  final String assessmentTitle;

  final num? score;
  final num totalPoints;

  final String rating;
  final String feedback;

  @override
  State<_AssessmentFeedbackDialog> createState() =>
      _AssessmentFeedbackDialogState();
}

class _AssessmentFeedbackDialogState extends State<_AssessmentFeedbackDialog> {
  late final TextEditingController _controller;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.feedback);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String feedback = _controller.text.trim();

    if (feedback.isEmpty) {
      setState(() {
        _error = 'Please enter feedback.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.saveFeedback(
        submissionId: widget.submissionId,
        feedback: feedback,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;

        _error = error is AssessmentSubmissionException
            ? error.message
            : 'Unable to save feedback: $error';
      });

      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Score, Rating & Feedback'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.assessmentTitle),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.score == null
                            ? 'Score: Not graded'
                            : 'Score: ${widget.score} / ${widget.totalPoints}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Rating: ${widget.rating}'),
                      const SizedBox(height: 10),
                      const Text(
                        'Scores and ratings are read-only.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !_saving,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Instructor feedback',
                    hintText: 'Write feedback for this student...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text(
                  'New or changed feedback notifies only this student.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    FocusScope.of(context).unfocus();

                    Navigator.of(context).pop(false);
                  },
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.comment_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Feedback'),
          ),
        ],
      ),
    );
  }
}
