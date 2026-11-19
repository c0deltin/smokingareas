/// Japanese public holidays (国民の祝日) by the rules in force since 2020,
/// including substitute holidays (振替休日) and citizens' holidays
/// (国民の休日). Pure Dart (tested); dates are calendar days in Japan.
library;

final _cache = <int, Set<int>>{};

/// Whether the calendar day [date] (only year, month and day are used) is a
/// public holiday in Japan.
bool isJapaneseHoliday(DateTime date) =>
    holidaysOf(date.year).contains(date.month * 100 + date.day);

/// Holidays of [year] as `month * 100 + day`.
Set<int> holidaysOf(int year) => _cache.putIfAbsent(year, () {
      final base = <DateTime>{
        DateTime(year, 1, 1),
        _nthMonday(year, 1, 2), // Coming of Age Day
        DateTime(year, 2, 11),
        DateTime(year, 2, 23), // Emperor's Birthday
        DateTime(year, 3, _vernalEquinox(year)),
        DateTime(year, 4, 29),
        DateTime(year, 5, 3),
        DateTime(year, 5, 4),
        DateTime(year, 5, 5),
        _nthMonday(year, 7, 3), // Marine Day
        DateTime(year, 8, 11), // Mountain Day
        _nthMonday(year, 9, 3), // Respect for the Aged Day
        DateTime(year, 9, _autumnalEquinox(year)),
        _nthMonday(year, 10, 2), // Sports Day
        DateTime(year, 11, 3),
        DateTime(year, 11, 23),
      };
      final days = {...base};
      // Substitute holiday: a holiday on a Sunday moves the day off to the
      // next day that is not a holiday.
      for (final d in base) {
        if (d.weekday != DateTime.sunday) continue;
        var next = _addDays(d, 1);
        while (days.contains(next)) {
          next = _addDays(next, 1);
        }
        days.add(next);
      }
      // Citizens' holiday: a weekday between two holidays.
      for (final d in base) {
        final between = _addDays(d, 1);
        if (base.contains(_addDays(d, 2)) &&
            !days.contains(between) &&
            between.weekday != DateTime.sunday) {
          days.add(between);
        }
      }
      return {
        for (final d in days)
          if (d.year == year) d.month * 100 + d.day,
      };
    });

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime _nthMonday(int year, int month, int n) {
  final first = DateTime(year, month, 1);
  final offset = (DateTime.monday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + (n - 1) * 7);
}

// Astronomical approximation used for 1980–2099.
int _vernalEquinox(int y) =>
    (20.8431 + 0.242194 * (y - 1980) - ((y - 1980) ~/ 4)).floor();

int _autumnalEquinox(int y) =>
    (23.2488 + 0.242194 * (y - 1980) - ((y - 1980) ~/ 4)).floor();

/// The current wall-clock time in Japan (JST, UTC+9, no daylight saving),
/// whatever the device's time zone is.
DateTime japanNow([DateTime? utcNow]) {
  final t = (utcNow ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return DateTime(t.year, t.month, t.day, t.hour, t.minute);
}
