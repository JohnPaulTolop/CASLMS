import 'dart:io';
import 'dart:ui' as ui;

import 'package:caslms/core/app_theme.dart';
import 'package:caslms/screens/instructor/instructor_task_widgets.dart';
import 'package:caslms/screens/instructor/instructor_module_builder_page.dart';
import 'package:caslms/screens/instructor/instructor_add_learning_material_page.dart';
import 'package:caslms/screens/instructor/instructor_create_assessment_page.dart';
import 'package:caslms/services/module_service.dart';
import 'package:caslms/services/learning_material_service.dart';
import 'package:caslms/services/assessment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Map<String, dynamic>> _sections = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': '4C',
    'name': 'Section 4C',
    'identifier': '4C',
    'status': 'active',
  },
];
const List<String> _moduleSectionIds = <String>['4C'];

class _Modules extends Fake implements ModuleService {
  Map<String, Object?>? saved;
  bool fail = false;
  @override
  Future<int> getNextModuleOrder({required String courseId}) async => 2;
  @override
  Future<String> createModule({
    required String courseId,
    required String title,
    required String description,
    required int order,
    required List<String> sectionIds,
    String status = 'published',
  }) async {
    if (fail) throw ModuleServiceException('Unable to save. Please retry.');
    saved = {
      'course': courseId,
      'title': title,
      'description': description,
      'order': order,
      'sections': sectionIds,
      'status': status,
    };
    return 'new-module';
  }
}

class _Materials extends Fake implements LearningMaterialService {
  Map<String, Object?>? saved;
  @override
  Future<Map<String, dynamic>> createLinkMaterial({
    required String courseId,
    required String moduleId,
    required String title,
    String description = '',
    required String url,
    required List<String> sectionIds,
    String resourceType = 'link',
    String status = 'published',
  }) async {
    saved = {
      'course': courseId,
      'module': moduleId,
      'title': title,
      'url': url,
      'sections': sectionIds,
      'type': resourceType,
      'status': status,
    };
    return {'id': 'material'};
  }
}

class _Assessments extends Fake implements AssessmentService {
  Map<String, Object?>? saved;
  @override
  Future<Map<String, dynamic>> createExternalAssessment({
    required String courseId,
    required String moduleId,
    required String title,
    required String instructions,
    required String assessmentType,
    required String submissionMethod,
    String externalUrl = '',
    List<String> allowedSubmissionTypes = const [
      'github_repository',
      'zip_file',
      'technical_document',
    ],
    required num totalPoints,
    required DateTime dueAt,
    required List<String> sectionIds,
    String sectionId = '',
    String status = 'published',
  }) async {
    saved = {
      'course': courseId,
      'module': moduleId,
      'title': title,
      'method': submissionMethod,
      'url': externalUrl,
      'types': allowedSubmissionTypes,
      'points': totalPoints,
      'due': dueAt,
      'sections': sectionIds,
      'section': sectionId,
      'status': status,
    };
    return {'id': 'assessment', 'title': title};
  }
}

Future<void> mountTask(
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
        '/task': (_) =>
            RepaintBoundary(key: const ValueKey('task-preview'), child: page),
      },
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> _enter(WidgetTester t, Finder f, String text) async {
  await t.ensureVisible(f);
  await t.enterText(f, text);
  await t.pumpAndSettle();
}

