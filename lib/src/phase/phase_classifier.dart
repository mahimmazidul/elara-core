import 'dart:math' as math;

import '../models/calendar_date.dart';
import '../models/cycle_record.dart';
import '../models/phase_result.dart';

/// Fixed calendar arithmetic, not an observation of actual ovulation.
class PhaseClassifier {
  PhaseResult classify({
    required CycleRecord lastPeriod,
    required int cycleLength,
    required DateTime date,
  }) {
    if (cycleLength < 15) {
      throw ArgumentError.value(
          cycleLength, 'cycleLength', 'must be at least 15 days');
    }
    final duration = lastPeriod.periodDuration ?? 5;
    if (duration > cycleLength) {
      throw ArgumentError(
          'Period duration cannot exceed the estimated cycle length.');
    }
    final elapsed = calendarDaysBetween(lastPeriod.startDate, date);
    if (elapsed < 0) {
      throw ArgumentError(
          'The classification date cannot precede the last period start.');
    }
    final day = elapsed + 1;
    final ovulation = cycleLength - 14;
    // A short cycle can put the modeled window before day 1. Clip its dates,
    // not the recorded history. It can also overlap bleeding.
    final fertileStart = math.max(1, ovulation - 5);
    final fertileEnd = math.min(cycleLength, ovulation + 1);
    final window = DateRange(
      addCalendarDays(lastPeriod.startDate, fertileStart - 1),
      addCalendarDays(lastPeriod.startDate, fertileEnd - 1),
    );
    final midLuteal = (ovulation + 1 + cycleLength) ~/ 2;
    final CyclePhase phase;
    final int? phaseDay;
    LutealSubphase? subphase;

    // Do not silently wrap into a new cycle when no new period was recorded.
    if (day > cycleLength) {
      phase = CyclePhase.unknown;
      phaseDay = null;
    } else if (day <= duration) {
      phase = CyclePhase.menstrual;
      phaseDay = day;
    } else if (day < fertileStart) {
      phase = CyclePhase.follicular;
      phaseDay = day - duration;
    } else if (day <= fertileEnd) {
      phase = CyclePhase.ovulatory;
      phaseDay = day - math.max(fertileStart, duration + 1).toInt() + 1;
    } else if (day <= midLuteal) {
      phase = CyclePhase.lutealEarly;
      subphase = LutealSubphase.early;
      phaseDay = day - math.max(ovulation + 2, duration + 1).toInt() + 1;
    } else {
      phase = CyclePhase.lutealLate;
      subphase = LutealSubphase.late;
      final lateStart =
          math.max(midLuteal + 1, math.max(fertileEnd + 1, duration + 1));
      phaseDay = day - lateStart + 1;
    }
    return PhaseResult(
      phase: phase,
      phaseDay: phaseDay,
      cycleDay: day,
      ovulationDay: ovulation,
      fertileWindow: window,
      isFertile: window.contains(date),
      lutealSubphase: subphase,
      daysUntilPeriod: cycleLength - elapsed,
      daysUntilOvulation: ovulation - day,
    );
  }
}
