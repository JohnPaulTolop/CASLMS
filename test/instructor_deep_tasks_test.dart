// Rendering fixtures keep production records and services untouched.
// ignore_for_file: subtype_of_sealed_class
import 'dart:io';

import 'package:caslms/services/instructor_workspace_context.dart';

import 'dart:ui' as ui;

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_ai_quiz_editor_page.dart';
import 'package:caslms/screens/instructor/instructor_ai_quiz_generator_page.dart';
import 'package:caslms/screens/instructor/instructor_assessment_grading_page.dart';
import 'package:caslms/screens/instructor/instructor_quiz_results_page.dart';
import 'package:caslms/screens/instructor/instructor_semester_grades_page.dart';
import 'package:caslms/services/assessment_submission_service.dart';
import 'package:caslms/services/course_section_service.dart';
import 'package:caslms/services/quiz_service.dart';
import 'package:caslms/services/semester_grades_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'teacher';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _Db extends Fake implements FirebaseFirestore {
  _Db({this.role = 'instructor'});
  final String role;
  Map<String, dynamic>? updated;
  Map<String, dynamic> row(String path) => switch (path) {
    'users/teacher' => {'role': role, 'status': 'active'},
    'courses/course' => {
      'code': 'IT302',
      'title': 'Mobile development',
      'instructorId': 'teacher',
      'status': 'active',
    },
    'modules/module' => {'title': 'Chapter 1', 'courseId': 'course'},
    'assessments/quiz' => {
      'title': 'Data basics',
      'instructions': 'Choose the best answer.',
      'assessmentType': 'quiz',
      'deliveryType': 'ai_generated',
      'courseId': 'course',
      'moduleId': 'module',
      'createdBy': 'teacher',
      'status': 'draft',
      'questions': [
        {
          'question': 'Which option is correct?',
          'options': ['One', 'Two', 'Three', 'Four'],
          'correctAnswerIndex': 1,
          'points': 2,
          'explanation': 'Two is correct.',
        },
      ],
    },
    'assessments/assignment' => {
      'title': 'Practice activity',
      'assessmentType': 'assignment',
      'courseId': 'course',
      'moduleId': 'module',
      'deliveryType': 'artifact',
      'totalPoints': 20,
    },
    _ => {},
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Reference(db, '$path/$id');
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #where ? this : super.noSuchMethod(i);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(
    path == 'courses' ? [_Row('course', db.row('courses/course'))] : [],
  );
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Row(path.split('/').last, db.row(path));
  @override
  Future<void> update(Map<Object, Object?> data) async =>
      db.updated = data.map((key, value) => MapEntry(key.toString(), value));
}

class _Row extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Row(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  bool get exists => row.isNotEmpty;
  @override
  Map<String, dynamic> data() => row;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Quizzes extends Fake implements QuizService {
  @override
  Future<List<Map<String, dynamic>>> getInstructorQuizResults() async => [
    for (final name in ['Alex', 'Jamie'])
      {
        'studentName': '$name Student',
        'studentEmail': '$name@example.edu',
        'quizTitle': 'Data basics',
        'courseCode': 'IT302',
        'courseTitle': 'Mobile development',
        'score': name == 'Alex' ? 8 : 3,
        'totalPoints': 10,
        'passingScore': 5,
        'passed': name == 'Alex',
      },
  ];
}

class _Submissions extends Fake implements AssessmentSubmissionService {
  String? feedback;
  @override
  Future<List<Map<String, dynamic>>> getAssessmentSubmissions({
    required String assessmentId,
  }) async => [
    {
      'id': 'submission',
      'studentId': 'student',
      'studentName': 'Alex Student',
      'studentEmail': 'alex@example.edu',
      'status': 'submitted',
      'assessmentId': assessmentId,
      'score': 15,
      'rating': 'Good',
      'feedback': '',
    },
  ];
  @override
  Future<void> saveFeedback({
    required String submissionId,
    required String feedback,
  }) async {
    expect(submissionId, 'submission');
    this.feedback = feedback;
  }
}

class _Sections extends Fake implements CourseSectionService {
  @override
  Future<List<Map<String, dynamic>>> getSections(String courseId) async => [
    {
      'id': 'section',
      'courseId': 'course',
      'name': 'BSIT-4A',
      'status': 'active',
    },
  ];
}

class _Grades implements GradebookApi {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(action);
    if (action == 'finalize') return {'revision': 2, 'postedCount': 1};
    return {
      'previewHash': 'preview',
      'revision': 1,
      'courseTitle': 'Mobile development',
      'sectionName': 'BSIT-4A',
      'termLabel': 'First Semester',
      'grades': [
        {
          'studentId': 'student',
          'studentName': 'Alex Student',
          'campusId': '20260001',
          'rawPercentage': 80,
          'percentage': 90,
          'grade': '1.5',
          'result': 'Passed',
          'issues': [],
        },
      ],
    };
  }
}

