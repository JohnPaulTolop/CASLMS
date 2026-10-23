import 'dart:async';

import 'package:caslms/screens/session_gate.dart';
import 'package:caslms/services/campus_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get emailVerified => true;
}

class _Auth extends Fake implements CampusAuthService {
  _Auth(String uid) : _user = _User(uid);
  User? _user;
  int sessionReads = 0;
  final watchCalls = <String, int>{};
  final sessions = StreamController<User?>.broadcast(sync: true);
  final profiles = <String, StreamController<Map<String, dynamic>?>>{};

  @override
  User? get currentUser => _user;
  @override
  Stream<User?> get authStateChanges {
    sessionReads++;
    // Each invocation returns a fresh stream, like the real Firebase wrapper.
    return sessions.stream.map((user) => user);
  }

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    watchCalls.update(uid, (count) => count + 1, ifAbsent: () => 1);
    return profiles
        .putIfAbsent(
          uid,
          () => StreamController<Map<String, dynamic>?>.broadcast(sync: true),
        )
        .stream
        .map((profile) => profile);
  }

  void tokenEvent(String uid) {
    _user = _User(uid);
    sessions.add(_user);
  }

  void profile(String uid, String status) => profiles[uid]!.add({
    'uid': uid,
    'role': 'instructor',
    'status': status,
    'name': 'Instructor $uid',
    'universityId': '12345',
    'email': '$uid@example.com',
  });

  @override
  Future<void> signOut() async {
    _user = null;
    sessions.add(null);
  }

  Future<void> close() async {
    await sessions.close();
    for (final controller in profiles.values) {
      await controller.close();
    }
  }
}

void main() {
  testWidgets(
    'token renewal and parent rebuilds keep the profile listener and page mounted',
    (tester) async {
      final auth = _Auth('first');
      late StateSetter rebuildHost;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildHost = setState;
              return SessionGate(authService: auth);
            },
          ),
        ),
      );
      auth.profile('first', 'pending');
      await tester.pump();
      expect(find.text('Waiting for approval'), findsOneWidget);
      final originalElement = tester.element(find.text('Waiting for approval'));
      for (var event = 0; event < 6; event++) {
        auth.tokenEvent('first');
        rebuildHost(() {});
        await tester.pump();
        expect(find.text('Waiting for approval'), findsOneWidget);
        expect(
          identical(
            originalElement,
            tester.element(find.text('Waiting for approval')),
          ),
          isTrue,
        );
        expect(auth.sessionReads, 1);
        expect(auth.watchCalls['first'], 1);
      }
      // Stabilizing streams must retain real-time access revocation.
      auth.profile('first', 'suspended');
      await tester.pump();
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(auth.profiles['first']!.hasListener, isFalse);
      await auth.close();
    },
  );

  testWidgets(
    'changing account cancels the old profile and ignores its late events',
    (tester) async {
      final auth = _Auth('first');
      await tester.pumpWidget(
        MaterialApp(home: SessionGate(authService: auth)),
      );
      auth.profile('first', 'pending');
      await tester.pump();
      auth.tokenEvent('second');
      await tester.pump();
      expect(auth.profiles['first']!.hasListener, isFalse);
      expect(find.text('Waiting for approval'), findsNothing);
      auth.profile('first', 'pending');
      auth.profile('second', 'denied');
      await tester.pump();
      expect(find.text('Application denied'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsNothing);
      expect(auth.watchCalls, {'first': 1, 'second': 1});
      await tester.pumpWidget(const SizedBox.shrink());
      expect(auth.profiles['second']!.hasListener, isFalse);
      await auth.close();
    },
  );
}
