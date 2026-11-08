import 'calendar_date.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulatory,
  lutealEarly,
  lutealLate,
  unknown,
}

enum LutealSubphase { early, late }

/// Calendar-based estimates only. They cannot confirm ovulation or fertility.
class PhaseResult {
  const PhaseResult({
    required this.phase,
    required this.phaseDay,
    required this.cycleDay,
    required this.ovulationDay,
    required this.fertileWindow,
    required this.isFertile,
    required this.lutealSubphase,
    required this.daysUntilPeriod,
    required this.daysUntilOvulation,
  });

  final CyclePhase phase;
  final int? phaseDay;
  final int cycleDay;
  final int ovulationDay;
  final DateRange fertileWindow;

  /// Whether the date is in the modeled window; null when the cycle is overdue.
  /// This is not confirmation of fertility or infertility.
  final bool? isFertile;
  final LutealSubphase? lutealSubphase;

  /// Signed day counts: a negative value means the estimate is overdue/past.
  final int daysUntilPeriod;
  final int daysUntilOvulation;
}
