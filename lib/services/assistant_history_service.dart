import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AssistantHistoryEntry {
  const AssistantHistoryEntry({
    required this.id,
    required this.title,
    required this.updated,
    required this.studyHelp,
    required this.messages,
    this.studentId,
    this.hasAttachments = false,
  });
  final String id, title;
  final DateTime updated;
  final bool studyHelp, hasAttachments;
  final String? studentId;
  final List<Map<String, dynamic>> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'updated': updated.toIso8601String(),
    'studyHelp': studyHelp,
    'studentId': studentId,
    'hasAttachments': hasAttachments,
    'messages': messages,
  };
  static AssistantHistoryEntry? fromJson(dynamic value) {
    if (value is! Map || value['id'] is! String || value['messages'] is! List) {
      return null;
    }
    final messages = <Map<String, dynamic>>[];
    for (final row in (value['messages'] as List).take(80)) {
      if (row is! Map || row['text'] is! String) continue;
      final text = row['text'] as String;
      messages.add({
        'text': text.substring(0, text.length.clamp(0, 6000)),
        'isUser': row['isUser'] == true,
        'isError': row['isError'] == true,
      });
    }
    if (messages.isEmpty) return null;
    final title = (value['title'] ?? 'Conversation').toString();
    return AssistantHistoryEntry(
      id: value['id'],
      title: title.substring(0, title.length.clamp(0, 100)),
      updated:
          DateTime.tryParse(value['updated'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      studyHelp: value['studyHelp'] != false,
      studentId: value['studentId'] is String ? value['studentId'] : null,
      hasAttachments: value['hasAttachments'] == true,
      messages: messages,
    );
  }
}

/// Local, account- and role-scoped transcripts. No files or source records saved.
class AssistantHistoryService {
  static Future<void>? _writes;
  String _key(String uid, String role) =>
      'assistant-history-v1:${Uri.encodeComponent(role)}:${Uri.encodeComponent(uid)}';

  Future<List<AssistantHistoryEntry>> load(String uid, String role) async {
    if (uid.isEmpty) return [];
    final pending = _writes;
    if (pending != null) await pending;
    return _read(await SharedPreferences.getInstance(), uid, role);
  }

  List<AssistantHistoryEntry> _read(
    SharedPreferences prefs,
    String uid,
    String role,
  ) {
    try {
      final value = jsonDecode(prefs.getString(_key(uid, role)) ?? '[]');
      if (value is! List) return [];
      return value
          .map(AssistantHistoryEntry.fromJson)
          .whereType<AssistantHistoryEntry>()
          .toList()
        ..sort((a, b) => b.updated.compareTo(a.updated));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String uid, String role, AssistantHistoryEntry entry) =>
      _write(() async {
        if (uid.isEmpty || entry.messages.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final clean = AssistantHistoryEntry.fromJson(entry.toJson());
        if (clean == null) return;
        final rows = [
          clean,
          ..._read(prefs, uid, role).where((row) => row.id != entry.id),
        ].take(20).toList();
        var encoded = jsonEncode(rows.map((row) => row.toJson()).toList());
        while (encoded.length > 1500000 && rows.length > 1) {
          rows.removeLast();
          encoded = jsonEncode(rows.map((row) => row.toJson()).toList());
        }
        if (!await prefs.setString(_key(uid, role), encoded)) {
          throw StateError('History could not be saved.');
        }
      });

  Future<void> delete(String uid, String role, String id) => _write(() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = _read(
      prefs,
      uid,
      role,
    ).where((row) => row.id != id).map((row) => row.toJson()).toList();
    if (!await prefs.setString(_key(uid, role), jsonEncode(rows))) {
      throw StateError('History could not be deleted.');
    }
  });

  Future<void> _write(Future<void> Function() action) {
    final previous = _writes;
    late final Future<void> result;
    result = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* A failed save must not block later saves. */
        }
      }
      try {
        await action();
      } finally {
        if (identical(_writes, result)) _writes = null;
      }
    }();
    _writes = result;
    return result;
  }
}
