import 'dart:convert';
import 'dart:io';

import 'package:caslms/config/academic_catalog.dart';
import 'package:caslms/services/enrollment_membership.dart';
import 'package:caslms/services/progress_calculator.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final backend = jsonDecode(
    File('supabase/functions/_shared/academic_catalog.json').readAsStringSync(),
  );
  check(
    jsonEncode(backend) == jsonEncode(AcademicCatalog.programs),
    'Client/server catalog mismatch',
  );
  check(
    !AcademicCatalog.contains('College of Arts and Sciences (CAS)', 'BSN'),
    'Stale program allowed after college change',
  );
  final counts = EnrollmentMembership.counts([
    {'studentId': 'legacy', 'status': 'active'},
    {'studentId': 'new', 'sectionId': 'A', 'status': 'active'},
    {'studentId': 'new', 'sectionId': 'A', 'status': 'active'},
    {'studentId': 'removed', 'sectionId': 'A', 'status': 'inactive'},
  ], 'ORIGINAL');
  check(
    counts['ORIGINAL'] == 1 && counts['A'] == 1,
    'Section count double-counts or loses legacy membership',
  );
  check(
    EnrollmentMembership.sectionId({'sectionId': 'B'}, 'ORIGINAL') == 'B',
    'Transfer ignored',
  );
  for (final score in [0, 17.5, 20]) {
    final result = ProgressCalculator.course(
      course: {'id': 'course'},
      modules: [
        {'id': 'module', 'courseId': 'course', 'status': 'published'},
      ],
      assessments: [
        {
          'id': 'form',
          'courseId': 'course',
          'moduleId': 'module',
          'status': 'published',
          'assessmentType': 'quiz',
          'deliveryType': 'external_link',
          'totalPoints': 20,
        },
      ],
      assignments: [],
      quizzes: [],
      assignmentSubmissions: [],
      quizAttempts: [],
      assessmentSubmissions: [
        {
          'assessmentId': 'form',
          'courseId': 'course',
          'studentId': 'student',
          'status': 'graded',
          'score': score,
          'totalPoints': 20,
          'gradingMode': 'manual',
          'submissionType': 'google_form',
          'submissionSource': 'instructor_verification',
          'complianceStatus': 'complied',
          'verifiedBy': 'teacher',
          'verifiedAt': DateTime.now(),
          'submittedAt': DateTime.now(),
        },
      ],
    );
    check(
      result['quizEarnedPoints'] == score &&
          result['quizAvailablePoints'] == 20 &&
          result['gradedQuizzes'] == 1,
      'Manual Google Forms grade does not reach gradebook',
    );
  }
  stdout.writeln(
    'Passed: catalog parity, dependent choices, section counts/transfers, and manual gradebook scores (including zero).',
  );
}
