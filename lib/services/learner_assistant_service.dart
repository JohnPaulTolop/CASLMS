import 'ai_router_service.dart';

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'learner_assistant_report.dart';
import 'student_assessment_query_service.dart';

class LearnerAssistantException implements Exception {
  const LearnerAssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AssistantStudent {
  const AssistantStudent(this.id, this.label);
  final String id;
  final String label;
}

class LearnerAssistantReply {
  const LearnerAssistantReply(this.text, this.records, {this.usedAi = false});
  final String text;
  final String records;
  final bool usedAi;
}

/// All queries use the authenticated account's UID, never a prompt-generated UID.
/// The model has no database tools and sees only a sanitized selected-student report.
class LearnerAssistantService {
  LearnerAssistantService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<AssistantRow> _account(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const LearnerAssistantException('Please sign in again.');
    }
    final doc = await _db
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (data == null ||
        data['role'] != role ||
        data['status'] != 'active' ||
        !['student', 'instructor'].contains(role)) {
      throw const LearnerAssistantException(
        'An active account for this role is required.',
      );
    }
    return {...data, 'id': doc.id};
  }

  void _checkSession(String uid) {
    if (_auth.currentUser?.uid != uid) {
      throw const LearnerAssistantException(
        'Your session changed. Reopen the assistant.',
      );
    }
  }

