import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed app activity history.
///
/// Firebase ID tokens and App Check are verified by the activity-logs Edge
/// Function. The Supabase table is not directly exposed to app clients.
class ActivityLogService {
  factory ActivityLogService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
    FirebaseAppCheck? appCheck,
  }) => ActivityLogService._(
    auth ?? FirebaseAuth.instance,
    supabase,
    appCheck ?? FirebaseAppCheck.instance,
  );

  const ActivityLogService._(this._auth, this._supabase, this._appCheck);

  final FirebaseAuth _auth;
  final SupabaseClient? _supabase;
  final FirebaseAppCheck _appCheck;
  static final Set<String> _recordedSessions = {};

  SupabaseClient get _client {
    final injected = _supabase;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const ActivityLogException(
        'Activity history is still starting. Refresh and retry.',
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String action, [
    Map<String, dynamic> body = const <String, dynamic>{},
  ]) async {
    final user = _auth.currentUser;
    if (user == null) throw const ActivityLogException('Please sign in again.');
    final token = await user.getIdToken();
    final appCheckToken = await _appCheck.getToken();
    if (token == null || appCheckToken == null || appCheckToken.isEmpty) {
      throw const ActivityLogException(
        'App verification failed. Refresh and retry.',
      );
    }
    final response = await _client.functions.invoke(
      'activity-logs',
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'X-Firebase-AppCheck': appCheckToken,
      },
      body: <String, dynamic>{'action': action, ...body},
    );
    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final message = data is Map ? (data['error'] ?? '').toString() : '';
      throw ActivityLogException(
        message.isEmpty ? 'Activity history is unavailable.' : message,
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> session(String type, {Map<String, dynamic>? profile}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || !['login', 'logout'].contains(type)) return;
      final token = await user.getIdTokenResult();
      final authTime = token.claims?['auth_time'];
      if (authTime is! num) return;
      final id = '${type}_${authTime.toInt()}_${user.uid}';
      if (_recordedSessions.contains(id)) return;
      await _invoke('session', <String, dynamic>{'type': type});
      _recordedSessions.add(id);
    } catch (_) {
      // Optional logging must not block authentication.
    }
  }

  Future<void> source(String type, String id) async {
    try {
      if (!['course_created', 'material_uploaded'].contains(type)) return;
      if (_auth.currentUser == null || id.trim().isEmpty) return;
      await _invoke('source', <String, dynamic>{
        'type': type,
        'targetId': id.trim(),
      });
    } catch (_) {
      // The original course or upload operation remains successful.
    }
  }

  Future<ActivityLogPage> listAdmin({
    String category = 'all',
    DateTime? since,
    int? cursor,
    int limit = 50,
  }) async {
    final response = await _invoke('list', <String, dynamic>{
      'category': category,
      'limit': limit,
      'since': ?since?.toUtc().toIso8601String(),
      'cursor': ?cursor,
    });
    final rawRows = response['rows'];
    final rows = rawRows is List
        ? rawRows
              .whereType<Map>()
              .map((row) => ActivityLogRecord(Map<String, dynamic>.from(row)))
              .toList()
        : <ActivityLogRecord>[];
    return ActivityLogPage(
      rows: rows,
      nextCursor: _int(response['nextCursor']),
    );
  }

  Future<ActivityLogMigrationResult> migrateLegacyLogs({
    void Function(int copied, int scanned)? onProgress,
  }) async {
    String? cursor;
    var copied = 0;
    var scanned = 0;
    for (var page = 0; page < 1000; page++) {
      final response = await _invoke('migrate', <String, dynamic>{
        'limit': 100,
        'cursor': ?cursor,
      });
      copied += _int(response['copied']) ?? 0;
      scanned += _int(response['scanned']) ?? 0;
      onProgress?.call(copied, scanned);
      final next = (response['nextCursor'] ?? '').toString().trim();
      if (response['done'] == true || next.isEmpty) {
        return ActivityLogMigrationResult(copied: copied, scanned: scanned);
      }
      cursor = next;
    }
    throw const ActivityLogException(
      'Migration stopped after the maximum safe number of pages.',
    );
  }

  Future<void> signOut() async {
    await session('logout')
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    await _auth.signOut();
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}

class ActivityLogRecord {
  const ActivityLogRecord(this.data);
  final Map<String, dynamic> data;
  String get id => (data['id'] ?? '').toString();
}

class ActivityLogPage {
  const ActivityLogPage({required this.rows, required this.nextCursor});
  final List<ActivityLogRecord> rows;
  final int? nextCursor;
}

class ActivityLogMigrationResult {
  const ActivityLogMigrationResult({
    required this.copied,
    required this.scanned,
  });
  final int copied;
  final int scanned;
}

class ActivityLogException implements Exception {
  const ActivityLogException(this.message);
  final String message;
  @override
  String toString() => message;
}
