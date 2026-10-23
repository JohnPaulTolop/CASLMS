/// Uses existing sourceType/sourceId conventions, including legacy notices.
class NotificationTarget {
  const NotificationTarget(this.collection, this.id, this.kind);
  final String collection, id, kind;
  static String text(dynamic value) => (value ?? '').toString().trim();
  static NotificationTarget? fromNotice(Map<String, dynamic> notice) {
    final source = text(notice['sourceType']);
    final type = text(notice['targetType']).isNotEmpty
        ? text(notice['targetType'])
        : text(notice['type']);
    final id = text(notice['sourceId']).isNotEmpty
        ? text(notice['sourceId'])
        : text(notice['targetId']);
    const collections = {
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
    if (collections.containsKey(source) && validId(id)) {
      return NotificationTarget(collections[source]!, id, source);
    }
    // Never infer an assessment/submission ID from a title or display name.
    const legacy = {
      'course': 'course',
      'course_created': 'course',
      'course_enrollment': 'course',
      'activity': 'assessment',
      'activity_created': 'assessment',
      'quiz': 'assessment',
      'quiz_created': 'assessment',
      'assessment': 'assessment',
      'assignment': 'assignment',
      'assignment_created': 'assignment',
      'announcement': 'announcement',
      'announcement_posted': 'announcement',
      'resource': 'moduleResource',
      'message': 'conversation',
    };
    final kind = legacy[type];
    final exact = id.isNotEmpty
        ? id
        : text(
            notice[{
              'course': 'courseId',
              'assessment': 'assessmentId',
              'assignment': 'assignmentId',
              'announcement': 'announcementId',
              'moduleResource': 'resourceId',
              'conversation': 'conversationId',
            }[kind]],
          );
    return kind != null && validId(exact)
        ? NotificationTarget(collections[kind]!, exact, kind)
        : null;
  }

  static bool validId(String id) =>
      id.isNotEmpty && !id.contains('/') && id != '.' && id != '..';
}
