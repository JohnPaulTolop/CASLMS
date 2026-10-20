class ActivityScore {
  const ActivityScore({
    required this.title,
    required this.courseId,
    required this.subject,
    required this.type,
    required this.submittedAt,
    required this.totalPoints,
    required this.pointsEarned,
    required this.percentage,
    required this.status,
    required this.late,
    required this.needsInstructorReview,
  });
  factory ActivityScore.fromJson(Map<String, dynamic> json) => ActivityScore(
    title: json['title'] as String,
    courseId: json['courseId'] as String,
    subject: json['subject'] as String,
    type: json['activityType'] as String,
    submittedAt: DateTime.parse(json['submittedAt'] as String),
    totalPoints: (json['totalPoints'] as num?)?.toDouble(),
    pointsEarned: (json['pointsEarned'] as num?)?.toDouble(),
    percentage: (json['percentage'] as num?)?.toDouble(),
    status: json['status'] as String,
    late: json['late'] == true,
    needsInstructorReview: json['needsInstructorReview'] == true,
  );
  final String title, courseId, subject, type, status;
  final DateTime submittedAt;
  final double? totalPoints, pointsEarned, percentage;
  final bool late, needsInstructorReview;
}

/// This model intentionally has no grade/percentage/ciphertext field.
/// A normal subject-list response cannot populate a hidden grade value.
class PostedSubject {
  const PostedSubject({
    required this.courseId,
    required this.title,
    required this.code,
    required this.termId,
    required this.posted,
    required this.revision,
  });
  factory PostedSubject.fromJson(Map<String, dynamic> json) => PostedSubject(
    courseId: json['courseId'] as String,
    title: json['courseTitle'] as String,
    code: json['courseCode'] as String,
    termId: json['termId'] as String,
    posted: json['posted'] == true,
    revision: (json['revision'] as num?)?.toInt() ?? 0,
  );
  final String courseId, title, code, termId;
  final bool posted;
  final int revision;
}

class RevealedGrade {
  const RevealedGrade({
    required this.grade,
    required this.result,
    required this.description,
  });
  factory RevealedGrade.fromJson(Map<String, dynamic> json) => RevealedGrade(
    grade: json['grade'] as String,
    result: json['result'] as String,
    description: (json['description'] ?? '') as String,
  );
  final String grade, result, description;
}
