/// Treat DateTime as a calendar date, not as an instant in a particular zone.
DateTime calendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime addCalendarDays(DateTime date, int days) =>
    calendarDate(date).add(Duration(days: days));

int calendarDaysBetween(DateTime start, DateTime end) =>
    calendarDate(end).difference(calendarDate(start)).inDays;

/// An inclusive range of calendar dates.
class DateRange {
  DateRange(DateTime start, DateTime end)
      : start = calendarDate(start),
        end = calendarDate(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('The end of a date range cannot precede its start.');
    }
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final day = calendarDate(date);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}
