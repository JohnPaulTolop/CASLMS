import 'package:caslms/services/section_audience_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final module = <String, dynamic>{
    'id': 'm',
    'courseId': 'course',
    'sectionIds': ['4C'],
  };
  final child = <String, dynamic>{
    'id': 'item',
    'moduleId': 'm',
    'courseId': 'course',
    'sectionIds': ['*'],
  };
  bool visible(Map<String, dynamic> row, String? section) =>
      SectionAudienceService.visibleInInstructorSection(row, section);
  test(
    '4C-only module is absent from 4D, shared and multi-section modules remain',
    () {
      expect(visible(module, '4C'), isTrue);
      expect(visible(module, '4D'), isFalse);
      expect(
        visible({
          ...module,
          'sectionIds': ['4C', '4D'],
        }, '4D'),
        isTrue,
      );
      expect(
        visible({
          ...module,
          'sectionIds': ['*'],
        }, '4D'),
        isTrue,
      );
    },
  );
  test('All sections retains every record for instructor management', () {
    expect(visible(module, null), isTrue);
    expect(visible(module, ''), isTrue);
    expect(visible({...module, 'sectionIds': []}, null), isTrue);
  });
  test('Legacy modules remain shared; malformed audiences do not leak into a section', () {
    expect(visible({'id': 'legacy'}, '4D'), isTrue);
    for (final ids in [
      [],
      ['*', '4C'],
      ['4C', '4C'],
      null,
      '4C',
    ]) {
      expect(visible({...module, 'sectionIds': ids}, '4C'), isFalse);
    }
  });
  test('Materials and assessments cannot widen the module audience', () {
    expect(
      SectionAudienceService.filterInstructorChildren([child], [module], '4C'),
      [child],
    );
    expect(
      SectionAudienceService.filterInstructorChildren([child], [module], '4D'),
      isEmpty,
    );
    expect(
      SectionAudienceService.filterInstructorChildren(
        [
          {
            ...child,
            'sectionIds': ['4D'],
          },
        ],
        [module],
        '4C',
      ),
      isEmpty,
    );
  });
  test('Old assessment sectionId remains an additional restriction', () {
    final shared = {
      ...module,
      'sectionIds': ['*'],
    };
    final quiz = {
      ...child,
      'sectionIds': ['4C', '4D'],
      'sectionId': '4C',
    };
    expect(
      SectionAudienceService.filterInstructorChildren([quiz], [shared], '4C'),
      [quiz],
    );
    expect(
      SectionAudienceService.filterInstructorChildren([quiz], [shared], '4D'),
      isEmpty,
    );
  });
  test('Section changes recompute from full records rather than the previous filtered view', () {
    final modules = [
      module,
      {
        ...module,
        'id': 'n',
        'sectionIds': ['4D'],
      },
    ];
    final records = [
      child,
      {...child, 'id': 'other', 'moduleId': 'n'},
    ];
    expect(
      SectionAudienceService.filterInstructorChildren(
        records,
        modules,
        '4C',
      ).single['id'],
      'item',
    );
    expect(
      SectionAudienceService.filterInstructorChildren(
        records,
        modules,
        '4D',
      ).single['id'],
      'other',
    );
    expect(
      SectionAudienceService.filterInstructorChildren(
        records,
        modules,
        null,
      ).length,
      2,
    );
  });
  test(
    'Orphaned and foreign-course children are absent from section views',
    () {
      expect(
        SectionAudienceService.filterInstructorChildren([child], [], '4C'),
        isEmpty,
      );
      expect(
        SectionAudienceService.filterInstructorChildren(
          [
            {...child, 'courseId': 'other'},
          ],
          [module],
          '4C',
        ),
        isEmpty,
      );
    },
  );
  test('Instructor drafts remain manageable in their assigned section', () {
    expect(visible({...module, 'status': 'draft'}, '4C'), isTrue);
  });
}
