/// Pure helpers shared by the admin library, activity viewer and CSV exports.
String adminText(Object? value) => (value ?? '').toString().trim();

Map<String, int> adminEnrollmentCounts(Iterable<Map<String, dynamic>> records) {
  final students = <String, Set<String>>{};
  for (final record in records) {
    final course = adminText(record['courseId']);
    final student = adminText(record['studentId']);
    if (adminText(record['status']).toLowerCase() != 'active' ||
        course.isEmpty ||
        student.isEmpty) {
      continue;
    }
    students.putIfAbsent(course, () => {}).add(student);
  }
  return students.map((course, members) => MapEntry(course, members.length));
}

DateTime? adminDate(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

String adminTimestamp(Object? value) {
  final date = adminDate(value)?.toLocal();
  if (date == null) return 'Not recorded';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String adminFileType(Map<String, dynamic> file) {
  final name = adminText(file['fileName']);
  final dot = name.lastIndexOf('.');
  return dot < 0 ? 'FILE' : name.substring(dot + 1).toUpperCase();
}

String adminFileSize(Object? bytes) {
  if (bytes is! num || bytes < 0) return 'Not recorded';
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Only original objects from the configured learning-materials bucket may be
/// embedded. Never treat a URL in a Firestore record as executable HTML.
Uri? adminMaterialUri(
  Map<String, dynamic> file,
  String projectUrl,
  String bucket,
) {
  final uri = Uri.tryParse(adminText(file['fileUrl']));
  final project = Uri.tryParse(projectUrl);
  if (uri == null ||
      project == null ||
      uri.scheme != 'https' ||
      uri.host != project.host ||
      uri.port != project.port ||
      uri.userInfo.isNotEmpty ||
      !uri.path.startsWith('/storage/v1/object/public/$bucket/')) {
    return null;
  }
  final objectPath = uri.path.substring(
    '/storage/v1/object/public/$bucket/'.length,
  );
  if (objectPath.isEmpty ||
      uri.pathSegments.any(
        (part) =>
            part == '.' ||
            part == '..' ||
            part.contains('/') ||
            part.contains(String.fromCharCode(92)),
      )) {
    return null;
  }
  return uri.replace(fragment: '');
}

String adminCsv(Iterable<List<Object?>> rows) {
  String cell(Object? value) {
    var text = (value ?? '').toString();
    if (value is! num && RegExp(r'^[=+@\-\t\r\n]').hasMatch(text.trimLeft())) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
}

const adminEventLabels = <String, String>{
  'login': 'Login',
  'logout': 'Logout requested',
  'course_created': 'Course created',
  'material_uploaded': 'File uploaded',
};
