import 'package:caslms/services/section_audience_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enrollment = <String, dynamic>{
    'studentId': 'student',
    'courseId': 'course',
    'sectionId': '4C',
    'status': 'active',
  };
  final module = <String, dynamic>{
    'id': 'module',
    'courseId': 'course',
    'sectionIds': ['4C'],
    'status': 'published',
  };
  final material = <String, dynamic>{
    'id': 'material',
    'courseId': 'course',
    'moduleId': 'module',
    'sectionIds': ['4C'],
    'status': 'published',
  };

  test('assigned material is visible to its student section', () {
    expect(
      SectionAudienceService.studentCanAccess(
        enrollment: enrollment,
        module: module,
        child: material,
      ),
      isTrue,
    );
  });

  test('material assigned to another section is hidden', () {
    expect(
      SectionAudienceService.studentCanAccess(
        enrollment: enrollment,
        module: module,
        child: {
          ...material,
          'sectionIds': ['4D'],
        },
      ),
      isFalse,
    );
  });

  test('stale material mirror pointing to another module is hidden', () {
    expect(
      SectionAudienceService.studentCanAccess(
        enrollment: enrollment,
        module: module,
        child: {...material, 'moduleId': 'another-module'},
      ),
      isFalse,
    );
  });
}
