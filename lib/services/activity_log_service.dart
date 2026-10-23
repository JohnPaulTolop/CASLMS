import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// App activity, not a replacement for identity-provider security audit logs.
/// Failures never turn a successful login, upload or course creation into an error.
class ActivityLogService {
  ActivityLogService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  static final Set<String> _recordedSessions = {};

  Future<void> session(String type, {Map<String, dynamic>? profile}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || !['login', 'logout'].contains(type)) return;
      final data =
          profile ?? (await _db.collection('users').doc(user.uid).get()).data();
      if (data == null || data['status'] != 'active') return;
      final token = await user.getIdTokenResult();
      final authTime = token.claims?['auth_time'];
      if (authTime is! num) return;
      final id = '${type}_${authTime.toInt()}_${user.uid}';
      if (_recordedSessions.contains(id)) return;
      await _db.collection('activityLogs').doc(id).set({
        'type': type,
        'actorId': user.uid,
        'actorName': (data['name'] ?? '').toString(),
        'actorRole': data['role'],
        'sessionAuthTime': authTime.toInt(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _recordedSessions.add(id);
    } catch (_) {
      /* Optional logging must not block authentication. */
    }
  }

  Future<void> source(String type, String id) async {
    try {
      if (!['course_created', 'material_uploaded'].contains(type)) return;
      final user = _auth.currentUser;
      if (user == null) return;
      final profile = (await _db.collection('users').doc(user.uid).get())
          .data();
      if (profile == null || profile['status'] != 'active') return;
      final collection = type == 'course_created'
          ? 'courses'
          : 'moduleResources';
      final data = (await _db.collection(collection).doc(id).get()).data();
      if (data == null) return;
      await _db.collection('activityLogs').doc('${type}_$id').set({
        'type': type,
        'actorId': user.uid,
        'actorName': (profile['name'] ?? '').toString(),
        'actorRole': profile['role'],
        'targetId': id,
        'courseId': type == 'course_created' ? id : data['courseId'],
        'title': (data['title'] ?? '').toString(),
        'occurredAt': data['createdAt'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      /* The original operation remains successful. */
    }
  }

  Future<void> signOut() async {
    // Firestore needs the existing session to authorize this append-only record.
    // Sign-out continues even when offline or logging is unavailable.
    await session('logout')
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    await _auth.signOut();
  }
}
