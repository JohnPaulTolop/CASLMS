import 'package:caslms/services/instructor_workspace_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sections = [
    {'id': 'a', 'courseId': 'course', 'status': 'active'},
    {'id': 'old', 'courseId': 'course', 'status': 'archived'},
    {'id': 'foreign', 'courseId': 'other', 'status': 'active'},
  ];
  InstructorWorkspaceContext selected() {
    final state = InstructorWorkspaceContext();
    final token = state.beginCourse('teacher', 'course');
    state.commitSections(token, 'teacher', 'course', sections, requested: 'a');
    return state;
  }

  test('Same-course refresh preserves selection across tabs and routes', () {
    final state = selected();
    final token = state.beginCourse('teacher', 'course');
    expect(state.commitSections(token, 'teacher', 'course', sections), isTrue);
    expect(state.sectionId, 'a');
  });
  test('Changing courses immediately removes incompatible section', () {
    final state = selected()..beginCourse('teacher', 'other');
    expect(state.sectionId, isNull);
  });
  test('Failure of an older request cannot clear a newer selection', () {
    final state = selected();
    final old = state.beginCourse('teacher', 'course');
    final latest = state.beginCourse('teacher', 'course');
    state.commitSections(latest, 'teacher', 'course', sections, requested: 'a');
    state.clearCourse('course', revision: old);
    expect(state.sectionId, 'a');
  });
  for (final id in ['old', 'foreign', 'deleted']) {
    test('Rejects invalid section $id', () {
      final state = selected();
      final token = state.beginCourse('teacher', 'course');
      state.commitSections(token, 'teacher', 'course', sections, requested: id);
      expect(state.sectionId, isNull);
    });
  }
  test('Deleted section is cleared during refresh', () {
    final state = selected();
    final token = state.beginCourse('teacher', 'course');
    state.commitSections(token, 'teacher', 'course', []);
    expect(state.sectionId, isNull);
  });
  for (final uid in [null, 'another-teacher']) {
    test('Account transition to $uid clears context and pending requests', () {
      final state = selected();
      final token = state.beginCourse('teacher', 'course');
      state.bindUser(uid);
      expect(state.courseId, isNull);
      expect(
        state.commitSections(
          token,
          'teacher',
          'course',
          sections,
          requested: 'a',
        ),
        isFalse,
      );
    });
  }
  test('An older async result cannot restore a superseded selection', () async {
    final state = selected();
    final old = state.beginCourse('teacher', 'course');
    final latest = state.beginCourse('teacher', 'course');
    state.commitSections(latest, 'teacher', 'course', sections, requested: '');
    await Future<void>.delayed(Duration.zero);
    expect(
      state.commitSections(old, 'teacher', 'course', sections, requested: 'a'),
      isFalse,
    );
    expect(state.sectionId, isNull);
  });
}
