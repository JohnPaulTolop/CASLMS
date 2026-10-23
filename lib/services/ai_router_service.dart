import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';

class AiRouterException implements Exception {
  const AiRouterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiRouterService {
  static const enabled = bool.fromEnvironment(
    'CASLMS_AI_GATEWAY_ENABLED',
    defaultValue: false,
  );
  Future<String> complete({
    required String task,
    required List<Map<String, String>> messages,
    int? questionCount,
    void Function(String text)? onDelta,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const AiRouterException('Please sign in again.');
    final client = http.Client();
    final timer = Timer(const Duration(seconds: 115), client.close);
    var text = '', done = false, truncated = false;
    try {
      final token = await user.getIdToken().timeout(
        const Duration(seconds: 10),
      );
      final appCheck = await FirebaseAppCheck.instance.getToken().timeout(
        const Duration(seconds: 10),
      );
      if (token == null || appCheck == null || appCheck.isEmpty) {
        throw const AiRouterException(
          'App verification failed. Refresh and retry.',
        );
      }
      final request =
          http.Request(
              'POST',
              Uri.parse('${SupabaseConfig.projectUrl}/functions/v1/ai-router'),
            )
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'apikey': SupabaseConfig.publishableKey,
              'X-Firebase-AppCheck': appCheck,
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode({
              'task': task,
              'messages': messages,
              'questionCount': ?questionCount,
            });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String? message;
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['error'] is String) {
            message = parsed['error'] as String;
          }
        } catch (_) {}
        throw AiRouterException(message ?? 'AI is unavailable. Please retry.');
      }
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 30))) {
        if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
          throw const AiRouterException(
            'Your session changed. Reopen the assistant.',
          );
        }
        if (!line.startsWith('data:')) continue;
        final event =
            jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
        if (event['type'] == 'error') {
          throw AiRouterException(
            event['message'] as String? ??
                'The answer was interrupted. Please retry.',
          );
        }
        if (event['type'] == 'delta') {
          final delta = event['text'] as String;
          text += delta;
          if (text.length > 100000) {
            throw const AiRouterException('The AI response was too large.');
          }
          onDelta?.call(text);
        }
        if (event['type'] == 'done') {
          done = true;
          truncated = event['truncated'] == true;
        }
      }
      if (!done || text.trim().isEmpty) {
        throw const AiRouterException(
          'The answer was interrupted. Please retry.',
        );
      }
      if (truncated) {
        throw const AiRouterException(
          'The response reached its length limit. Ask for a shorter answer or fewer items.',
        );
      }
      return text.trim();
    } on AiRouterException {
      rethrow;
    } catch (_) {
      throw const AiRouterException('AI connection interrupted. Please retry.');
    } finally {
      timer.cancel();
      client.close();
    }
  }
}
