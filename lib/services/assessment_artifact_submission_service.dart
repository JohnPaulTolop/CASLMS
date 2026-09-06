import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User;

class AssessmentSubmissionFile {
  const AssessmentSubmissionFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;

  double get sizeInMegabytes =>
      bytes.length / (1024 * 1024);
}

class AssessmentArtifactSubmissionService {
  AssessmentArtifactSubmissionService({
    FirebaseAuth? auth,
    SupabaseClient? supabase,
  })  : _auth =
            auth ?? FirebaseAuth.instance,
        _supabase =
            supabase ??
            Supabase.instance.client;

  final FirebaseAuth _auth;
  final SupabaseClient _supabase;

  static const int maximumFileBytes =
      20 * 1024 * 1024;

  Future<AssessmentSubmissionFile?>
      pickZipFile() {
    return _pickFile(
      allowedExtensions: const [
        'zip',
      ],
      invalidTypeMessage:
          'Choose a ZIP file.',
    );
  }

  Future<AssessmentSubmissionFile?>
      pickTechnicalDocument() {
    return _pickFile(
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'txt',
      ],
      invalidTypeMessage:
          'Choose a PDF, DOC, DOCX, or TXT file.',
    );
  }

  Future<AssessmentSubmissionFile?>
      _pickFile({
    required List<String>
        allowedExtensions,
    required String
        invalidTypeMessage,
  }) async {
    final PlatformFile? file =
        await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions:
          allowedExtensions,
    );

    if (file == null) {
      return null;
    }

    final String extension =
        (file.extension ?? '')
            .trim()
            .toLowerCase();

    if (!allowedExtensions
        .contains(extension)) {
      throw AssessmentArtifactSubmissionException(
        invalidTypeMessage,
      );
    }

    final Uint8List bytes;

    try {
      bytes =
          await file.readAsBytes();
    } catch (_) {
      throw AssessmentArtifactSubmissionException(
        'Unable to read the selected file.',
      );
    }

    if (bytes.isEmpty) {
      throw AssessmentArtifactSubmissionException(
        'The selected file is empty.',
      );
    }

    if (bytes.length >
        maximumFileBytes) {
      throw AssessmentArtifactSubmissionException(
        'The selected file must not exceed 20 MB.',
      );
    }

    return AssessmentSubmissionFile(
      name: file.name,
      mimeType:
          _mimeType(extension),
      bytes: bytes,
    );
  }

  Future<void>
      submitGitHubRepository({
    required String assessmentId,
    required String repositoryUrl,
  }) async {
    final String cleanUrl =
        repositoryUrl.trim();

    final Uri? uri =
        Uri.tryParse(cleanUrl);

    final List<String> parts =
        uri?.pathSegments
                .where(
                  (part) =>
                      part.isNotEmpty,
                )
                .toList() ??
            [];

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() !=
            'github.com' ||
        parts.length < 2) {
      throw AssessmentArtifactSubmissionException(
        'Use a valid https://github.com/owner/repository link.',
      );
    }

    await _invoke({
      'action': 'submit',
      'assessmentId':
          assessmentId.trim(),
      'submissionType':
          'github_repository',
      'repositoryUrl':
          cleanUrl,
    });
  }

  Future<void> submitZipFile({
    required String assessmentId,
    required AssessmentSubmissionFile
        file,
  }) {
    return _submitFile(
      assessmentId: assessmentId,
      submissionType:
          'zip_file',
      file: file,
    );
  }

  Future<void>
      submitTechnicalDocument({
    required String assessmentId,
    required AssessmentSubmissionFile
        file,
  }) {
    return _submitFile(
      assessmentId: assessmentId,
      submissionType:
          'technical_document',
      file: file,
    );
  }

  Future<void> _submitFile({
    required String assessmentId,
    required String submissionType,
    required AssessmentSubmissionFile
        file,
  }) async {
    if (file.bytes.isEmpty) {
      throw AssessmentArtifactSubmissionException(
        'The selected file is empty.',
      );
    }

    if (file.bytes.length >
        maximumFileBytes) {
      throw AssessmentArtifactSubmissionException(
        'The selected file must not exceed 20 MB.',
      );
    }

    await _invoke({
      'action': 'submit',
      'assessmentId':
          assessmentId.trim(),
      'submissionType':
          submissionType,
      'fileName':
          file.name,
      'mimeType':
          file.mimeType,
      'fileBase64':
          base64Encode(
        file.bytes,
      ),
    });
  }

  Future<Uri>
      createFileDownloadUrl({
    required String submissionId,
  }) async {
    final Map<String, dynamic> data =
        await _invoke({
      'action': 'open_file',
      'submissionId':
          submissionId.trim(),
    });

    final Uri? uri =
        Uri.tryParse(
      (data['url'] ?? '')
          .toString()
          .trim(),
    );

    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority) {
      throw AssessmentArtifactSubmissionException(
        'The secure file link is invalid.',
      );
    }

    return uri;
  }

  Future<Map<String, dynamic>>
      _invoke(
    Map<String, dynamic> body,
  ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw AssessmentArtifactSubmissionException(
        'You must be logged in.',
      );
    }

    final String? token =
        await user.getIdToken(true);

    if (token == null ||
        token.isEmpty) {
      throw AssessmentArtifactSubmissionException(
        'Unable to verify your account.',
      );
    }

    try {
      final response =
          await _supabase.functions
              .invoke(
        'assessment-submission',
        headers: {
          'Authorization':
              'Bearer $token',
        },
        body: body,
      );

      final dynamic value =
          response.data;

      if (value is! Map) {
        throw AssessmentArtifactSubmissionException(
          'The submission server returned an invalid response.',
        );
      }

      final Map<String, dynamic>
          data =
          Map<String, dynamic>.from(
        value,
      );

      if (data['success'] != true) {
        throw AssessmentArtifactSubmissionException(
          _message(data),
        );
      }

      return data;
    } on FunctionException catch (error) {
      throw AssessmentArtifactSubmissionException(
        _message(
          error.details,
        ),
      );
    } on AssessmentArtifactSubmissionException {
      rethrow;
    } catch (error) {
      throw AssessmentArtifactSubmissionException(
        'Unable to submit the assessment: $error',
      );
    }
  }

  String _mimeType(
    String extension,
  ) {
    switch (extension) {
      case 'zip':
        return 'application/zip';

      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'txt':
        return 'text/plain';

      default:
        return 'application/octet-stream';
    }
  }

  String _message(
    dynamic value,
  ) {
    if (value is Map) {
      final String message =
          (value['error'] ??
                  value['message'] ??
                  '')
              .toString()
              .trim();

      if (message.isNotEmpty) {
        return message;
      }
    }

    final String message =
        value?.toString().trim() ??
            '';

    if (message.isNotEmpty &&
        message != 'null') {
      return message;
    }

    return 'Unable to submit the assessment.';
  }
}

class AssessmentArtifactSubmissionException
    implements Exception {
  AssessmentArtifactSubmissionException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}