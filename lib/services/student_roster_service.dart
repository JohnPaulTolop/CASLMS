import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentRosterService {
  Future<List<Map<String, dynamic>>> load(String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final token = await user.getIdToken();
    final appCheck = await FirebaseAppCheck.instance.getToken();
    if (token == null || appCheck == null || appCheck.isEmpty) {
      throw StateError('App verification failed. Refresh and retry.');
    }
    final response = await Supabase.instance.client.functions.invoke(
      'assessment-submission',
      headers: {
        'Authorization': 'Bearer $token',
        'X-Firebase-AppCheck': appCheck,
      },
      body: {'action': 'student_roster', 'courseId': courseId},
    );
    final data = response.data;
    if (data is! Map || data['success'] != true || data['students'] is! List) {
      throw StateError('Unable to load classmates.');
    }
    return (data['students'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
