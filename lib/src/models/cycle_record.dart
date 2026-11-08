import 'calendar_date.dart';

/// One recorded period start and, if known, its bleeding duration in days.
class CycleRecord {
  CycleRecord({required DateTime startDate, this.periodDuration})
    : startDate = calendarDate(startDate) {
    if (periodDuration != null && periodDuration! < 1) {
      throw ArgumentError.value(
        periodDuration,
        'periodDuration',
        'must be positive',
      );
    }
  }

  final DateTime startDate;
  final int? periodDuration;
}

/// The engine contract requires oldest-to-newest starts with no duplicates.
List<int> completedCycleLengths(List<CycleRecord> history) {
  final lengths = <int>[];
  for (var i = 1; i < history.length; i++) {
    final length = calendarDaysBetween(
      history[i - 1].startDate,
      history[i].startDate,
    );
    if (length <= 0) {
      throw ArgumentError(
        'Cycle starts must be strictly increasing, with no duplicates.',
      );
    }
    lengths.add(length);
  }
  return lengths;
}
