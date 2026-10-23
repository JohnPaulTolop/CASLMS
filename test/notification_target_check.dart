import 'dart:io';

import 'package:caslms/models/notification_target.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  const sources = {
    'course': 'courses',
    'enrollment': 'enrollments',
    'module': 'modules',
    'moduleResource': 'moduleResources',
    'assessment': 'assessments',
    'assignment': 'assignments',
    'announcement': 'announcements',
    'assessmentSubmission': 'assessmentSubmissions',
    'automaticAssessmentGrade': 'assessmentSubmissions',
    'manualAssessmentGrade': 'assessmentSubmissions',
    'assessmentFeedback': 'assessmentSubmissions',
    'googleFormCompliance': 'assessmentSubmissions',
    'assessmentReceived': 'assessmentSubmissions',
    'submission': 'submissions',
    'submissionReceived': 'submissions',
    'semesterGrade': 'semesterGrades',
    'instructorApplication': 'instructorApplications',
    'instructorStatus': 'users',
    'conversation': 'conversations',
    'liveClass': 'liveClasses',
  };
  for (final source in sources.entries) {
    final target = NotificationTarget.fromNotice({
      'sourceType': source.key,
      'sourceId': 'exact-id',
    });
    check(
      target?.collection == source.value && target?.id == 'exact-id',
      'Incorrect ${source.key} destination',
    );
  }
  check(
    NotificationTarget.fromNotice({
          'type': 'quiz_created',
          'assessmentId': 'quiz-1',
        })?.id ==
        'quiz-1',
    'Reliable legacy quiz link',
  );
  check(
    NotificationTarget.fromNotice({'targetType': 'activity', 'targetId': 'a1'})
            ?.collection ==
        'assessments',
    'Explicit target metadata',
  );
  for (final notice in [
    <String, dynamic>{},
    {'type': 'grade', 'title': 'Graded: Biology'},
    {'sourceType': 'assessment', 'sourceId': 'bad/id'},
    {'sourceType': 'unknown', 'sourceId': 'id'},
    {'type': 'quiz', 'title': 'Midterm', 'courseId': 'c1'},
  ]) {
    check(
      NotificationTarget.fromNotice(notice) == null,
      'Ambiguous or unsafe link accepted',
    );
  }
  stdout.writeln(
    'Passed ${sources.length + 7} notification source/legacy/invalid-ID checks.',
  );
}
