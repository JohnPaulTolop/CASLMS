import 'dart:io';

import 'package:caslms/models/admin_records.dart';

class _Timestamp {
  DateTime toDate() => DateTime.utc(2026, 10, 23);
}

void main() {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  const origin = 'https://example.supabase.co';
  const bucket = 'caslms-learning-materials';
  const path =
      '$origin/storage/v1/object/public/$bucket/courses/c/modules/m/lecture.pdf';
  Uri? uri(String value) =>
      adminMaterialUri({'fileUrl': value}, origin, bucket);
  check(uri(path)?.scheme == 'https', 'Valid original learning-material URL');
  check(
    uri('$path?download=lecture.pdf') != null,
    'Storage query parameters remain supported',
  );
  check(uri('$path#page=2')?.fragment == '', 'Preview fragment is removed');
  check(
    uri(path.replaceFirst('https:', 'http:')) == null,
    'Reject insecure URLs',
  );
  check(
    uri(
          'https://example.supabase.co.evil.test/storage/v1/object/public/$bucket/a.pdf',
        ) ==
        null,
    'Reject lookalike origins',
  );
  check(
    uri('https://evil.test/storage/v1/object/public/$bucket/a.pdf') == null,
    'Reject foreign storage hosts',
  );
  check(
    uri('javascript:alert(1)') == null && uri('data:text/html,hello') == null,
    'Reject executable URL schemes',
  );
  check(
    uri(
          'https://user:pass@example.supabase.co/storage/v1/object/public/$bucket/a.pdf',
        ) ==
        null,
    'Reject credentials in file URLs',
  );
  check(
    uri(path.replaceFirst(bucket, 'other-bucket')) == null,
    'Reject other storage buckets',
  );
  check(
    uri('$origin/storage/v1/object/public/$bucket/%2e%2e/private/file.pdf') ==
        null,
    'Reject encoded traversal',
  );
  check(
    uri('$origin/storage/v1/object/public/$bucket/a%2fb.pdf') == null,
    'Reject embedded encoded path separators',
  );
  check(
    uri('$origin/storage/v1/object/public/$bucket/') == null,
    'Require an object path',
  );
  check(
    adminFileType({'fileName': 'LECTURE.PdF'}) == 'PDF',
    'File type is case insensitive',
  );
  check(
    adminFileType({'fileName': 'README'}) == 'FILE',
    'Unknown file type handled',
  );
  check(
    adminFileSize(0) == '0 B' && adminFileSize(1024) == '1.0 KB',
    'Byte and KB formatting',
  );
  check(adminFileSize(1048576) == '1.0 MB', 'MB formatting');
  check(
    adminFileSize(null) == 'Not recorded' &&
        adminFileSize(-1) == 'Not recorded',
    'Malformed size is not reported as zero',
  );
  check(
    adminDate(_Timestamp()) == DateTime.utc(2026, 10, 23),
    'Firestore-style timestamp supported',
  );
  check(
    adminDate(Object()) == null && adminTimestamp(null) == 'Not recorded',
    'Missing timestamp handled',
  );
  final csv = adminCsv([
    ['Title', 'Name'],
    ['A, B', 'Teacher "One"'],
    ['line\nbreak', '=HYPERLINK("bad")'],
    [' +formula', '-formula'],
    ['@formula', -2],
  ]);
  check(csv.startsWith('\uFEFF'), 'Excel UTF-8 BOM');
  check(
    csv.contains('"A, B","Teacher ""One"""'),
    'CSV quotes and commas escaped',
  );
  check(
    csv.contains('"line\nbreak"'),
    'Embedded newlines remain within quoted cells',
  );
  check(
    csv.contains('"\'=HYPERLINK('),
    'Spreadsheet formula input neutralized',
  );
  check(
    csv.contains('"\' +formula","\'-formula"'),
    'Leading whitespace and formula prefixes neutralized',
  );
  check(
    csv.contains('"\'@formula","-2"'),
    'Numeric values retained while text formula prefixes neutralized',
  );
  check(
    adminEventLabels['login'] != adminEventLabels['logout'],
    'Login and logout have separate categories',
  );
  final counts = adminEnrollmentCounts([
    {'courseId': 'one', 'studentId': 'student', 'status': 'active'},
    {'courseId': 'one', 'studentId': 'student', 'status': 'active'},
    {'courseId': 'two', 'studentId': 'student', 'status': 'active'},
    {'courseId': 'one', 'studentId': 'inactive', 'status': 'inactive'},
    {'courseId': 'one', 'studentId': 'another', 'status': 'ACTIVE'},
    {'courseId': 'one', 'studentId': '', 'status': 'active'},
    {'courseId': '', 'studentId': 'student', 'status': 'active'},
  ]);
  check(counts['one'] == 2, 'Distinct active students counted once per course');
  check(
    counts['two'] == 1,
    'Student enrolled in another course is counted there',
  );
  check(counts.length == 2, 'Invalid and inactive enrollments excluded');
  stdout.writeln('Passed $checks admin file URL, export and metadata checks.');
}
