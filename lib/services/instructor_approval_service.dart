import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User;
import 'package:url_launcher/url_launcher.dart';

class InstructorApprovalService {
  InstructorApprovalService({
    FirebaseAuth? auth,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _supabase =
            supabase ?? Supabase.instance.client;

  final FirebaseAuth _auth;
  final SupabaseClient _supabase;

  Future<Uri> getFacultyIdUrl(
    String applicantId,
  ) async {
    final String cleanApplicantId =
        applicantId.trim();

    if (cleanApplicantId.isEmpty) {
      throw InstructorApprovalException(
        'Applicant ID is missing.',
      );
    }

    final Map<String, dynamic> result =
        await _invoke({
      'action': 'get_faculty_id',
      'applicantId': cleanApplicantId,
    });

    final String url =
        (result['url'] ?? '')
            .toString()
            .trim();

    final Uri? uri =
        Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme) {
      throw InstructorApprovalException(
        'The faculty ID link is invalid.',
      );
    }

    return uri;
  }

  Future<void> openFacultyId(
    String applicantId,
  ) async {
    final Uri uri =
        await getFacultyIdUrl(
      applicantId,
    );

    final bool opened =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened) {
      throw InstructorApprovalException(
        'Unable to open the faculty ID file.',
      );
    }
  }

  Future<InstructorReviewResult>
      approveInstructor(
    String applicantId,
  ) {
    return _reviewInstructor(
      applicantId: applicantId,
      decision: 'approved',
    );
  }

  Future<InstructorReviewResult>
      denyInstructor({
    required String applicantId,
    required String reason,
  }) {
    final String cleanReason =
        reason.trim();

    if (cleanReason.isEmpty) {
      throw InstructorApprovalException(
        'Enter a reason for denying the application.',
      );
    }

    return _reviewInstructor(
      applicantId: applicantId,
      decision: 'denied',
      reason: cleanReason,
    );
  }

  Future<InstructorReviewResult>
      _reviewInstructor({
    required String applicantId,
    required String decision,
    String reason = '',
  }) async {
    final String cleanApplicantId =
        applicantId.trim();

    if (cleanApplicantId.isEmpty) {
      throw InstructorApprovalException(
        'Applicant ID is missing.',
      );
    }

    final Map<String, dynamic> result =
        await _invoke({
      'action': 'review',
      'applicantId': cleanApplicantId,
      'decision': decision,
      'reason': reason.trim(),
    });

    return InstructorReviewResult(
      decision:
          (result['decision'] ?? decision)
              .toString()
              .trim()
              .toLowerCase(),
      emailSent:
          result['emailSent'] == true,
      message:
          (result['message'] ?? '')
              .toString()
              .trim(),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body,
  ) async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw InstructorApprovalException(
        'Administrator login is required.',
      );
    }

    final String? firebaseToken =
        await currentUser.getIdToken(
      true,
    );

    if (firebaseToken == null ||
        firebaseToken.isEmpty) {
      throw InstructorApprovalException(
        'Unable to verify the administrator session.',
      );
    }

    try {
      final functionResponse =
          await _supabase.functions.invoke(
        'instructor-approval',
        headers: {
          'Authorization':
              'Bearer $firebaseToken',
        },
        body: body,
      );

      final dynamic responseData =
          functionResponse.data;

      if (responseData is! Map) {
        throw InstructorApprovalException(
          'The approval server returned an invalid response.',
        );
      }

      final Map<String, dynamic> data =
          responseData.map(
        (
          dynamic key,
          dynamic value,
        ) {
          return MapEntry(
            key.toString(),
            value,
          );
        },
      );

      if (data['success'] != true) {
        throw InstructorApprovalException(
          _messageFromResponse(data),
        );
      }

      return data;
    } on InstructorApprovalException {
      rethrow;
    } on FunctionException catch (error) {
      throw InstructorApprovalException(
        _messageFromResponse(
          error.details,
        ),
      );
    } on FirebaseAuthException catch (error) {
      throw InstructorApprovalException(
        error.message ??
            'Unable to verify the administrator.',
      );
    } catch (error) {
      throw InstructorApprovalException(
        'Unable to contact the instructor approval service: $error',
      );
    }
  }

  String _messageFromResponse(
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

    final String text =
        value?.toString().trim() ?? '';

    if (text.isNotEmpty &&
        text != 'null') {
      return text;
    }

    return 'Unable to process the instructor application.';
  }
}

class InstructorReviewResult {
  const InstructorReviewResult({
    required this.decision,
    required this.emailSent,
    required this.message,
  });

  final String decision;
  final bool emailSent;
  final String message;

  bool get approved =>
      decision == 'approved';
}

class InstructorApprovalException
    implements Exception {
  const InstructorApprovalException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}