  Future<List<AssistantRow>> _read(Query<Map<String, dynamic>> query) async {
    final rows = <AssistantRow>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var pageQuery = query.orderBy(FieldPath.documentId).limit(250);
      if (cursor != null) pageQuery = pageQuery.startAfterDocument(cursor);
      final page = await pageQuery.get(const GetOptions(source: Source.server));
      for (final doc in page.docs) {
        rows.add({
          ...doc.data().map(
            (key, value) =>
                MapEntry(key, value is Timestamp ? value.toDate() : value),
          ),
          'id': doc.id,
        });
      }
      if (rows.length > 5000) {
        throw const LearnerAssistantException(
          'There are too many records for one report. Ask your administrator for a filtered report.',
        );
      }
      if (page.docs.length < 250) return rows;
      cursor = page.docs.last;
    }
  }

  // Student queries must include section and publication filters. Instructor
  // reports retain their existing owned-course queries.
  Future<List<AssistantRow>> _studentAssessments(String courseId) async {
    final documents = await StudentAssessmentQueryService(
      firestore: _db,
      auth: _auth,
    ).getVisibleAssessments(courseId: courseId);
    return documents.map((document) {
      return <String, dynamic>{
        ...document.data().map(
          (key, value) =>
              MapEntry(key, value is Timestamp ? value.toDate() : value),
        ),
        'id': document.id,
      };
    }).toList();
  }

  Future<List<AssistantRow>> _ownedCourses(String uid) async => (await _read(
    _db.collection('courses').where('instructorId', isEqualTo: uid),
  )).where((course) => course['status'] == 'active').toList();

  Future<List<AssistantStudent>> students(String role) async {
    final account = await _account(role);
    final uid = account['id'] as String;
    if (role == 'student') return [AssistantStudent(uid, 'My records')];
    final courses = await _ownedCourses(uid);
    final roster = <String, AssistantStudent>{};
    for (final course in courses) {
      final enrollments = await _read(
        _db
            .collection('enrollments')
            .where('courseId', isEqualTo: course['id']),
      );
      for (final enrollment in enrollments) {
        if (enrollment['status'] != 'active') continue;
        final id = assistantText(enrollment['studentId']);
        if (id.isEmpty) continue;
        final name = assistantText(enrollment['studentName']);
        final campusId = assistantText(enrollment['studentCampusId']);
        roster[id] = AssistantStudent(
          id,
          '${name.isEmpty ? 'Student' : name}${campusId.isEmpty ? '' : ' · $campusId'}',
        );
      }
    }
    _checkSession(uid);
    return roster.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<LearnerAssistantReport> _report(
    String role,
    String? selectedStudent,
  ) async {
    final account = await _account(role);
    final uid = account['id'] as String;
    final studentId = role == 'student' ? uid : selectedStudent;
    if (studentId == null || studentId.isEmpty) {
      throw const LearnerAssistantException(
        'Choose a student from your classes first.',
      );
    }
    final courses = <AssistantRow>[];
    if (role == 'student') {
      final enrollments = await _read(
        _db.collection('enrollments').where('studentId', isEqualTo: uid),
      );
      final ids = enrollments
          .where((e) => e['status'] == 'active')
          .map((e) => assistantText(e['courseId']))
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final id in ids) {
        final doc = await _db
            .collection('courses')
            .doc(id)
            .get(const GetOptions(source: Source.server));
        final data = doc.data();
        if (data != null && data['status'] == 'active') {
          courses.add({...data, 'id': id});
        }
      }
    } else {
      for (final course in await _ownedCourses(uid)) {
        final rows = await _read(
          _db
              .collection('enrollments')
              .where('courseId', isEqualTo: course['id'])
              .where('studentId', isEqualTo: studentId),
        );
        if (rows.any((e) => e['status'] == 'active')) courses.add(course);
      }
      if (courses.isEmpty) {
        throw const LearnerAssistantException(
          'This student has no active enrollment in your classes. Refresh the student list.',
        );
      }
    }

    // A staff query cannot reach this profile read until enrollment is checked.
    final profile = role == 'student'
        ? account
        : (await _db
                  .collection('users')
                  .doc(studentId)
                  .get(const GetOptions(source: Source.server)))
              .data();
    if (profile == null || profile['role'] != 'student') {
      throw const LearnerAssistantException(
        'The student profile is unavailable.',
      );
    }
    String value(String key) => assistantText(profile[key]).isEmpty
        ? 'Not recorded'
        : assistantText(profile[key]);
    final details = <String, dynamic>{
      'name': value('name'),
      'campusId': value('universityId'),
      'email': value('email'),
      'department': value('department'),
      'program': value('course'),
      'accountStatus': value('status'),
    };
    final subjectLabels = <String>[];
    final tasks = <AssistantRow>[];
    for (final course in courses) {
      final id = course['id'] as String;
      final label = [
        course['code'],
        course['title'],
        course['semester'],
        course['academicYear'],
      ].map(assistantText).where((part) => part.isNotEmpty).join(' · ');
      subjectLabels.add(label);
      final modules = await _read(
        _db.collection('modules').where('courseId', isEqualTo: id),
      );
      final publishedModules = modules
          .where((m) => m['status'] == 'published')
          .map((m) => m['id'])
          .toSet();
      final modernAssessmentIds = <String>{};
      for (final source in ['assessment', 'assignment', 'quiz']) {
        final taskCollection = source == 'quiz' ? 'quizzes' : '${source}s';
        final resultCollection = source == 'assessment'
            ? 'assessmentSubmissions'
            : source == 'assignment'
            ? 'submissions'
            : 'quiz_attempts';
        final loaded = await Future.wait([
          source == 'assessment' && role == 'student'
              ? _studentAssessments(id)
              : _read(
                  _db
                      .collection(taskCollection)
                      .where('courseId', isEqualTo: id),
                ),
          _read(
            _db
                .collection(resultCollection)
                .where('studentId', isEqualTo: studentId)
                .where('courseId', isEqualTo: id),
          ),
        ]);
        for (final task in loaded[0]) {
          if (source == 'assessment') {
            modernAssessmentIds.add(assistantText(task['id']));
          } else if (modernAssessmentIds.contains(
            assistantText(task['assessmentId']),
          )) {
            continue;
          }
          if (task['status'] != 'published') continue;
          final moduleId = assistantText(task['moduleId']);
          if (moduleId.isNotEmpty && !publishedModules.contains(moduleId)) {
            continue;
          }
          final results = loaded[1]
              .where((r) => r['${source}Id'] == task['id'])
              .toList();
          tasks.add({
            'subject': label,
            'title': assistantText(task['title']).isEmpty
                ? 'Untitled requirement'
                : assistantText(task['title']),
            'status': assistantRequirementStatus(
              task,
              latestAssistantSubmission(results),
              source,
            ),
            if (task['dueAt'] is DateTime)
              'dueAt': (task['dueAt'] as DateTime).toIso8601String(),
          });
        }
      }
    }
    _checkSession(uid);
    return LearnerAssistantReport(
      profile: details,
      subjects: subjectLabels,
      tasks: tasks,
      instructorView: role == 'instructor',
    );
  }

  Future<LearnerAssistantReply> ask({
    required String role,
    required String question,
    String? studentId,
    void Function(String text)? onDelta,
  }) async {
    final clean = question.trim();
    if (clean.isEmpty || clean.length > 1500) {
      throw const LearnerAssistantException(
        'Enter a question of 1–1,500 characters.',
      );
    }
    final uid = _auth.currentUser?.uid;
    try {
      final report = await _report(
        role,
        studentId,
      ).timeout(const Duration(seconds: 60));
      final records = report.describe('overview');
      final q = clean.toLowerCase();
      final standard = [
        'missing',
        'incomplete',
        'approved',
        'complied',
        'submitted',
        'pending',
        'subject',
        'enroll',
        'registered',
        'detail',
        'profile',
        'overview',
      ];
      if (standard.any(q.contains)) {
        return LearnerAssistantReply(report.describe(clean), records);
      }
      final context = report.toContext();
      // Contact information stays in deterministic record views.
      context['student'] = {...report.profile}..remove('email');
      final encoded = jsonEncode(context);
      if (encoded.length > 45000) {
        return LearnerAssistantReply(
          'This report is too large for an AI summary.\n\n$records',
          records,
        );
      }
      try {
        final prompt = jsonEncode({'question': clean, 'records': context});
        final answer = await AiRouterService().complete(
          task: 'records_summary',
          messages: [
            {'role': 'user', 'content': prompt},
          ],
          onDelta: onDelta,
        );
        if (uid == null) {
          throw const LearnerAssistantException('Please sign in again.');
        }
        _checkSession(uid);
        if (answer.trim().isNotEmpty) {
          return LearnerAssistantReply(answer.trim(), records, usedAi: true);
        }
      } on LearnerAssistantException {
        rethrow;
      } catch (_) {
        // Preserve the verified report during AI outages or quota exhaustion.
      }
      return LearnerAssistantReply(
        'AI summaries are unavailable right now. Here are the current records:\n\n$records',
        records,
      );
    } on LearnerAssistantException {
      rethrow;
    } on FirebaseException catch (error) {
      throw LearnerAssistantException(
        error.code == 'permission-denied'
            ? 'Some records could not be accessed. Check your course enrollment or contact your instructor.'
            : error.code == 'failed-precondition'
            ? 'A database query needs an index. Ask the administrator to check the Flutter console.'
            : 'Unable to read current records. Check your connection and try again.',
      );
    } on TimeoutException {
      throw const LearnerAssistantException(
        'Loading records took too long. Please try again.',
      );
    }
  }
}