Future<void> _capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_TASKS')) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('task-preview')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('build/task-previews/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
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
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        for (final kind in ['module', 'material', 'assessment']) {
          testWidgets('Task form $kind $width dark $dark text $scale', (
            t,
          ) async {
            final page = switch (kind) {
              'module' => InstructorModuleBuilderScreen(
                courseId: 'course',
                courseCode: 'IT302',
                courseTitle: 'Mobile development',
                moduleService: _Modules(),
                initialSectionId: '4C',
                sections: _sections,
              ),
              'material' => InstructorAddLearningMaterialScreen(
                courseId: 'course',
                moduleId: 'module',
                moduleTitle: 'Chapter 1',
                sections: _sections,
                moduleSectionIds: _moduleSectionIds,
                initialSectionId: '4C',
                materialService: _Materials(),
              ),
              _ => InstructorCreateAssessmentScreen(
                courseId: 'course',
                moduleId: 'module',
                courseCode: 'IT302',
                courseTitle: 'Mobile development',
                moduleTitle: 'Chapter 1',
                sections: _sections,
                moduleSectionIds: _moduleSectionIds,
                initialSectionId: '4C',
                assessmentService: _Assessments(),
              ),
            };
            await mountTask(t, page, width: width, dark: dark, scale: scale);
            expect(find.byType(InstructorTaskActions), findsOneWidget);
            if (kind == 'material') {
              await _tap(t, find.text('Link'));
              expect(find.text('Source'), findsOneWidget);
            }
            final inputs = find.byType(TextField);
            await t.ensureVisible(inputs.last);
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            if (width != 320 && scale == 1) {
              await t.drag(
                find.byType(NestedScrollView),
                const Offset(0, 5000),
              );
              await t.pumpAndSettle();
              await _capture(t, '$kind-$width-$dark');
            }
          });
        }
      }
    }
  }
  testWidgets(
    'Module form validates, keeps retry available and saves a draft',
    (t) async {
      final service = _Modules();
      await mountTask(
        t,
        InstructorModuleBuilderScreen(
          courseId: 'course',
          moduleService: service,
          initialSectionId: '4C',
          sections: _sections,
        ),
      );
      await _tap(t, find.text('Publish module'));
      expect(service.saved, isNull);
      await _enter(
        t,
        find.byKey(const ValueKey('module-title')),
        'Foundations',
      );
      await _enter(
        t,
        find.byKey(const ValueKey('module-description')),
        'Learn the foundations.',
      );
      await _tap(t, find.byType(Switch));
      service.fail = true;
      await _tap(t, find.text('Save draft'));
      expect(find.text('Unable to save. Please retry.'), findsOneWidget);
      service.fail = false;
      await _tap(t, find.text('Save draft'));
      expect(service.saved, {
        'course': 'course',
        'title': 'Foundations',
        'description': 'Learn the foundations.',
        'order': 2,
        'sections': _moduleSectionIds,
        'status': 'draft',
      });
      expect(find.text('Course workspace'), findsOneWidget);
    },
  );
  testWidgets('Material source and visibility still submit the selected link', (
    t,
  ) async {
    final service = _Materials();
    await mountTask(
      t,
      InstructorAddLearningMaterialScreen(
        courseId: 'course',
        moduleId: 'module',
        moduleTitle: 'Chapter 1',
        sections: _sections,
        moduleSectionIds: _moduleSectionIds,
        initialSectionId: '4C',
        materialService: service,
      ),
    );
    await _enter(
      t,
      find.byKey(const ValueKey('material-title')),
      'Useful reference',
    );
    await _tap(t, find.text('Link'));
    final url = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.controller?.text == '' &&
          w.keyboardType == TextInputType.url,
    );
    await _enter(t, url, 'https://example.com/lesson');
    await _tap(t, find.text('Save as draft'));
    await _tap(t, find.text('Save draft'));
    expect(service.saved, {
      'course': 'course',
      'module': 'module',
      'title': 'Useful reference',
      'url': 'https://example.com/lesson',
      'sections': _moduleSectionIds,
      'type': 'link',
      'status': 'draft',
    });
  });
  testWidgets('Google Form method validates and saves its URL', (t) async {
    final service = _Assessments();
    await mountTask(
      t,
      InstructorCreateAssessmentScreen(
        courseId: 'course',
        moduleId: 'module',
        courseCode: 'IT302',
        courseTitle: 'Mobile development',
        moduleTitle: 'Chapter 1',
        sections: _sections,
        moduleSectionIds: _moduleSectionIds,
        initialSectionId: '4C',
        assessmentService: service,
      ),
    );
    await _tap(
      t,
      find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.initialValue == 'artifact',
      ),
    );
    await _tap(t, find.text('Google Form').last);
    expect(field('Google Form URL'), findsOneWidget);
    await _enter(t, field('Title'), 'Reflection');
    await _enter(t, field('Instructions'), 'Answer the reflection questions.');
    await _enter(t, field('Total Points'), '10');
    await _enter(t, field('Google Form URL'), 'https://example.com');
    await _tap(t, find.text('Save draft'));
    expect(service.saved, isNull);
    expect(
      find.text('Use a forms.gle or docs.google.com/forms link.'),
      findsOneWidget,
    );
    await _enter(t, field('Google Form URL'), 'https://forms.gle/classform');
    await _tap(
      t,
      find
          .ancestor(
            of: find.text('Due Date & Time'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await _tap(t, find.text('OK').last);
    await _tap(t, find.text('OK').last);
    await _tap(t, find.text('Save draft'));
    expect(service.saved?['method'], 'google_form');
    expect(service.saved?['url'], 'https://forms.gle/classform');
    expect(service.saved?['status'], 'draft');
    expect(service.saved?['course'], 'course');
    expect(service.saved?['module'], 'module');
  });
  testWidgets(
    'Assessment options, deadline, validation and draft saving remain intact',
    (t) async {
      final service = _Assessments();
      await mountTask(
        t,
        InstructorCreateAssessmentScreen(
          courseId: 'course',
          moduleId: 'module',
          courseCode: 'IT302',
          courseTitle: 'Mobile development',
          moduleTitle: 'Chapter 1',
          sections: _sections,
          moduleSectionIds: _moduleSectionIds,
          initialSectionId: '4C',
          assessmentService: service,
        ),
      );
      await _tap(t, find.text('Save draft'));
      expect(service.saved, isNull);
      await _enter(t, field('Title'), 'Practice activity');
      await _enter(t, field('Instructions'), 'Complete this exercise.');
      await _enter(t, field('Total Points'), '20');
      await _tap(
        t,
        find
            .ancestor(
              of: find.text('Due Date & Time'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await _tap(t, find.text('OK').last);
      await _tap(t, find.text('OK').last);
      await _tap(t, find.text('Save draft'));
      expect(service.saved?['course'], 'course');
      expect(service.saved?['module'], 'module');
      expect(service.saved?['points'], 20);
      expect(service.saved?['types'], [
        'github_repository',
        'zip_file',
        'technical_document',
      ]);
      expect(service.saved?['status'], 'draft');
    },
  );
}
