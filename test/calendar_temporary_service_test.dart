// SDK reference fakes are confined to this no-network test; app code uses real SDK references.
// ignore_for_file: subtype_of_sealed_class
import 'package:caslms/services/calendar_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Auth extends Fake implements FirebaseAuth {
  User user = _User('admin');
  @override
  User get currentUser => user;
}

class _Db extends Fake implements FirebaseFirestore {
  final paths = <String>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    paths.add(path);
    if (path == 'calendarEvents') {
      throw StateError('Temporary mode must never access shared events.');
    }
    return _Collection(path);
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(this.path, path!);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Empty();
}

class _Empty extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.collectionPath, this.id);
  final String collectionPath;
  @override
  final String id;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Document(
    collectionPath == 'users'
        ? {
            'role': id == 'admin'
                ? 'admin'
                : id == 'teacher'
                ? 'instructor'
                : 'student',
            'status': 'active',
          }
        : {
            'status': 'active',
            'code': 'IT302',
            'instructorId': id == 'owned' ? 'teacher' : 'another-teacher',
          },
  );
}

class _Document extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Document(this.row);
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}

void main() {
  test('Default temporary events can be edited and deleted without shared event access', () async {
    final db = _Db(), auth = _Auth();
    final service = CalendarService(firestore: db, auth: auth);
    expect(service.temporaryEvents, isTrue);
    final start = DateTime.utc(2026, 11, 6, 1),
        end = DateTime.utc(2026, 11, 6, 2);
    await service.save(
      role: 'admin',
      title: 'Temporary assembly',
      description: 'Local example',
      courseId: '',
      start: start,
      end: end,
      allDay: false,
    );
    var data = await service.load('admin');
    final event = data.entries.singleWhere(
      (entry) => entry.title == 'Temporary assembly',
    );
    await service.save(
      role: 'admin',
      title: 'Updated assembly',
      description: '',
      courseId: '',
      start: start,
      end: end,
      allDay: false,
      existing: event,
    );
    data = await service.load('admin');
    expect(
      data.entries.any((entry) => entry.title == 'Updated assembly'),
      isTrue,
    );
    await service.delete('admin', event);
    data = await service.load('admin');
    expect(data.entries.any((entry) => entry.id == event.id), isFalse);
    final sample = data.entries.firstWhere(
      (entry) => entry.id == 'sample-campus',
    );
    await service.delete('admin', sample);
    expect(
      (await service.load('admin')).entries
          .any((entry) => entry.id == 'sample-campus'),
      isFalse,
    );
    expect(db.paths, isNot(contains('calendarEvents')));
  });
  test(
    'Temporary authoring still restricts student writes and instructor scope',
    () async {
      final db = _Db(), auth = _Auth();
      final service = CalendarService(firestore: db, auth: auth);
      final start = DateTime.utc(2026, 11, 6, 1),
          end = DateTime.utc(2026, 11, 6, 2);
      auth.user = _User('teacher');
      await service.save(
        role: 'instructor',
        title: 'Owned workshop',
        description: '',
        courseId: 'owned',
        start: start,
        end: end,
        allDay: false,
      );
      await expectLater(
        service.save(
          role: 'instructor',
          title: 'Foreign event',
          description: '',
          courseId: 'foreign',
          start: start,
          end: end,
          allDay: false,
        ),
        throwsStateError,
      );
      await expectLater(
        service.save(
          role: 'instructor',
          title: 'Schoolwide event',
          description: '',
          courseId: '',
          start: start,
          end: end,
          allDay: false,
        ),
        throwsStateError,
      );
      auth.user = _User('student');
      await expectLater(
        service.save(
          role: 'student',
          title: 'Student event',
          description: '',
          courseId: 'owned',
          start: start,
          end: end,
          allDay: false,
        ),
        throwsStateError,
      );
      expect(db.paths, isNot(contains('calendarEvents')));
    },
  );
}
