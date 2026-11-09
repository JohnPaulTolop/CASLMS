import '../models/calendar_entry.dart';

/// National dates from Proclamations 1006 (2026), 1427 (2027), 1189 and 1264.
/// 2027 Eid dates await separate proclamations; no estimated dates are shown.
class PhilippineHolidays {
  static const sources = {
    2026: 'https://lawphil.net/executive/proc/proc2025/proc_1006_2025.html',
    2027: 'https://lawphil.net/executive/proc/proc2026/proc_1427_2026.html',
  };
  static List<CalendarEntry> forYear(int year) {
    if (!sources.containsKey(year)) return [];
    final rows = <(int, int, String, String)>[
      (1, 1, "New Year's Day", 'Regular holiday'),
      (
        2,
        25,
        'EDSA People Power Revolution Anniversary',
        'Special working day',
      ),
      (4, 9, 'Araw ng Kagitingan', 'Regular holiday'),
      (5, 1, 'Labor Day', 'Regular holiday'),
      (6, 12, 'Independence Day', 'Regular holiday'),
      (8, 21, 'Ninoy Aquino Day', 'Special non-working day'),
      (11, 1, "All Saints’ Day", 'Special non-working day'),
      (11, 2, "All Souls’ Day", 'Special non-working day'),
      (11, 30, 'Bonifacio Day', 'Regular holiday'),
      (12, 8, 'Immaculate Conception', 'Special non-working day'),
      (12, 24, 'Christmas Eve', 'Special non-working day'),
      (12, 25, 'Christmas Day', 'Regular holiday'),
      (12, 30, 'Rizal Day', 'Regular holiday'),
      (12, 31, 'Last Day of the Year', 'Special non-working day'),
      if (year == 2026) ...[
        (2, 17, 'Chinese New Year', 'Special non-working day'),
        (3, 20, 'Eid’l Fitr', 'Regular holiday · Proclamation 1189'),
        (4, 2, 'Maundy Thursday', 'Regular holiday'),
        (4, 3, 'Good Friday', 'Regular holiday'),
        (4, 4, 'Black Saturday', 'Special non-working day'),
        (5, 27, 'Eid’l Adha', 'Regular holiday · Proclamation 1264'),
        (8, 31, 'National Heroes Day', 'Regular holiday'),
      ] else ...[
        (2, 6, 'Chinese New Year', 'Special non-working day'),
        (3, 25, 'Maundy Thursday', 'Regular holiday'),
        (3, 26, 'Good Friday', 'Regular holiday'),
        (3, 27, 'Black Saturday', 'Special non-working day'),
        (8, 30, 'National Heroes Day', 'Regular holiday'),
      ],
    ];
    return rows.map((row) {
      final start = DateTime.utc(
        year,
        row.$1,
        row.$2,
      ).subtract(const Duration(hours: 8));
      final source = row.$3 == 'Eid’l Fitr'
          ? 'https://pco.gov.ph/news_releases/palace-declares-march-20-regular-holiday-nationwide-for-eidl-fitr/'
          : row.$3 == 'Eid’l Adha'
          ? 'https://pco.gov.ph/news_releases/palace-declares-may-27-as-a-regular-holiday-for-eidl-adha-observance/'
          : sources[year];
      return CalendarEntry(
        id: 'holiday-$year-${row.$1}-${row.$2}',
        title: row.$3,
        start: start,
        end: start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1)),
        kind: CalendarKind.holiday,
        allDay: true,
        description:
            '${row.$4}. National observance; local holidays are not included.',
        sourceUrl: source,
      );
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
  }
}