Future<void> _mount(
  WidgetTester t,
  Widget page, {
  double width = 390,
  bool dark = false,
  double scale = 1,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 1000);
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      initialRoute: '/task',
      routes: {
        '/': (_) => const Scaffold(body: Text('Course workspace')),
        '/task': (_) => RepaintBoundary(
          key: const ValueKey('deep-task-preview'),
          child: page,
        ),
      },
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder f) async {
  for (var attempt = 0; attempt < 12 && f.evaluate().isEmpty; attempt++) {
    await t.drag(find.byType(NestedScrollView), const Offset(0, -350));
    await t.pumpAndSettle();
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> _capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_TASKS')) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('deep-task-preview')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/task-previews/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => InstructorWorkspaceContext.instance.bindUser(null));
  testWidgets('Main grading inherits the validated course and section', (
    t,
  ) async {
    final selection = InstructorWorkspaceContext.instance;
    final revision = selection.beginCourse('teacher', 'course');
    selection.commitSections(revision, 'teacher', 'course', [
      {'id': 'section', 'courseId': 'course', 'status': 'active'},
    ], requested: 'section');
    await _mount(
      t,
      InstructorSemesterGradesScreen(
        api: _Grades(),
        firestore: _Db(),
        auth: _Auth(),
        sectionService: _Sections(),
      ),
    );
    expect(find.text('BSIT-4A'), findsOneWidget);
    expect(selection.sectionId, 'section');
    expect(t.takeException(), isNull);
  });
  setUpAll(() async {
    await (FontLoader(
      'Ahem',
    )..addFont(rootBundle.load('assets/fonts/Roboto-regular.ttf'))).load();
    final font = FontLoader('Roboto');
    for (final face in ['regular', 'medium', 'bold', 'black']) {
      font.addFont(rootBundle.load('assets/fonts/Roboto-$face.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        for (final kind in [
          'quiz',
          'submissions',
          'results',
          'semester',
          'generator',
        ]) {
          testWidgets(
            'Deeper instructor task $kind $width dark $dark text $scale',
            (t) async {
              final db = _Db(), auth = _Auth();
              final page = switch (kind) {
                'quiz' => InstructorAiQuizEditorScreen(
                  assessmentId: 'quiz',
                  courseId: 'course',
                  moduleId: 'module',
                  firestore: db,
                  auth: auth,
                ),
                'submissions' => InstructorAssessmentGradingScreen(
                  assessmentId: 'assignment',
                  firestore: db,
                  submissionService: _Submissions(),
                ),
                'results' => InstructorQuizResultsScreen(
                  quizService: _Quizzes(),
                ),
                'semester' => InstructorSemesterGradesScreen(
                  courseId: 'course',
                  sectionId: 'section',
                  api: _Grades(),
                  firestore: db,
                  auth: auth,
                  sectionService: _Sections(),
                ),
                _ => const InstructorAIQuizGeneratorScreen(),
              };
              await _mount(t, page, width: width, dark: dark, scale: scale);
              expect(t.takeException(), isNull);
              if (kind == 'quiz') {
                final question = find.byWidgetPredicate(
                  (w) =>
                      w is TextField && w.decoration?.labelText == 'Question',
                );
                await t.ensureVisible(question);
                await t.pumpAndSettle();
                expect(question, findsOneWidget);
              }
              if (kind == 'submissions') {
                final student = find.text('Alex Student');
                for (
                  var attempt = 0;
                  attempt < 12 && student.evaluate().isEmpty;
                  attempt++
                ) {
                  await t.drag(
                    find.byType(NestedScrollView),
                    const Offset(0, -350),
                  );
                  await t.pumpAndSettle();
                }
                await t.ensureVisible(student);
                await t.pumpAndSettle();
              }
              expect(t.takeException(), isNull);
              if (width == 1440 && scale == 1) {
                await _capture(t, '$kind-$width-$dark');
              }
            },
          );
        }
      }
    }
  }
  testWidgets(
    'Quiz editing retains choices, correct answers, points and draft save',
    (t) async {
      final db = _Db();
      await _mount(
        t,
        InstructorAiQuizEditorScreen(
          assessmentId: 'quiz',
          courseId: 'course',
          moduleId: 'module',
          firestore: db,
          auth: _Auth(),
        ),
      );
      final question = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Question',
      );
      await t.ensureVisible(question);
      await t.enterText(question, 'Which answer is best?');
      await _tap(t, find.text('Save quiz draft'));
      expect(db.updated?['title'], 'Data basics');
      expect(db.updated?['questionCount'], 1);
      final row = (db.updated!['questions'] as List).first as Map;
      expect(row['question'], 'Which answer is best?');
      expect(row['options'], ['One', 'Two', 'Three', 'Four']);
      expect(row['correctAnswerIndex'], 1);
      expect(row['points'], 2);
    },
  );
  testWidgets('Quiz editor keeps role restrictions', (t) async {
    await _mount(
      t,
      InstructorAiQuizEditorScreen(
        assessmentId: 'quiz',
        courseId: 'course',
        moduleId: 'module',
        firestore: _Db(role: 'student'),
        auth: _Auth(),
      ),
    );
    expect(find.text('Only instructors can edit AI quizzes.'), findsOneWidget);
  });
  testWidgets(
    'Quiz results still filter passed attempts and search by student',
    (t) async {
      await _mount(t, InstructorQuizResultsScreen(quizService: _Quizzes()));
      await _tap(t, find.text('Passed (1)'));
      expect(find.text('Jamie Student'), findsNothing);
      expect(find.text('Alex Student'), findsOneWidget);
      await _tap(t, find.text('All (2)'));
      await t.enterText(find.byType(TextField), 'Jamie');
      await t.pumpAndSettle();
      expect(find.text('Jamie Student'), findsOneWidget);
      expect(find.text('Alex Student'), findsNothing);
    },
  );
  testWidgets('Semester posting still requires a preview and confirmation', (
    t,
  ) async {
    final api = _Grades();
    await _mount(
      t,
      InstructorSemesterGradesScreen(
        courseId: 'course',
        sectionId: 'section',
        api: api,
        firestore: _Db(),
        auth: _Auth(),
        sectionService: _Sections(),
      ),
      width: 1440,
    );
    final weight = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Activity',
    );
    await t.ensureVisible(weight);
    await t.enterText(weight, '100');
    await t.pumpAndSettle();
    await _tap(t, find.text('Compute Preview'));
    expect(api.calls, ['preview']);
    await _tap(t, find.text('Post Semester Grades'));
    await _tap(t, find.text('Cancel'));
    expect(api.calls, ['preview']);
    await _tap(t, find.text('Post Semester Grades'));
    await _tap(t, find.text('Post grades'));
    expect(api.calls, ['preview', 'finalize']);
    expect(find.text('1 semester grades posted.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Submission feedback is saved through the existing service', (
    t,
  ) async {
    final service = _Submissions();
    await _mount(
      t,
      InstructorAssessmentGradingScreen(
        assessmentId: 'assignment',
        firestore: _Db(),
        submissionService: service,
      ),
    );
    await _tap(t, find.text('Score & feedback'));
    await t.enterText(find.byType(TextField).last, 'Clear solution.');
    await _tap(t, find.text('Save Feedback'));
    expect(service.feedback, 'Clear solution.');
  });
}
