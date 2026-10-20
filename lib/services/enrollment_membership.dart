/// Shared interpretation of old and new enrollment records.
class EnrollmentMembership {
  static String text(Object? value) => (value ?? '').toString().trim();

  static String sectionId(
    Map<String, dynamic> enrollment,
    String originalCode,
  ) {
    final explicit = text(enrollment['sectionId']);
    return explicit.isEmpty ? originalCode.trim() : explicit;
  }

  static bool active(Map<String, dynamic> enrollment) =>
      text(enrollment['status']).toLowerCase() == 'active';

  static List<Map<String, dynamic>> uniqueActive(
    Iterable<Map<String, dynamic>> enrollments,
  ) {
    final students = <String, Map<String, dynamic>>{};
    for (final row in enrollments) {
      final student = text(row['studentId']);
      if (!active(row) || student.isEmpty) continue;
      final canonical = '${text(row['courseId'])}_$student';
      if (!students.containsKey(student) || text(row['id']) == canonical) {
        students[student] = row;
      }
    }
    return students.values.toList();
  }

  static Map<String, int> counts(
    Iterable<Map<String, dynamic>> enrollments,
    String originalCode,
  ) {
    final members = <String, Set<String>>{};
    for (final enrollment in uniqueActive(enrollments)) {
      final student = text(enrollment['studentId']);
      if (!active(enrollment) || student.isEmpty) continue;
      final section = sectionId(enrollment, originalCode);
      if (section.isNotEmpty) {
        members.putIfAbsent(section, () => {}).add(student);
      }
    }
    return members.map((key, value) => MapEntry(key, value.length));
  }
}
