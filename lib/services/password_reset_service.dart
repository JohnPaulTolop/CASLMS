import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetService {
  PasswordResetService({
    SupabaseClient? supabaseClient,
    FirebaseAppCheck? appCheck,
  }) : _supabase = supabaseClient ?? Supabase.instance.client,
       _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final SupabaseClient _supabase;
  final FirebaseAppCheck _appCheck;

  static const String genericSuccessMessage =
      'If the ID number and registered email match an account, '
      'a password reset link will be sent shortly.';

  Future<String> requestPasswordReset({
    required String campusId,
    required String email,
  }) async {
    final String cleanCampusId = campusId.trim().replaceAll(RegExp(r'\s+'), '');

    final String cleanEmail = email.trim().toLowerCase();

    if (!RegExp(r'^\d{5,12}$').hasMatch(cleanCampusId)) {
      throw PasswordResetException(
        'Enter a valid student or faculty ID number.',
      );
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw PasswordResetException('Enter a valid registered email address.');
    }

    var stage = 'App Check token request';

    try {
      final String? appCheckToken = await _appCheck.getToken(true);

      if (appCheckToken == null || appCheckToken.trim().isEmpty) {
        throw PasswordResetException(
          'CASLMS could not verify this application. '
          'Please restart it and try again.',
        );
      }

      stage = 'Supabase password-reset invocation';
      final FunctionResponse functionResponse = await _supabase.functions
          .invoke(
            'password-reset',
            headers: {'X-Firebase-AppCheck': appCheckToken},
            body: {'campusId': cleanCampusId, 'email': cleanEmail},
          );

      stage = 'password-reset response validation';
      if (kDebugMode) {
        debugPrint(
          '[PasswordReset] Supabase response HTTP '
          '${functionResponse.status}.',
        );
      }

      final Map<String, dynamic> data = _toStringMap(functionResponse.data);

      if (data['success'] != true) {
        throw PasswordResetException(_messageFromData(data));
      }

      final String message = (data['message'] ?? '').toString().trim();

      return message.isEmpty ? genericSuccessMessage : message;
    } on PasswordResetException {
      if (kDebugMode) {
        debugPrint('[PasswordReset] Failed during $stage.');
      }
      rethrow;
    } on FunctionException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[PasswordReset] Failed during $stage: '
          'Supabase HTTP ${error.status}.',
        );
      }
      throw PasswordResetException(_messageFromData(error.details));
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[PasswordReset] Failed during $stage: '
          'Firebase ${error.plugin}/${error.code}.',
        );
      }
      throw PasswordResetException(
        'CASLMS could not verify this application. '
        'Please restart it and try again.',
      );
    } catch (error) {
      if (kDebugMode) {
        // Do not log exception messages: they can contain request data.
        debugPrint(
          '[PasswordReset] Failed during $stage '
          '(${error.runtimeType}).',
        );
      }
      throw PasswordResetException(
        'Unable to request a password reset right now. '
        'Please check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _toStringMap(dynamic value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }

    return value.map((dynamic key, dynamic item) {
      return MapEntry(key.toString(), item);
    });
  }

  String _messageFromData(dynamic value) {
    final Map<String, dynamic> data = _toStringMap(value);

    final String message = (data['error'] ?? data['message'] ?? '')
        .toString()
        .trim();

    if (message.isNotEmpty) {
      return message;
    }

    return 'Unable to request a password reset right now. '
        'Please try again.';
  }
}

class PasswordResetException implements Exception {
  const PasswordResetException(this.message);

  final String message;

  @override
  String toString() => message;
}
