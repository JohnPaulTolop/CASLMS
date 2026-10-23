import 'dart:io';

import 'package:caslms/models/course_order.dart';

class FakeTimestamp {
  FakeTimestamp(this.millisecondsSinceEpoch);
  final int millisecondsSinceEpoch;
}

void main() {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  final classes = <Map<String, dynamic>>[
    {
      'id': 'old-join',
      'code': 'A',
      'joinedAt': DateTime.utc(2025),
      'createdAt': DateTime.utc(2026),
    },
    {
      'id': 'new-join',
      'code': 'Z',
      'joinedAt': DateTime.utc(2026),
      'createdAt': DateTime.utc(2020),
    },
    {'id': 'missing', 'code': 'A'},
  ]..sort(compareJoinedCourses);
  check(
    classes.first['id'] == 'new-join',
    'Newest membership precedes newly created courses',
  );
  check(
    classes.last['id'] == 'missing',
    'Legacy missing timestamps remain accessible at the end',
  );
  check(
    courseDate(FakeTimestamp(1234)) == 1234,
    'Firestore-style timestamps are supported',
  );
  check(
    courseDate('2026-01-01T00:00:00Z') ==
        DateTime.utc(2026).millisecondsSinceEpoch,
    'ISO timestamps are supported',
  );
  check(
    courseDate(null) == 0 && courseDate(Object()) == 0,
    'Missing and malformed dates are safe',
  );
  check(
    compareJoinedCourses(
          {'id': 'B', 'enrolledAt': DateTime.utc(2026)},
          {'id': 'A', 'acceptedAt': DateTime.utc(2025)},
        ) <
        0,
    'Legacy enrollment date fallbacks',
  );
  check(
    compareJoinedCourses({'id': 'a', 'code': 'IT'}, {'id': 'b', 'code': 'IT'}) <
        0,
    'Stable ID resolves equal dates and codes',
  );
  check(
    compareJoinedCourses({'code': 'A'}, {'code': 'B'}) < 0,
    'Legacy ties have deterministic course order',
  );
  stdout.writeln('Passed $checks joined-course ordering checks.');
}
