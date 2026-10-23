import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// One authorized directory feed shared by admin overview and file filters.
class AdminCatalog extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final List<StreamSubscription> _subscriptions = [];
  final Set<String> _ready = {};
  final Map<String, String> _errors = {};
  bool _disposed = false;
  int _generation = 0;
  Map<String, Map<String, dynamic>> users = {};
  Map<String, Map<String, dynamic>> courses = {};
  Map<String, Map<String, dynamic>> pendingApplications = {};
  bool get loading => !_ready.containsAll(['users', 'courses', 'applications']);
  String? get error => _errors.isEmpty ? null : _errors.values.join(' ');

  Future<void> start() async {
    final generation = ++_generation;
    final previous = _subscriptions.toList();
    _subscriptions.clear();
    await Future.wait(previous.map((subscription) => subscription.cancel()));
    if (_disposed || generation != _generation) return;
    _ready.clear();
    _errors.clear();
    notifyListeners();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in as an administrator.');
      final profile = (await _db.collection('users').doc(uid).get()).data();
      if (profile?['role'] != 'admin' || profile?['status'] != 'active') {
        throw StateError('Active administrator access is required.');
      }
      if (_disposed || generation != _generation) return;
      void listen(
        String name,
        Query<Map<String, dynamic>> query,
        void Function(Map<String, Map<String, dynamic>>) assign,
      ) {
        _subscriptions.add(
          query.snapshots().listen(
            (snapshot) {
              if (_disposed || generation != _generation) return;
              assign({
                for (final d in snapshot.docs)
                  d.id: {...d.data(), 'id': d.id, 'uid': d.id},
              });
              _ready.add(name);
              _errors.remove(name);
              notifyListeners();
            },
            onError: (Object error) {
              if (_disposed || generation != _generation) return;
              _ready.add(name);
              _errors[name] = 'Unable to sync $name. Please retry.';
              notifyListeners();
            },
          ),
        );
      }

      listen('users', _db.collection('users'), (rows) => users = rows);
      listen('courses', _db.collection('courses'), (rows) => courses = rows);
      listen(
        'applications',
        _db
            .collection('instructorApplications')
            .where('status', isEqualTo: 'pending'),
        (rows) => pendingApplications = rows,
      );
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _ready.addAll(['users', 'courses', 'applications']);
      _errors['access'] = 'Unable to load the admin directory. Check your connection and account access.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

class AdminScope extends InheritedNotifier<AdminCatalog> {
  const AdminScope({
    super.key,
    required AdminCatalog catalog,
    required super.child,
  }) : super(notifier: catalog);
  static AdminCatalog of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminScope>()!.notifier!;
}
