import 'dart:async';

import 'ai_router_service.dart';

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAssistantService {
  AdminAssistantService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GenerativeModel? model,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _model =
           model ??
           FirebaseAI.googleAI().generativeModel(
             model: 'gemini-3.7-flash',
             generationConfig: GenerationConfig(
               maxOutputTokens: 600,
               thinkingConfig: ThinkingConfig.withThinkingLevel(
                 ThinkingLevel.low,
               ),
             ),
           );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GenerativeModel _model;

  _AdminAssistantData? _cachedData;
  DateTime? _cacheCreatedAt;

  static const Duration _cacheDuration = Duration(minutes: 2);

  Future<String> ask(String question) async {
    final String cleanQuestion = question.trim();

    if (cleanQuestion.isEmpty) {
      throw const AdminAssistantException('Enter a question first.');
    }

    await _requireAdministrator();

    final _AdminAssistantData data = await _loadData();
    final String? recordAnswer = data.answerFromRecords(cleanQuestion);

    if (recordAnswer != null) {
      return recordAnswer;
    }

    return _answerWithAi(question: cleanQuestion, data: data);
  }

  void clearCache() {
    _cachedData = null;
    _cacheCreatedAt = null;
  }

  Future<void> _requireAdministrator() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw const AdminAssistantException(
        'Your session has expired. Sign in again.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> profileDocument =
        await _firestore.collection('users').doc(user.uid).get();
    final Map<String, dynamic>? profile = profileDocument.data();
    final String role = _text(profile?['role']).toLowerCase();
    final String status = _text(profile?['status']).toLowerCase();

    if (role != 'admin' || status != 'active') {
      throw const AdminAssistantException(
        'Only active CASLMS administrators can use this assistant.',
      );
    }
  }

  Future<_AdminAssistantData> _loadData() async {
    final DateTime now = DateTime.now();
    final DateTime? createdAt = _cacheCreatedAt;

    if (_cachedData != null &&
        createdAt != null &&
        now.difference(createdAt) < _cacheDuration) {
      return _cachedData!;
    }

    try {
      final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
          await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
            _firestore
                .collection('users')
                .where('role', isEqualTo: 'student')
                .limit(750)
                .get(),
            _firestore.collection('courses').limit(500).get(),
            _firestore
                .collection('enrollments')
                .where('status', isEqualTo: 'active')
                .limit(5000)
                .get(),
            _firestore.collection('instructorApplications').limit(750).get(),
            _firestore
                .collection('assessments')
                .where('status', isEqualTo: 'published')
                .limit(5000)
                .get(),
            _firestore.collection('assessmentSubmissions').limit(8000).get(),
          ]);

      final _AdminAssistantData result = _AdminAssistantData(
        students: _documents(snapshots[0]),
        courses: _documents(snapshots[1]),
        enrollments: _documents(snapshots[2]),
        instructorApplications: _documents(snapshots[3]),
        assessments: _documents(snapshots[4]),
        assessmentSubmissions: _documents(snapshots[5]),
      );

      _cachedData = result;
      _cacheCreatedAt = now;

      return result;
    } on FirebaseException catch (error) {
      throw AdminAssistantException(
        error.code == 'permission-denied'
            ? 'The assistant does not have permission to read the required records.'
            : 'Unable to load CASLMS records right now. Please try again.',
      );
    }
  }

  List<Map<String, dynamic>> _documents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              <String, dynamic>{...document.data(), 'id': document.id},
        )
        .toList(growable: false);
  }

  Future<String> _answerWithAi({
    required String question,
    required _AdminAssistantData data,
  }) async {
    final Map<String, dynamic> context = data.aiContext(question);
    final String encodedContext = jsonEncode(context);

    final String prompt =
        '''
You are the CASLMS administrative records assistant.

Answer the administrator's question using ONLY the supplied CASLMS record context.
Never invent a student, subject, approval, requirement, grade, status, or personal detail.
If the records do not contain enough information, clearly say what is unavailable.
Treat a subject as registered only when its enrollment status is active.
Treat an assessment requirement as completed only when the supplied record marks it completed.
Do not expose internal document IDs, authentication email aliases, tokens, or security configuration.
Use concise plain text with short headings and bullet points when useful.
The context can be incomplete when the system has more records than the safety limit; mention that when relevant.

ADMIN QUESTION:
$question

CASLMS RECORD CONTEXT:
$encodedContext
''';

    try {
      if (AiRouterService.enabled) {
        return await AiRouterService().complete(
          task: 'records_summary',
          messages: [
            {'role': 'user', 'content': prompt},
          ],
        );
      }
      final GenerateContentResponse response = await _model
          .generateContent(<Content>[Content.text(prompt)])
          .timeout(const Duration(seconds: 35));
      if (response.candidates.any(
        (candidate) => candidate.finishReason == FinishReason.maxTokens,
      )) {
        throw const AdminAssistantException(
          'The response reached its length limit. Ask a narrower question.',
        );
      }
      final String answer = (response.text ?? '').trim();

      if (answer.isEmpty) {
        throw const AdminAssistantException(
          'The assistant returned an empty response. Please try again.',
        );
      }

      return answer;
    } on AdminAssistantException {
      rethrow;
    } catch (_) {
      throw const AdminAssistantException(
        'The AI assistant is temporarily unavailable. Record lookup questions such as student details, registered subjects, approved applications, and missing requirements still work without AI.',
      );
    }
  }
}

