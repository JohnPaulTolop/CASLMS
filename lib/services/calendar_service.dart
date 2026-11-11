import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/calendar_entry.dart';
import 'course_content_paths.dart';
import 'enrollment_service.dart';
import 'student_assessment_query_service.dart';
import 'section_audience_service.dart';

class CalendarService {
  CalendarService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    bool? temporaryEvents,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       temporaryEvents = temporaryEvents ?? !liveEventsEnabled;
  static const liveEventsEnabled = bool.fromEnvironment(
    'CASLMS_LIVE_CALENDAR_EVENTS',
    defaultValue: false,
  );
  final bool temporaryEvents;
  static final _temporary = <String, CalendarEntry>{};
  static final _seeded = <String>{};
  static void _sample(String id, CalendarEntry Function() create) {
    if (_seeded.add(id)) _temporary[id] = create();
  }

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  String? get uid => _auth.currentUser?.uid;
  Stream<String?> get accountChanges =>
      _auth.authStateChanges().map((user) => user?.uid);
  void _check(String id) {
    if (uid != id) throw StateError('Your session changed. Reopen Calendar.');
  }

  Future<String> _account(String role) async {
    final id = uid;
    if (id == null) throw StateError('Please sign in again.');
    final profile =
        (await _db
                .collection('users')
                .doc(id)
                .get(const GetOptions(source: Source.server)))
            .data();
    _check(id);
    final profileRole = (profile?['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final profileStatus = (profile?['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (!['student', 'instructor', 'admin'].contains(role) ||
        profileRole != role ||
        profileStatus != 'active') {
      throw StateError('An active account is required.');
    }
    return id;
  }

  Future<CalendarData> load(String role) async {
    final id = await _account(role);
    final List<Map<String, dynamic>> courses;
    if (role == 'student') {
      courses = await EnrollmentService().getMyActiveCourses();
    } else {
      Query<Map<String, dynamic>> query = _db.collection('courses');
      if (role == 'instructor') {
        query = query.where('instructorId', isEqualTo: id);
      }
      courses = (await query.get(const GetOptions(source: Source.server))).docs
          .where((doc) => doc.data()['status'] == 'active')
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    }
    _check(id);
    final entries = <CalendarEntry>[];
    Future<void> readEvents(String? courseId) async {
      Query<Map<String, dynamic>> query;
      if (role == 'student' && courseId != null && courseId.isNotEmpty) {
        query = CourseContentPaths.calendarEvents(
          _db,
          courseId,
        ).where('courseId', isEqualTo: courseId);
      } else {
        query = _db.collection('calendarEvents');
      }
      if (courseId != null && !(role == 'student' && courseId.isNotEmpty)) {
        query = query.where('courseId', isEqualTo: courseId);
      }
      final docs = await query.get(const GetOptions(source: Source.server));
      for (final doc in docs.docs) {
        final row = doc.data();
        final start = _date(row['startAt']), end = _date(row['endAt']);
        if (start == null || end == null) continue;
        final course = courses
            .where((course) => course['id'] == row['courseId'])
            .firstOrNull;
        entries.add(
          CalendarEntry(
            id: doc.id,
            title: row['title'] as String,
            start: start,
            end: end,
            kind: CalendarKind.event,
            description: (row['description'] ?? '').toString(),
            allDay: row['allDay'] == true,
            courseId: (row['courseId'] ?? '').toString(),
            courseLabel: (course?['code'] ?? 'Schoolwide').toString(),
            ownerId: row['ownerId'] as String,
          ),
        );
      }
    }

    var eventsAvailable = true;
    try {
      if (temporaryEvents) {
        _seedTemporary(courses);
        final courseIds = courses
            .map((course) => course['id'].toString())
            .toSet();
        entries.addAll(
          _temporary.values.where(
            (event) =>
                role == 'admin' ||
                event.courseId.isEmpty ||
                courseIds.contains(event.courseId),
          ),
        );
      } else {
        if (role == 'admin') {
          await readEvents(null);
        } else {
          await Future.wait([
            readEvents(''),
            for (final course in courses) readEvents(course['id'].toString()),
          ]);
        }
      }
    } on FirebaseException {
      // A separate event outage must not hide authorized coursework deadlines.
      eventsAvailable = false;
      entries.clear();
    }
    // Reuse section-scoped student assessment queries; never fetch another section.
    await Future.wait(
      courses.map((course) async {
        final courseId = course['id'].toString();
        final QuerySnapshot<Map<String, dynamic>> modules;
        if (role == 'student') {
          final enrollment = await SectionAudienceService(firestore: _db)
              .requireActiveEnrollment(courseId: courseId, studentId: id);
          final sectionId = (enrollment['sectionId'] ?? '').toString().trim();
          modules = await CourseContentPaths.modules(_db, courseId)
              .where('courseId', isEqualTo: courseId)
              .where('status', isEqualTo: 'published')
              .where(
                'sectionIds',
                arrayContainsAny: <String>[
                  SectionAudienceService.allSections,
                  sectionId,
                ],
              )
              .get();
        } else {
          modules = await _db
              .collection('modules')
              .where('courseId', isEqualTo: courseId)
              .get();
        }
        final published = modules.docs
            .where((doc) => doc.data()['status'] == 'published')
            .map((doc) => doc.id)
            .toSet();
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> assessments;
        if (role == 'student') {
          assessments = await StudentAssessmentQueryService(
            firestore: _db,
            auth: _auth,
          ).getVisibleAssessments(courseId: courseId);
        } else {
          assessments =
              (await _db
                      .collection('assessments')
                      .where('courseId', isEqualTo: courseId)
                      .get())
                  .docs;
        }
        for (final doc in assessments) {
          final row = doc.data();
          final due = _date(row['dueAt']);
          if (due == null ||
              !['published', 'closed'].contains(row['status']) ||
              !published.contains(row['moduleId'])) {
            continue;
          }
          entries.add(
            CalendarEntry(
              id: 'due-${doc.id}',
              title: (row['title'] ?? 'Assessment').toString(),
              start: due,
              end: due,
              kind: CalendarKind.deadline,
              description: 'Assessment due date',
              courseId: courseId,
              courseLabel: (course['code'] ?? '').toString(),
              assessmentId: doc.id,
              moduleId: (row['moduleId'] ?? '').toString(),
              course: course,
            ),
          );
        }
      }),
    );
    _check(id);
    return CalendarData(
      entries: entries..sort((a, b) => a.start.compareTo(b.start)),
      courses: courses,
      eventsAvailable: eventsAvailable,
    );
  }

  DateTime? _date(dynamic value) => value is Timestamp
      ? value.toDate().toUtc()
      : value is DateTime
      ? value.toUtc()
      : null;

  void _seedTemporary(List<Map<String, dynamic>> courses) {
    final today = philippineDay(DateTime.now());
    final campus = philippineWallToUtc(
      today.add(const Duration(days: 2, hours: 10)),
    );
    _sample(
      'sample-campus',
      () => CalendarEntry(
        id: 'sample-campus',
        title: 'Sample: Campus event',
        start: campus,
        end: campus.add(const Duration(hours: 1)),
        kind: CalendarKind.event,
        ownerId: 'sample',
        courseLabel: 'Schoolwide · Sample',
        description:
            'Example event only. This is not a published school announcement.',
      ),
    );
    for (final course in courses) {
      final id = 'sample-${course['id']}';
      final start = philippineWallToUtc(
        today.add(const Duration(days: 3, hours: 9)),
      );
      _sample(
        id,
        () => CalendarEntry(
          id: id,
          title: 'Sample: Class workshop',
          start: start,
          end: start.add(const Duration(hours: 1)),
          kind: CalendarKind.event,
          courseId: course['id'].toString(),
          ownerId: (course['instructorId'] ?? '').toString(),
          courseLabel: '${course['code'] ?? 'Course'} · Sample',
          description: 'Example event only. Temporary changes are visible on this device until the app reloads.',
        ),
      );
    }
  }

  Future<void> save({
    required String role,
    required String title,
    required String description,
    required String courseId,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    CalendarEntry? existing,
  }) async {
    final id = await _account(role);
    if (!['admin', 'instructor'].contains(role) ||
        title.trim().isEmpty ||
        title.trim().length > 120 ||
        description.length > 1000 ||
        end.isBefore(start) ||
        end.difference(start) > const Duration(days: 31)) {
      throw StateError(
        'Enter a title and a valid date range of up to 31 days.',
      );
    }
    Map<String, dynamic>? course;
    if (role == 'instructor' && courseId.isEmpty) {
      throw StateError('Choose one of your courses.');
    }
    if (courseId.isNotEmpty) {
      course =
          (await _db
                  .collection('courses')
                  .doc(courseId)
                  .get(const GetOptions(source: Source.server)))
              .data();
      if ((role == 'instructor' && course?['instructorId'] != id) ||
          course?['status'] != 'active') {
        throw StateError('You can only add events to your active courses.');
      }
    }
    _check(id);
    if (temporaryEvents) {
      final previous = existing == null ? null : _temporary[existing.id];
      if (existing != null &&
          (previous == null || role != 'admin' && previous.ownerId != id)) {
        throw StateError('You cannot edit this event.');
      }
      final eventId =
          existing?.id ?? 'temp-${DateTime.now().microsecondsSinceEpoch}';
      _temporary[eventId] = CalendarEntry(
        id: eventId,
        title: title.trim(),
        description: description.trim(),
        start: start,
        end: end,
        allDay: allDay,
        kind: CalendarKind.event,
        courseId: courseId,
        courseLabel: '${course?['code'] ?? 'Schoolwide'} · Temporary',
        ownerId: previous?.ownerId ?? id,
      );
      return;
    }
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'courseId': courseId,
      'startAt': Timestamp.fromDate(start),
      'endAt': Timestamp.fromDate(end),
      'allDay': allDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existing == null) {
      final document = _db.collection('calendarEvents').doc();
      final createData = <String, dynamic>{
        ...data,
        'ownerId': id,
        'creatorRole': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final batch = _db.batch()..set(document, createData);
      if (courseId.isNotEmpty) {
        batch.set(
          CourseContentPaths.calendarEvents(_db, courseId).doc(document.id),
          createData,
        );
      }
      await batch.commit();
    } else {
      final document = _db.collection('calendarEvents').doc(existing.id);
      final current = await document.get(
        const GetOptions(source: Source.server),
      );
      final currentData = current.data() ?? <String, dynamic>{};
      final batch = _db.batch()..update(document, data);
      if (courseId.isNotEmpty) {
        batch.set(
          CourseContentPaths.calendarEvents(_db, courseId).doc(existing.id),
          {...currentData, ...data},
          SetOptions(merge: true),
        );
      }
      final previousCourseId = (currentData['courseId'] ?? existing.courseId)
          .toString()
          .trim();
      if (previousCourseId.isNotEmpty && previousCourseId != courseId) {
        batch.delete(
          CourseContentPaths.calendarEvents(
            _db,
            previousCourseId,
          ).doc(existing.id),
        );
      }
      await batch.commit();
    }
  }

  Future<void> delete(String role, CalendarEntry event) async {
    final id = await _account(role);
    if (temporaryEvents) {
      final stored = _temporary[event.id];
      if (stored == null ||
          role != 'admin' &&
              (role != 'instructor' ||
                  stored.ownerId != id ||
                  stored.courseId.isEmpty)) {
        throw StateError('You cannot delete this event.');
      }
      _check(id);
      _temporary.remove(event.id);
      return;
    }
    if (role != 'admin' && (role != 'instructor' || event.ownerId != id)) {
      throw StateError('You cannot delete this event.');
    }
    final batch = _db.batch()
      ..delete(_db.collection('calendarEvents').doc(event.id));
    if (event.courseId.isNotEmpty) {
      batch.delete(
        CourseContentPaths.calendarEvents(_db, event.courseId).doc(event.id),
      );
    }
    await batch.commit();
  }
}
