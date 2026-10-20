import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'enrollment_membership.dart';

class CourseSectionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _text(Object? value) => (value ?? '').toString().trim();

  Future<Map<String, dynamic>> _ownedCourse(String courseId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Instructor login required.');
    }

    final profile = await _db.collection('users').doc(user.uid).get();

    if (profile.data()?['role'] != 'instructor' ||
        profile.data()?['status'] != 'active') {
      throw StateError('Active instructor account required.');
    }

    final document = await _db.collection('courses').doc(courseId).get();

    final course = document.data();

    if (course == null || course['instructorId'] != user.uid) {
      throw StateError('You do not own this course.');
    }

    return {...course, 'id': document.id};
  }

  Future<void> ensureLegacySection(String courseId) async {
    final course = await _ownedCourse(courseId);
    final classCode = _text(course['classCode']);

    if (classCode.isEmpty) {
      throw StateError('Course class code is missing.');
    }

    final ref = _db.collection('courseSections').doc(classCode);

    final existing = await ref.get();

    if (existing.exists) {
      if (existing.data()?['courseId'] != courseId) {
        throw StateError('Class code conflict detected.');
      }
      return;
    }

    await ref.set({
      'courseId': courseId,
      'instructorId': course['instructorId'],
      'name': _text(course['legacySectionName']).isNotEmpty
          ? course['legacySectionName']
          : 'Original Section',
      'identifier': _text(course['legacySectionIdentifier']).isNotEmpty
          ? course['legacySectionIdentifier']
          : 'ORIGINAL',
      'classCode': classCode,
      'legacy': true,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Existing courses have a virtual original section.
  // Viewing a course never writes migration data.
  Map<String, dynamic> _virtualLegacySection(
    String courseId,
    Map<String, dynamic> course,
  ) {
    final name = _text(course['legacySectionName']);
    final identifier = _text(course['legacySectionIdentifier']);
    final code = _text(course['classCode']);

    return <String, dynamic>{
      'id': code,
      'courseId': courseId,
      'instructorId': course['instructorId'],
      'name': name.isEmpty ? 'Original Section' : name,
      'identifier': identifier.isEmpty ? 'ORIGINAL' : identifier,
      'classCode': code,
      'legacy': true,
      'virtual': true,
      'status': 'active',
    };
  }

  Future<List<Map<String, dynamic>>> getSections(String courseId) async {
    final course = await _ownedCourse(courseId);

    final snapshot = await _db
        .collection('courseSections')
        .where('courseId', isEqualTo: courseId)
        .get();

    final sections = snapshot.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();

    final legacyCode = _text(course['classCode']);

    if (legacyCode.isNotEmpty && !sections.any((s) => s['id'] == legacyCode)) {
      sections.add(_virtualLegacySection(courseId, course));
    }

    sections.sort((a, b) {
      if (a['legacy'] == true && b['legacy'] != true) {
        return -1;
      }
      if (b['legacy'] == true && a['legacy'] != true) {
        return 1;
      }
      return _text(a['identifier']).compareTo(_text(b['identifier']));
    });

    final enrollments = await _db
        .collection('enrollments')
        .where('courseId', isEqualTo: courseId)
        .get();
    final counts = EnrollmentMembership.counts(
      enrollments.docs.map(
        (doc) => <String, dynamic>{...doc.data(), 'id': doc.id},
      ),
      legacyCode,
    );
    return sections
        .map(
          (section) => <String, dynamic>{
            ...section,
            'studentCount': counts[section['id']] ?? 0,
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>> getSection({
    required String courseId,
    required String sectionId,
  }) async {
    final course = await _ownedCourse(courseId);

    final snapshot = await _db
        .collection('courseSections')
        .doc(sectionId)
        .get();

    final section = snapshot.data();

    if (section != null && section['courseId'] == courseId) {
      return {...section, 'id': snapshot.id};
    }

    if (section == null && sectionId == _text(course['classCode'])) {
      return _virtualLegacySection(courseId, course);
    }

    throw StateError('Section not found in this course.');
  }

  Future<String> createSection({
    required String courseId,
    required String name,
    required String identifier,
  }) async {
    final course = await _ownedCourse(courseId);

    final cleanName = name.trim();
    final cleanIdentifier = identifier.trim().toUpperCase();

    if (cleanName.isEmpty || cleanName.length > 80) {
      throw StateError('Invalid section name.');
    }

    if (!RegExp(r'^[A-Z0-9][A-Z0-9 -]{0,29}$').hasMatch(cleanIdentifier)) {
      throw StateError('Invalid section identifier.');
    }

    final existing = await getSections(courseId);

    if (existing.any(
      (section) =>
          _text(section['identifier']).toUpperCase() == cleanIdentifier,
    )) {
      throw StateError('Section identifier already exists.');
    }

    final prefix = _text(course['code'])
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    if (prefix.isEmpty) {
      throw StateError('Course code is missing.');
    }

    final random = Random.secure();

    for (var attempt = 0; attempt < 30; attempt++) {
      final suffix = List.generate(
        7,
        (_) => _alphabet[random.nextInt(_alphabet.length)],
      ).join();

      final classCode = '$prefix-$suffix';

      final ref = _db.collection('courseSections').doc(classCode);

      if ((await ref.get()).exists) continue;

      final oldCodes = await _db
          .collection('courses')
          .where('classCode', isEqualTo: classCode)
          .limit(1)
          .get();

      if (oldCodes.docs.isNotEmpty) continue;

      await ref.set({
        'courseId': courseId,
        'instructorId': course['instructorId'],
        'name': cleanName,
        'identifier': cleanIdentifier,
        'classCode': classCode,
        'legacy': false,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return classCode;
    }

    throw StateError('Unable to generate a class code.');
  }

  Future<void> renameSection({
    required String courseId,
    required String sectionId,
    required String name,
    required String identifier,
  }) async {
    final section = await getSection(courseId: courseId, sectionId: sectionId);

    final cleanName = name.trim();
    final cleanIdentifier = identifier.trim().toUpperCase();

    if (cleanName.isEmpty ||
        cleanName.length > 80 ||
        !RegExp(r'^[A-Z0-9][A-Z0-9 -]{0,29}$').hasMatch(cleanIdentifier)) {
      throw StateError('Invalid section name or identifier.');
    }

    final sections = await getSections(courseId);

    if (sections.any(
      (item) =>
          item['id'] != sectionId &&
          _text(item['identifier']).toUpperCase() == cleanIdentifier,
    )) {
      throw StateError('Section identifier already exists.');
    }

    if (section['virtual'] != true) {
      await _db.collection('courseSections').doc(sectionId).update({
        'name': cleanName,
        'identifier': cleanIdentifier,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (section['legacy'] == true) {
      await _db.collection('courses').doc(courseId).update({
        'legacySectionName': cleanName,
        'legacySectionIdentifier': cleanIdentifier,
      });
    }
  }

  Future<void> assignStudent({
    required String courseId,
    required String sectionId,
    required String studentId,
  }) async {
    final section = await getSection(courseId: courseId, sectionId: sectionId);

    if (section['status'] != 'active') {
      throw StateError('Section is archived.');
    }

    final ref = _db.collection('enrollments').doc('${courseId}_$studentId');

    final enrollment = await ref.get();
    final data = enrollment.data();

    if (data == null ||
        data['courseId'] != courseId ||
        data['studentId'] != studentId ||
        data['status'] != 'active') {
      throw StateError('Student is not actively enrolled.');
    }

    await ref.update({
      'sectionId': sectionId,
      'sectionName': section['name'],
      'sectionIdentifier': section['identifier'],
      'sectionAssignedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveSection({
    required String courseId,
    required String sectionId,
  }) async {
    final section = await getSection(courseId: courseId, sectionId: sectionId);

    if (section['legacy'] == true) {
      throw StateError(
        'The original section must remain available for older records.',
      );
    }

    final enrollments = await _db
        .collection('enrollments')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (final doc in enrollments.docs) {
      final data = doc.data();
      if (data['status'] == 'active' && data['sectionId'] == sectionId) {
        throw StateError('Transfer active students before archiving.');
      }
    }

    await _db.collection('courseSections').doc(sectionId).update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
