import 'package:flutter/material.dart';

import '../../services/assessment_artifact_submission_service.dart';

class StudentAssessmentSubmissionScreen
    extends StatefulWidget {
  const StudentAssessmentSubmissionScreen({
    super.key,
    required this.assessment,
  });

  final Map<String, dynamic>
      assessment;

  @override
  State<StudentAssessmentSubmissionScreen>
      createState() =>
          _StudentAssessmentSubmissionScreenState();
}

class _StudentAssessmentSubmissionScreenState
    extends State<
        StudentAssessmentSubmissionScreen> {
  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color borderColor =
      Color(0xFFE6EAF0);

  static const Color red =
      Color(0xFFFF4B4B);

  final AssessmentArtifactSubmissionService
      _submissionService =
      AssessmentArtifactSubmissionService();

  bool _isSubmitting = false;

  String get _assessmentId {
    return (
      widget.assessment[
              'assessmentId'] ??
          widget.assessment['id'] ??
          ''
    ).toString().trim();
  }

  String get _title {
    return (
      widget.assessment['title'] ??
          'Assessment'
    ).toString();
  }

  String get _instructions {
    return (
      widget.assessment[
              'instructions'] ??
          ''
    ).toString().trim();
  }

  Set<String> get _allowedSubmissionTypes {
    final dynamic value = widget.assessment['allowedSubmissionTypes'];

    // Existing assessments created before Phase 7F keep all three options.
    if (value is! Iterable) {
      return const {
        'github_repository',
        'zip_file',
        'technical_document',
      };
    }

    return value
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void>
      _submitGitHubRepository() async {
    if (_isSubmitting) {
      return;
    }

    final TextEditingController
        controller =
        TextEditingController();

    final String? repositoryUrl =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'GitHub Repository',
          ),
          content: TextField(
            controller: controller,
            keyboardType:
                TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration:
                const InputDecoration(
              labelText:
                  'Repository link',
              hintText:
                  'https://github.com/owner/repository',
              prefixIcon:
                  Icon(
                Icons.link_rounded,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final String value =
                    controller.text
                        .trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryBlue,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Continue',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (repositoryUrl == null ||
        repositoryUrl.isEmpty) {
      return;
    }

    final bool confirmed =
        await _confirmSubmission(
      title:
          'Submit GitHub Repository?',
      message:
          'Make sure the repository is accessible to your instructor.\n\n$repositoryUrl',
    );

    if (!confirmed) {
      return;
    }

    await _performSubmission(
      () {
        return _submissionService
            .submitGitHubRepository(
          assessmentId:
              _assessmentId,
          repositoryUrl:
              repositoryUrl,
        );
      },
    );
  }

  Future<void>
      _selectZipFile() async {
    if (_isSubmitting) {
      return;
    }

    try {
      final AssessmentSubmissionFile?
          file =
          await _submissionService
              .pickZipFile();

      if (file == null ||
          !mounted) {
        return;
      }

      final bool confirmed =
          await _confirmFile(
        file: file,
        typeLabel: 'ZIP file',
      );

      if (!confirmed) {
        return;
      }

      await _performSubmission(
        () {
          return _submissionService
              .submitZipFile(
            assessmentId:
                _assessmentId,
            file: file,
          );
        },
      );
    } on AssessmentArtifactSubmissionException
        catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(
        'Unable to select ZIP file: $error',
      );
    }
  }

  Future<void>
      _selectTechnicalDocument() async {
    if (_isSubmitting) {
      return;
    }

    try {
      final AssessmentSubmissionFile?
          file =
          await _submissionService
              .pickTechnicalDocument();

      if (file == null ||
          !mounted) {
        return;
      }

      final bool confirmed =
          await _confirmFile(
        file: file,
        typeLabel:
            'technical document',
      );

      if (!confirmed) {
        return;
      }

      await _performSubmission(
        () {
          return _submissionService
              .submitTechnicalDocument(
            assessmentId:
                _assessmentId,
            file: file,
          );
        },
      );
    } on AssessmentArtifactSubmissionException
        catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(
        'Unable to select document: $error',
      );
    }
  }

  Future<bool> _confirmFile({
    required AssessmentSubmissionFile
        file,
    required String typeLabel,
  }) {
    return _confirmSubmission(
      title:
          'Submit $typeLabel?',
      message:
          '${file.name}\n'
          '${file.sizeInMegabytes.toStringAsFixed(2)} MB\n\n'
          'You cannot replace it after submission.',
    );
  }

  Future<bool>
      _confirmSubmission({
    required String title,
    required String message,
  }) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            message,
            style: const TextStyle(
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryBlue,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Submit',
              ),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void>
      _performSubmission(
    Future<void> Function() action,
  ) async {
    if (_isSubmitting) {
      return;
    }

    if (_assessmentId.isEmpty) {
      _showError(
        'Assessment ID is missing.',
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } on AssessmentArtifactSubmissionException
        catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to submit assessment: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: red,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  Widget _submissionOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              _isSubmitting
                  ? null
                  : onPressed,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color:
                        primaryBlue
                            .withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          color:
                              textDark,
                          fontSize:
                              14,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        description,
                        style:
                            const TextStyle(
                          color:
                              textGrey,
                          fontSize:
                              11,
                          height:
                              1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop:
          !_isSubmitting,
      child: Scaffold(
        backgroundColor:
            background,
        appBar: AppBar(
          backgroundColor:
              Colors.white,
          foregroundColor:
              textDark,
          elevation: 0,
          title: const Text(
            'Submit Assessment',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isSubmitting)
                const LinearProgressIndicator(
                  color:
                      primaryBlue,
                ),
              Expanded(
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(18),
                        decoration:
                            BoxDecoration(
                          color:
                              primaryBlue,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              _title,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            if (_instructions
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 8,
                              ),
                              Text(
                                _instructions,
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white
                                          .withValues(
                                    alpha:
                                        0.86,
                                  ),
                                  fontSize:
                                      12,
                                  height:
                                      1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 25,
                      ),
                      const Text(
                        'Submission',
                        style: TextStyle(
                          color:
                              textDark,
                          fontSize:
                              18,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        _allowedSubmissionTypes.length == 1
                            ? 'Use the submission option selected by your instructor.'
                            : 'Choose one of the submission options allowed by your instructor.',
                        style: const TextStyle(
                          color:
                              textGrey,
                          fontSize:
                              12,
                        ),
                      ),
                      const SizedBox(
                        height: 17,
                      ),
                      if (_allowedSubmissionTypes.contains(
                        'github_repository',
                      ))
                        _submissionOption(
                          icon: Icons.link_rounded,
                          title: 'GitHub Repository Link',
                          description:
                              'Submit a public or instructor-accessible GitHub repository.',
                          onPressed: _submitGitHubRepository,
                        ),
                      if (_allowedSubmissionTypes.contains('zip_file'))
                        _submissionOption(
                          icon: Icons.folder_zip_outlined,
                          title: 'Upload ZIP File',
                          description:
                              'Upload your project source code as a ZIP file.',
                          onPressed: _selectZipFile,
                        ),
                      if (_allowedSubmissionTypes.contains(
                        'technical_document',
                      ))
                        _submissionOption(
                          icon: Icons.description_outlined,
                          title: 'Upload Technical Docs',
                          description:
                              'Accepted: PDF, DOC, DOCX, or TXT — maximum 20 MB.',
                          onPressed: _selectTechnicalDocument,
                        ),
                      if (_isSubmitting) ...[
                        const SizedBox(
                          height: 12,
                        ),
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color:
                                    primaryBlue,
                              ),
                              SizedBox(
                                height: 12,
                              ),
                              Text(
                                'Uploading and submitting…',
                                style:
                                    TextStyle(
                                  color:
                                      textGrey,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
