/// Enrollment date, rather than course creation date, determines student order.
int courseDate(Object? value) {
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is String) {
    return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
  }
  try {
    return (value as dynamic).millisecondsSinceEpoch as int;
  } catch (_) {
    return 0;
  }
}

int compareJoinedCourses(Map<String, dynamic> a, Map<String, dynamic> b) {
  final order = courseDate(
    b['joinedAt'] ?? b['enrolledAt'] ?? b['acceptedAt'],
  ).compareTo(courseDate(a['joinedAt'] ?? a['enrolledAt'] ?? a['acceptedAt']));
  if (order != 0) return order;
  final code = (a['code'] ?? '').toString().compareTo(
    (b['code'] ?? '').toString(),
  );
  return code != 0
      ? code
      : (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
}
