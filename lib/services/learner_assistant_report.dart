// Pure reporting logic. No database writes or AI-generated status decisions.
typedef AssistantRow = Map<String, dynamic>;

String assistantText(dynamic value) => (value ?? '').toString().trim();
String _lower(dynamic value) => assistantText(value).toLowerCase();

class LearnerAssistantReport {
  LearnerAssistantReport({
    required this.profile,
    required this.subjects,
    required this.tasks,
    required this.instructorView,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  final AssistantRow profile;
  final List<String> subjects;
  final List<AssistantRow> tasks;
  final bool instructorView;
  final DateTime checkedAt;

  String get scope => instructorView
      ? 'Only this student’s active enrollments in your classes are included.'
      : 'Only your active subject enrollments are included.';

  Map<String, dynamic> toContext() => {
    'scope': scope,
    'checkedAt': checkedAt.toIso8601String(),
    'student': profile,
    'registeredSubjects': subjects,
    'requirements': tasks,
    'limitations':
        'Published assessments, assignments, and quizzes only. '
        'No registrar clearance checklist is stored here. '
        'Submitted work is not necessarily approved. Graded does not imply passed.',
  };

  String describe(String question) {
    final q = question.toLowerCase();
    final missing =
        q.contains('missing') ||
        q.contains('incomplete') ||
        q.contains('not submitted');
    final approved = q.contains('approved') || q.contains('complied');
    final pending = q.contains('pending') || q.contains('submitted');
    final subjectsOnly =
        q.contains('subject') ||
        q.contains('enroll') ||
        q.contains('registered');
    final detailsOnly = q.contains('detail') || q.contains('profile');
    final out = StringBuffer()
      ..writeln('${profile['name']} · ${profile['campusId']}')
      ..writeln(scope);
    if (detailsOnly) {
      for (final key in ['email', 'department', 'program', 'accountStatus']) {
        out.writeln('$key: ${profile[key]}');
      }
    }
    if (subjectsOnly || detailsOnly || (!missing && !approved && !pending)) {
      out.writeln('\nRegistered subjects:');
      if (subjects.isEmpty) out.writeln('No active subjects in this scope.');
      for (final subject in subjects) {
        out.writeln('• $subject');
      }
    }
    if (subjectsOnly || detailsOnly) return out.toString().trim();
    final selected = tasks.where((task) {
      final status = task['status'];
      if (missing)
        return [
          'Missing',
          'Not complied',
          'In progress',
          'Awaiting instructor verification',
          'Unverified record',
        ].contains(status);
      if (approved) return status == 'Approved / complied';
      if (pending)
        return status == 'Submitted — awaiting grade' ||
            status == 'Awaiting instructor verification';
      return true;
    }).toList();
    out.writeln(
      '\n${missing
          ? 'Outstanding requirements'
          : approved
          ? 'Approved requirements'
          : pending
          ? 'Pending review'
          : 'Requirements'}: ${selected.length}',
    );
    for (final task in selected) {
      out.writeln('• ${task['subject']} / ${task['title']}: ${task['status']}');
    }
    if (selected.isEmpty)
      out.writeln('No matching published requirements found.');
    out.writeln(
      '\nSubmitted and graded work do not automatically mean approved or passed.',
    );
    return out.toString().trim();
  }
}

/// Select the latest record deterministically, including revocations.
AssistantRow? latestAssistantSubmission(List<AssistantRow> rows) {
  if (rows.isEmpty) return null;
  DateTime date(AssistantRow row) {
    for (final key in [
      'updatedAt',
      'verifiedAt',
      'gradedAt',
      'submittedAt',
      'completedAt',
      'startedAt',
    ]) {
      final value = row[key];
      if (value is DateTime) return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  final sorted = [...rows]
    ..sort((a, b) {
      final order = date(b).compareTo(date(a));
      return order != 0
          ? order
          : assistantText(a['id']).compareTo(assistantText(b['id']));
    });
  return sorted.first;
}

String assistantRequirementStatus(
  AssistantRow task,
  AssistantRow? result,
  String source,
) {
  final googleForm =
      _lower(task['submissionMethod']) == 'google_form' ||
      _lower(result?['submissionType']) == 'google_form';
  if (result == null)
    return googleForm ? 'Awaiting instructor verification' : 'Missing';
  final status = _lower(result['status']);
  final compliance = _lower(result['complianceStatus']);
  if (status == 'not_complied' ||
      compliance == 'not_complied' ||
      status == 'rejected') {
    return 'Not complied';
  }
  if (googleForm) {
    return compliance == 'complied' &&
            _lower(result['submissionSource']) == 'instructor_verification' &&
            assistantText(result['verifiedBy']).isNotEmpty &&
            result['verifiedAt'] != null &&
            ['submitted', 'graded'].contains(status)
        ? 'Approved / complied'
        : 'Awaiting instructor verification';
  }
  if (status == 'in_progress') return 'In progress';
  if (['graded', 'completed', 'submitted'].contains(status) &&
      result['score'] is num &&
      (status == 'graded' || source == 'quiz'))
    return 'Graded';
  if (!['submitted', 'graded'].contains(status) ||
      result['submittedAt'] == null) {
    return 'Unverified record';
  }
  if (source == 'assignment') {
    return assistantText(result['answerText']).isNotEmpty ||
            assistantText(result['fileUrl']).isNotEmpty
        ? 'Submitted — awaiting grade'
        : 'Unverified record';
  }
  final kind = _lower(result['submissionType']);
  if (kind == 'github_repository') {
    final uri = Uri.tryParse(assistantText(result['repositoryUrl']));
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'github.com' &&
        uri.pathSegments.where((p) => p.isNotEmpty).length >= 2) {
      return 'Submitted — awaiting grade';
    }
  }
  if (['zip_file', 'technical_document'].contains(kind) &&
      _lower(result['storageProvider']) == 'supabase' &&
      result['storageBucket'] == 'caslms-assessment-submissions' &&
      assistantText(result['storagePath']).isNotEmpty &&
      assistantText(result['fileName']).isNotEmpty &&
      result['sizeBytes'] is num &&
      (result['sizeBytes'] as num) > 0 &&
      (result['sizeBytes'] as num) <= 20 * 1024 * 1024) {
    return 'Submitted — awaiting grade';
  }
  return 'Unverified record';
}
