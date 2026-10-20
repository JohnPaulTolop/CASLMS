import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class LiveClassService {
  Future<Map<String, dynamic>> request({
    required String action,
    required String courseId,
    String? sectionId,
    String? sessionId,
    String? title,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const LiveClassException('Please sign in again.');
    var stage = 'Firebase sign-in token';
    try {
      final token = await user.getIdToken();
      stage = 'Firebase App Check token';
      final appCheck = await FirebaseAppCheck.instance.getToken();
      if (token == null || appCheck == null || appCheck.isEmpty) {
        throw const LiveClassException(
          'Unable to verify this app. Refresh and try again.',
        );
      }
      stage = 'live-class backend request';
      final response = await Supabase.instance.client.functions.invoke(
        'live-class',
        headers: {
          'Authorization': 'Bearer $token',
          'X-Firebase-AppCheck': appCheck,
        },
        body: {
          'action': action,
          'courseId': courseId,
          'sectionId': ?sectionId,
          'sessionId': ?sessionId,
          'title': ?title,
        },
      );
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw const LiveClassException(
          'Unable to load the classroom. Please retry.',
        );
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (error) {
      debugPrint('[LiveClass] $stage: HTTP ${error.status}');
      final details = error.details;
      throw LiveClassException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Live classes are unavailable. Check that the live-class function is deployed.',
        status: error.status,
      );
    } on LiveClassException {
      rethrow;
    } on FirebaseException catch (error) {
      // Never print credentials, raw exception messages, emails or tokens.
      debugPrint('[LiveClass] $stage: Firebase ${error.plugin}/${error.code}');
      throw LiveClassException(
        stage == 'Firebase App Check token'
            ? 'App verification failed. Refresh the page and try again. If it continues, contact your instructor.'
            : 'Your sign-in session could not be verified. Log out and sign in again.',
        status: stage == 'Firebase sign-in token' ? 401 : null,
      );
    } catch (error) {
      debugPrint('[LiveClass] $stage: ${error.runtimeType}');
      throw const LiveClassException(
        'Unable to reach the classroom service. Refresh and try again.',
      );
    }
  }
}

class LiveClassException implements Exception {
  const LiveClassException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}
