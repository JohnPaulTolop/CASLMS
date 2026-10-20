import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

abstract interface class GradebookApi {
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]);
}

class SemesterGradesService implements GradebookApi {
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const GradebookException('Please sign in again.');
    try {
      final token = await user.getIdToken();
      final appCheck = await FirebaseAppCheck.instance.getToken();
      if (token == null || appCheck == null || appCheck.isEmpty) {
        throw const GradebookException(
          'App verification failed. Refresh and retry.',
        );
      }
      final result = await Supabase.instance.client.functions.invoke(
        'semester-grades',
        headers: {
          'Authorization': 'Bearer $token',
          'X-Firebase-AppCheck': appCheck,
        },
        body: {'action': action, ...data},
      );
      if (result.data is! Map || result.data['success'] != true) {
        throw const GradebookException('Unable to load grades. Please retry.');
      }
      return Map<String, dynamic>.from(result.data);
    } on FunctionException catch (error) {
      final details = error.details;
      throw GradebookException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'The grades service is unavailable. Please retry.',
        status: error.status,
      );
    } on GradebookException {
      rethrow;
    } on FirebaseException {
      throw const GradebookException(
        'Account or app verification failed. Refresh and sign in again.',
      );
    } catch (_) {
      throw const GradebookException(
        'Unable to reach the grades service. Please retry.',
      );
    }
  }
}

class GradebookException implements Exception {
  const GradebookException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}
