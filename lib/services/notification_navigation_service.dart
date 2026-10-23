import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_target.dart';
import 'live_class_service.dart';

class NotificationAccessException implements Exception {
  const NotificationAccessException(this.message);
  final String message;
}

class NotificationDestination {
  const NotificationDestination(
    this.target,
    this.record,
    this.course,
    this.role,
    this.notice,
  );
  final NotificationTarget target;
  final Map<String, dynamic> record, course, notice;
  final String role;
}

class NotificationNavigationService {
  static const missing =
      'The content associated with this notification is no longer available.';
  static const denied = 'You no longer have permission to access this content.';
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<Map<String, dynamic>> _get(String collection, String id) async {
    if (!NotificationTarget.validId(id)) {
      throw const NotificationAccessException(missing);
    }
    final doc = await _db
        .collection(collection)
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) throw const NotificationAccessException(missing);
    return {...doc.data()!, 'id': doc.id};
  }

  Future<NotificationDestination> resolve(String notificationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const NotificationAccessException(denied);
    final notice = await _get('notifications', notificationId);
    if (notice['userId'] != uid) {
      throw const NotificationAccessException(denied);
    }
    final profile = await _get('users', uid);
    final role = NotificationTarget.text(profile['role']);
    if (profile['status'] != 'active' ||
        !['admin', 'instructor', 'student'].contains(role)) {
      throw const NotificationAccessException(denied);
    }
    final target = NotificationTarget.fromNotice(notice);
    if (target == null) {
      throw const NotificationAccessException(
        'This older notification has no reliable content link. Open the relevant course from your dashboard.',
      );
    }
    // Final semester grades remain encrypted behind the existing reveal flow.
    // The public notice supplies only course/term identifiers; never fetch ciphertext.
    if (target.kind == 'semesterGrade') {
      if (role != 'student') throw const NotificationAccessException(denied);
      final courseId = NotificationTarget.text(notice['courseId']);
      final course = await _get('courses', courseId);
      await _membership(uid, courseId, course, '');
      return NotificationDestination(
        target,
        {'id': target.id, 'courseId': courseId, 'termId': notice['termId']},
        course,
        role,
        notice,
      );
    }
    if (target.kind == 'liveClass') {
      final courseId = NotificationTarget.text(notice['courseId']);
      final sectionId = NotificationTarget.text(notice['sectionId']);
      final course = await _get('courses', courseId);
      if (role == 'student') {
        await _membership(uid, courseId, course, sectionId);
      }
      if (role == 'instructor' && course['instructorId'] != uid) {
        throw const NotificationAccessException(denied);
      }
      final state = await LiveClassService().request(
        action: 'state',
        courseId: courseId,
        sectionId: sectionId,
      );
      final session = state['session'] as Map?;
      if (session == null ||
          session['sessionId'] != notice['sessionId'] ||
          session['status'] != 'live') {
        throw const NotificationAccessException(missing);
      }
      return NotificationDestination(
        target,
        {'courseId': courseId, 'sectionId': sectionId},
        course,
        role,
        notice,
      );
    }
    final record = await _get(target.collection, target.id);
    if (target.kind == 'instructorApplication') {
      if (role != 'admin') throw const NotificationAccessException(denied);
      return NotificationDestination(target, record, {}, role, notice);
    }
    if (target.kind == 'instructorStatus') {
      if (target.id != uid) throw const NotificationAccessException(denied);
      return NotificationDestination(target, record, {}, role, notice);
    }
    if (target.kind == 'conversation') {
      if (record['studentId'] != uid && record['instructorId'] != uid) {
        throw const NotificationAccessException(denied);
      }
    }
    final courseId = target.kind == 'course'
        ? target.id
        : target.kind == 'announcement' &&
              record['targetType'] == 'all_classes' &&
              NotificationTarget.text(record['courseId']).isEmpty
        ? NotificationTarget.text(notice['authorizationCourseId'])
        : NotificationTarget.text(record['courseId']);
    final course = target.kind == 'course'
        ? record
        : await _get('courses', courseId);
    final noticeCourse =
        NotificationTarget.text(notice['authorizationCourseId']).isNotEmpty
        ? NotificationTarget.text(notice['authorizationCourseId'])
        : NotificationTarget.text(notice['courseId']);
    if (noticeCourse.isNotEmpty && noticeCourse != courseId) {
      throw const NotificationAccessException(denied);
    }
    if (target.kind == 'announcement' &&
        record['targetType'] == 'all_classes' &&
        record['createdBy'] != course['instructorId']) {
      throw const NotificationAccessException(denied);
    }
    if (role == 'instructor' && course['instructorId'] != uid) {
      throw const NotificationAccessException(denied);
    }
    if (target.kind == 'conversation' &&
        record['instructorId'] != course['instructorId']) {
      throw const NotificationAccessException(denied);
    }
    if (target.collection == 'assessmentSubmissions' ||
        target.collection == 'submissions') {
      final legacy = target.collection == 'submissions';
      final parent = await _get(
        legacy ? 'assignments' : 'assessments',
        NotificationTarget.text(
          record[legacy ? 'assignmentId' : 'assessmentId'],
        ),
      );
      if (parent['courseId'] != courseId) {
        throw const NotificationAccessException(denied);
      }
      if (!legacy) {
        if (NotificationTarget.text(record['moduleId']).isNotEmpty &&
            record['moduleId'] != parent['moduleId']) {
          throw const NotificationAccessException(denied);
        }
        record['moduleId'] = parent['moduleId'];
      }
      if (role == 'student') {
        await _membership(
          uid,
          courseId,
          course,
          NotificationTarget.text(parent['sectionId']),
        );
      }
    }
    if (target.collection == 'assessmentSubmissions' ||
        target.collection == 'submissions' ||
        target.kind == 'enrollment') {
      if (role == 'student' && record['studentId'] != uid) {
        throw const NotificationAccessException(denied);
      }
    }
    if (role == 'student') {
      await _membership(
        uid,
        courseId,
        course,
        NotificationTarget.text(record['sectionId']),
      );
      final moduleId = NotificationTarget.text(record['moduleId']);
      if (moduleId.isNotEmpty && target.kind != 'module') {
        final module = await _get('modules', moduleId);
        if (module['courseId'] != courseId) {
          throw const NotificationAccessException(denied);
        }
        if (module['status'] != 'published') {
          throw const NotificationAccessException(missing);
        }
      }
      if ([
            'assessments',
            'assignments',
            'modules',
            'moduleResources',
            'announcements',
          ].contains(target.collection) &&
          (record['status'] ??
                  (target.kind == 'moduleResource' ? 'published' : '')) !=
              'published') {
        throw const NotificationAccessException(missing);
      }
    }
    return NotificationDestination(target, record, course, role, notice);
  }

  Future<void> _membership(
    String uid,
    String courseId,
    Map<String, dynamic> course,
    String section,
  ) async {
    final doc = await _db
        .collection('enrollments')
        .doc('${courseId}_$uid')
        .get(const GetOptions(source: Source.server));
    final enrollment = doc.data();
    if (enrollment == null) throw const NotificationAccessException(denied);
    final memberSection =
        NotificationTarget.text(enrollment['sectionId']).isNotEmpty
        ? NotificationTarget.text(enrollment['sectionId'])
        : NotificationTarget.text(course['classCode']);
    if (enrollment['status'] != 'active' ||
        course['status'] != 'active' ||
        section.isNotEmpty && section != memberSection) {
      throw const NotificationAccessException(denied);
    }
  }
}