class _AdminAssistantData {
  _AdminAssistantData({
    required this.students,
    required this.courses,
    required this.enrollments,
    required this.instructorApplications,
    required this.assessments,
    required this.assessmentSubmissions,
  }) : coursesById = <String, Map<String, dynamic>>{
         for (final Map<String, dynamic> course in courses)
           _text(course['id']): course,
       },
       submissionsByStudentAndAssessment = _buildSubmissionIndex(
         assessmentSubmissions,
       );

  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> courses;
  final List<Map<String, dynamic>> enrollments;
  final List<Map<String, dynamic>> instructorApplications;
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> assessmentSubmissions;

  final Map<String, Map<String, dynamic>> coursesById;
  final Map<String, Map<String, dynamic>> submissionsByStudentAndAssessment;

  static Map<String, Map<String, dynamic>> _buildSubmissionIndex(
    List<Map<String, dynamic>> submissions,
  ) {
    final Map<String, Map<String, dynamic>> result =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> submission in submissions) {
      final String studentId = _text(submission['studentId']);
      final String assessmentId = _text(submission['assessmentId']);

      if (studentId.isEmpty || assessmentId.isEmpty) {
        continue;
      }

      result['${studentId}_$assessmentId'] = submission;
    }

    return result;
  }

  String? answerFromRecords(String question) {
    final String normalized = question.toLowerCase();
    final List<Map<String, dynamic>> matches = _matchingStudents(question);

    final bool asksMissing =
        normalized.contains('missing') ||
        normalized.contains('incomplete') ||
        normalized.contains('not submitted') ||
        normalized.contains('pending requirement');
    final bool asksSubject =
        normalized.contains('subject') ||
        normalized.contains('course') ||
        normalized.contains('enrolled') ||
        normalized.contains('registered');
    final bool asksApproved =
        normalized.contains('approved') ||
        normalized.contains('complied') ||
        normalized.contains('completed requirement');
    final bool asksOverview =
        normalized.contains('overview') ||
        normalized.contains('summary') ||
        normalized.contains('how many') ||
        normalized.contains('statistics');

    if (asksMissing) {
      return _missingRequirementsAnswer(matches);
    }

    if (asksSubject) {
      return _registeredSubjectsAnswer(matches);
    }

    if (asksApproved) {
      return _approvedAnswer(
        matches,
        instructorOnly:
            normalized.contains('instructor') ||
            normalized.contains('faculty') ||
            normalized.contains('application'),
      );
    }

    if (matches.isNotEmpty) {
      return _studentDetailsAnswer(matches);
    }

    if (asksOverview) {
      return _overviewAnswer();
    }

    return null;
  }

  List<Map<String, dynamic>> _matchingStudents(String question) {
    final String normalized = question.toLowerCase();
    final Set<String> resultIds = <String>{};
    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> student in students) {
      final String id = _text(student['id']);
      final String campusId = _text(student['universityId']).toLowerCase();
      final String name = _text(student['name']).toLowerCase();

      final List<String> meaningfulNameParts = name
          .split(RegExp(r'\s+'))
          .where((String part) => part.length >= 3)
          .toList(growable: false);

      final bool campusIdMatches =
          campusId.isNotEmpty && normalized.contains(campusId);
      final bool fullNameMatches =
          name.length >= 3 && normalized.contains(name);
      final bool namePartsMatch =
          meaningfulNameParts.length >= 2 &&
          meaningfulNameParts.every(normalized.contains);

      if ((campusIdMatches || fullNameMatches || namePartsMatch) &&
          resultIds.add(id)) {
        results.add(student);
      }
    }

    return results;
  }

  List<Map<String, dynamic>> _studentEnrollments(String studentId) {
    return enrollments
        .where(
          (Map<String, dynamic> enrollment) =>
              _text(enrollment['studentId']) == studentId &&
              _text(enrollment['status']).toLowerCase() == 'active',
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _studentSubjects(String studentId) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> enrollment in _studentEnrollments(
      studentId,
    )) {
      final String courseId = _text(enrollment['courseId']);
      final Map<String, dynamic>? course = coursesById[courseId];

      if (course != null) {
        result.add(course);
      }
    }

    result.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          _courseLabel(a).compareTo(_courseLabel(b)),
    );

    return result;
  }

  _StudentRequirementReport _reportFor(Map<String, dynamic> student) {
    final String studentId = _text(student['id']);
    final List<Map<String, dynamic>> subjects = _studentSubjects(studentId);
    final Set<String> courseIds = subjects
        .map((Map<String, dynamic> course) => _text(course['id']))
        .where((String id) => id.isNotEmpty)
        .toSet();

    final List<String> missingProfileFields = <String>[];
    final Map<String, dynamic> requiredProfileFields = <String, dynamic>{
      'full name': student['name'],
      'registered Gmail': student['email'],
      'campus ID': student['universityId'],
      'department': student['department'],
      'program': student['course'],
    };

    requiredProfileFields.forEach((String label, dynamic value) {
      if (_text(value).isEmpty) {
        missingProfileFields.add(label);
      }
    });

    final List<String> missingAssessments = <String>[];
    final List<String> completedAssessments = <String>[];

    for (final Map<String, dynamic> assessment in assessments) {
      final String courseId = _text(assessment['courseId']);

      if (!courseIds.contains(courseId)) {
        continue;
      }

      final String assessmentId = _text(assessment['id']);
      final Map<String, dynamic>? submission =
          submissionsByStudentAndAssessment['${studentId}_$assessmentId'];
      final String label = _assessmentLabel(assessment);

      if (_submissionIsCompleted(submission)) {
        completedAssessments.add(label);
      } else {
        missingAssessments.add(label);
      }
    }

    return _StudentRequirementReport(
      student: student,
      subjects: subjects,
      missingProfileFields: missingProfileFields,
      missingAssessments: missingAssessments,
      completedAssessments: completedAssessments,
    );
  }

  bool _submissionIsCompleted(Map<String, dynamic>? submission) {
    if (submission == null) {
      return false;
    }

    final String status = _text(submission['status']).toLowerCase();
    final String complianceStatus = _text(submission['complianceStatus'])
        .toLowerCase();

    const Set<String> completedStatuses = <String>{
      'submitted',
      'graded',
      'completed',
      'approved',
      'compliance_approved',
    };
    const Set<String> completedComplianceStatuses = <String>{
      'complied',
      'approved',
      'verified',
    };

    return completedStatuses.contains(status) ||
        completedComplianceStatuses.contains(complianceStatus);
  }

  String _missingRequirementsAnswer(List<Map<String, dynamic>> matches) {
    final List<Map<String, dynamic>> source = matches.isEmpty
        ? students
        : matches;
    final List<_StudentRequirementReport> reports = source
        .map(_reportFor)
        .where((_StudentRequirementReport report) => report.hasMissing)
        .toList(growable: false);

    if (reports.isEmpty) {
      return matches.isEmpty
          ? 'No missing student profile or published-assessment requirements were found in the available records.'
          : 'No missing profile or published-assessment requirements were found for the selected student.';
    }

    final StringBuffer answer = StringBuffer()
      ..writeln('Missing requirements (${reports.length} students)');

    for (final _StudentRequirementReport report in reports.take(50)) {
      answer
        ..writeln()
        ..writeln('• ${report.studentLabel}');

      if (report.missingProfileFields.isNotEmpty) {
        answer.writeln('  Profile: ${report.missingProfileFields.join(', ')}');
      }

      if (report.missingAssessments.isNotEmpty) {
        answer.writeln(
          '  Assessments: ${report.missingAssessments.join('; ')}',
        );
      }
    }

    if (reports.length > 50) {
      answer.writeln('\nShowing the first 50 matching students.');
    }

    return answer.toString().trim();
  }

  String _registeredSubjectsAnswer(List<Map<String, dynamic>> matches) {
    final List<Map<String, dynamic>> source = matches.isEmpty
        ? students
        : matches;
    final StringBuffer answer = StringBuffer()..writeln('Registered subjects');

    int shown = 0;

    for (final Map<String, dynamic> student in source) {
      if (shown >= 80) {
        break;
      }

      final _StudentRequirementReport report = _reportFor(student);
      final String subjectText = report.subjects.isEmpty
          ? 'No active subjects'
          : report.subjects.map(_courseLabel).join('; ');

      answer
        ..writeln()
        ..writeln('• ${report.studentLabel}')
        ..writeln('  $subjectText');
      shown++;
    }

    if (source.length > shown) {
      answer.writeln(
        '\nShowing the first $shown of ${source.length} students.',
      );
    }

    return answer.toString().trim();
  }

  String _approvedAnswer(
    List<Map<String, dynamic>> matches, {
    required bool instructorOnly,
  }) {
    final List<Map<String, dynamic>> approvedApplications =
        instructorApplications
            .where(
              (Map<String, dynamic> application) =>
                  _text(application['status']).toLowerCase() == 'approved',
            )
            .toList(growable: false);

    if (instructorOnly) {
      if (approvedApplications.isEmpty) {
        return 'No approved instructor applications were found.';
      }

      final StringBuffer answer = StringBuffer()
        ..writeln(
          'Approved instructor applications (${approvedApplications.length})',
        );

      for (final Map<String, dynamic> application in approvedApplications.take(
        80,
      )) {
        answer.writeln(
          '• ${_valueOr(application['name'], 'Unnamed instructor')} — '
          '${_valueOr(application['universityId'], 'No faculty ID')} — '
          '${_valueOr(application['department'], 'No department')}',
        );
      }

      return answer.toString().trim();
    }

    final List<Map<String, dynamic>> source = matches.isEmpty
        ? students
        : matches;
    final StringBuffer answer = StringBuffer()
      ..writeln('Approved/completed requirements');

    int shown = 0;

    for (final Map<String, dynamic> student in source) {
      final _StudentRequirementReport report = _reportFor(student);

      if (report.completedAssessments.isEmpty) {
        continue;
      }

      answer
        ..writeln()
        ..writeln('• ${report.studentLabel}')
        ..writeln('  ${report.completedAssessments.join('; ')}');
      shown++;

      if (shown >= 50) {
        break;
      }
    }

    if (shown == 0) {
      answer.writeln(
        '\nNo completed published-assessment requirements were found.',
      );
    }

    answer.writeln(
      '\nApproved instructor applications: ${approvedApplications.length}',
    );

    return answer.toString().trim();
  }

  String _studentDetailsAnswer(List<Map<String, dynamic>> matches) {
    final StringBuffer answer = StringBuffer()..writeln('Student record');

    for (final Map<String, dynamic> student in matches.take(10)) {
      final _StudentRequirementReport report = _reportFor(student);

      answer
        ..writeln()
        ..writeln('• ${report.studentLabel}')
        ..writeln('  Gmail: ${_valueOr(student['email'], 'Not provided')}')
        ..writeln(
          '  Department: ${_valueOr(student['department'], 'Not provided')}',
        )
        ..writeln('  Program: ${_valueOr(student['course'], 'Not provided')}')
        ..writeln('  Account: ${_valueOr(student['status'], 'Unknown')}')
        ..writeln(
          '  Subjects: ${report.subjects.isEmpty ? 'None' : report.subjects.map(_courseLabel).join('; ')}',
        )
        ..writeln(
          '  Missing requirements: ${report.hasMissing ? report.missingSummary : 'None found'}',
        );
    }

    return answer.toString().trim();
  }

  String _overviewAnswer() {
    final int approvedApplications = instructorApplications
        .where(
          (Map<String, dynamic> application) =>
              _text(application['status']).toLowerCase() == 'approved',
        )
        .length;
    final int pendingApplications = instructorApplications
        .where(
          (Map<String, dynamic> application) =>
              _text(application['status']).toLowerCase() == 'pending',
        )
        .length;
    final int studentsWithMissingRequirements = students
        .map(_reportFor)
        .where((_StudentRequirementReport report) => report.hasMissing)
        .length;

    return '''
CASLMS records overview

• Students: ${students.length}
• Active subject enrollments: ${enrollments.length}
• Subjects/courses: ${courses.length}
• Published assessments: ${assessments.length}
• Students with missing profile or assessment requirements: $studentsWithMissingRequirements
• Approved instructor applications: $approvedApplications
• Pending instructor applications: $pendingApplications
'''
        .trim();
  }

  Map<String, dynamic> aiContext(String question) {
    final List<Map<String, dynamic>> matches = _matchingStudents(question);
    final List<Map<String, dynamic>> selectedStudents = matches.isNotEmpty
        ? matches.take(20).toList()
        : students.take(80).toList();

    return <String, dynamic>{
      'recordLimits': <String, dynamic>{
        'studentRecordsIncluded': selectedStudents.length,
        'totalStudentsLoaded': students.length,
        'studentContextWasFilteredByQuestion': matches.isNotEmpty,
      },
      'summary': <String, dynamic>{
        'students': students.length,
        'courses': courses.length,
        'activeEnrollments': enrollments.length,
        'publishedAssessments': assessments.length,
        'instructorApplications': instructorApplications.length,
      },
      'students': selectedStudents.map((Map<String, dynamic> student) {
        final _StudentRequirementReport report = _reportFor(student);

        return <String, dynamic>{
          'name': _valueOr(student['name'], 'Not provided'),
          'campusId': _valueOr(student['universityId'], 'Not provided'),
          'department': _valueOr(student['department'], 'Not provided'),
          'program': _valueOr(student['course'], 'Not provided'),
          'accountStatus': _valueOr(student['status'], 'Unknown'),
          'registeredSubjects': report.subjects.map(_courseLabel).toList(),
          'missingProfileRequirements': report.missingProfileFields,
          'missingAssessmentRequirements': report.missingAssessments,
          'completedAssessmentRequirements': report.completedAssessments,
        };
      }).toList(),
      'instructorApplicationSummary': <String, int>{
        for (final String status in <String>['pending', 'approved', 'rejected'])
          status: instructorApplications
              .where(
                (Map<String, dynamic> application) =>
                    _text(application['status']).toLowerCase() == status,
              )
              .length,
      },
    };
  }

  static String _courseLabel(Map<String, dynamic> course) {
    final String code = _text(course['code']).isNotEmpty
        ? _text(course['code'])
        : _text(course['courseCode']);
    final String title = _valueOr(course['title'], 'Untitled subject');
    final String semester = _text(course['semester']);
    final String academicYear = _text(course['academicYear']);
    final String term = <String>[
      semester,
      academicYear,
    ].where((String value) => value.isNotEmpty).join(', ');

    return <String>[
      if (code.isNotEmpty) code,
      title,
      if (term.isNotEmpty) term,
    ].join(' — ');
  }

  String _assessmentLabel(Map<String, dynamic> assessment) {
    final String title = _valueOr(assessment['title'], 'Untitled assessment');
    final Map<String, dynamic>? course =
        coursesById[_text(assessment['courseId'])];
    final String courseText = course == null
        ? 'Unknown subject'
        : _courseLabel(course);

    return '$title ($courseText)';
  }
}

class _StudentRequirementReport {
  const _StudentRequirementReport({
    required this.student,
    required this.subjects,
    required this.missingProfileFields,
    required this.missingAssessments,
    required this.completedAssessments,
  });

  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> subjects;
  final List<String> missingProfileFields;
  final List<String> missingAssessments;
  final List<String> completedAssessments;

  bool get hasMissing =>
      missingProfileFields.isNotEmpty || missingAssessments.isNotEmpty;

  String get studentLabel {
    return '${_valueOr(student['name'], 'Unnamed student')} '
        '(${_valueOr(student['universityId'], 'No campus ID')})';
  }

  String get missingSummary {
    return <String>[
      if (missingProfileFields.isNotEmpty)
        'Profile: ${missingProfileFields.join(', ')}',
      if (missingAssessments.isNotEmpty)
        'Assessments: ${missingAssessments.join('; ')}',
    ].join(' | ');
  }
}

String _text(dynamic value) => (value ?? '').toString().trim();

String _valueOr(dynamic value, String fallback) {
  final String text = _text(value);
  return text.isEmpty ? fallback : text;
}

class AdminAssistantException implements Exception {
  const AdminAssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}
