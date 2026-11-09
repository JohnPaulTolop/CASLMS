enum CalendarKind { event, deadline, holiday }

DateTime philippineTime(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: 8));
DateTime philippineDay(DateTime utc) {
  final date = philippineTime(utc);
  return DateTime.utc(date.year, date.month, date.day);
}

DateTime philippineWallToUtc(DateTime wall) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
).subtract(const Duration(hours: 8));

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.kind,
    this.description = '',
    this.courseId = '',
    this.courseLabel = '',
    this.ownerId = '',
    this.allDay = false,
    this.sourceUrl,
    this.assessmentId = '',
    this.moduleId = '',
    this.course = const {},
  });
  final String id,
      title,
      description,
      courseId,
      courseLabel,
      ownerId,
      assessmentId,
      moduleId;
  final DateTime start, end;
  final CalendarKind kind;
  final bool allDay;
  final String? sourceUrl;
  final Map<String, dynamic> course;
  bool occursOn(DateTime day) =>
      !philippineDay(start).isAfter(day) && !philippineDay(end).isBefore(day);
}

class CalendarData {
  const CalendarData({
    required this.entries,
    required this.courses,
    this.eventsAvailable = true,
  });
  final List<CalendarEntry> entries;
  final List<Map<String, dynamic>> courses;
  final bool eventsAvailable;
}
