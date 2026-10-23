import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_order.dart';

/// Reference-counted shared listeners. Dashboard and Classes share one feed.
class LiveCoursesService {
  static final Map<String, _LiveCoursesFeed> _feeds = {};
  static Stream<List<Map<String, dynamic>>> watch(
    FirebaseFirestore db,
    String uid, {
    bool instructor = false,
  }) {
    return Stream.multi((sink) {
      final key = '${identityHashCode(db)}:$uid:$instructor';
      final feed = _feeds.putIfAbsent(
        key,
        () => _LiveCoursesFeed(db, uid, instructor, () => _feeds.remove(key)),
      );
      final subscription = feed.stream.listen(sink.add, onError: sink.addError);
      if (feed.latest != null) sink.add(feed.latest!);
      sink.onCancel = subscription.cancel;
    });
  }
}

class _LiveCoursesFeed {
  _LiveCoursesFeed(this.db, this.uid, this.instructor, this.onEmpty) {
    _controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }
  final FirebaseFirestore db;
  final String uid;
  final bool instructor;
  final void Function() onEmpty;
  late final StreamController<List<Map<String, dynamic>>> _controller;
  Stream<List<Map<String, dynamic>>> get stream => _controller.stream;
  StreamSubscription? _sourceSubscription;
  final Map<String, StreamSubscription> _details = {};
  Map<String, Map<String, dynamic>> _source = {};
  final Map<String, Map<String, dynamic>> _courses = {};
  final Map<String, int> _counts = {};
  final Set<String> _ready = {};
  List<Map<String, dynamic>>? latest;
  bool _closed = false;
  void _error(Object error) {
    if (!_closed) _controller.addError(error);
  }

  void _start() {
    final query = db
        .collection(instructor ? 'courses' : 'enrollments')
        .where(instructor ? 'instructorId' : 'studentId', isEqualTo: uid);
    _sourceSubscription = query.snapshots().listen((snapshot) {
      if (_closed) return;
      final next = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] != 'active') continue;
        final id = instructor ? doc.id : (data['courseId'] ?? '').toString();
        if (id.isEmpty ||
            id.contains('/') ||
            (!instructor && doc.id != '${id}_$uid')) {
          continue;
        }
        next[id] = {...data, 'id': doc.id};
      }
      _source = next;
      for (final id in _details.keys.toList()) {
        if (!next.containsKey(id)) {
          _details.remove(id)?.cancel();
          _courses.remove(id);
          _counts.remove(id);
          _ready.remove(id);
        }
      }
      for (final entry in next.entries) {
        final id = entry.key;
        if (instructor) _courses[id] = entry.value;
        if (_details.containsKey(id)) continue;
        if (instructor) {
          _details[id] = db
              .collection('enrollments')
              .where('courseId', isEqualTo: id)
              .snapshots()
              .listen(
                (members) {
                  if (_closed || !_source.containsKey(id)) return;
                  _counts[id] = members.docs
                      .where(
                        (d) =>
                            d.data()['status'] == 'active' &&
                            d.id == '${id}_${d.data()['studentId']}',
                      )
                      .map((d) => d.data()['studentId'])
                      .toSet()
                      .length;
                  _ready.add(id);
                  _emit();
                },
                onError: (Object error) {
                  _ready.add(id);
                  _error(error);
                  _emit();
                },
              );
        } else {
          _details[id] = db
              .collection('courses')
              .doc(id)
              .snapshots()
              .listen(
                (course) {
                  if (_closed || !_source.containsKey(id)) return;
                  final data = course.data();
                  if (data != null && data['status'] == 'active') {
                    _courses[id] = {...data, 'id': id};
                  } else {
                    _courses.remove(id);
                  }
                  _ready.add(id);
                  _emit();
                },
                onError: (Object error) {
                  _courses.remove(id);
                  _ready.add(id);
                  _error(error);
                  _emit();
                },
              );
        }
      }
      _emit();
    }, onError: _error);
  }

  void _emit() {
    if (_closed || _source.keys.any((id) => !_ready.contains(id))) return;
    final rows = <Map<String, dynamic>>[];
    for (final entry in _source.entries) {
      final course = _courses[entry.key];
      if (course == null) continue;
      final membership = entry.value;
      rows.add({
        ...course,
        'id': entry.key,
        'courseId': entry.key,
        if (instructor) 'studentCount': _counts[entry.key] ?? 0,
        if (!instructor) ...{
          'enrollmentId': membership['id'],
          'joinedAt': membership['enrolledAt'] ?? membership['acceptedAt'],
          'sectionId': (membership['sectionId'] ?? course['classCode'] ?? '')
              .toString(),
        },
      });
    }
    if (instructor) {
      rows.sort(
        (a, b) =>
            courseDate(b['createdAt']).compareTo(courseDate(a['createdAt'])),
      );
    } else {
      rows.sort(compareJoinedCourses);
    }
    latest = rows;
    _controller.add(rows);
  }

  void _stop() {
    _closed = true;
    onEmpty();
    _sourceSubscription?.cancel();
    for (final sub in _details.values) {
      sub.cancel();
    }
    _details.clear();
    _controller.close();
  }
}
