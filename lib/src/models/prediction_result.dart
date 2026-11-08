import 'calendar_date.dart';
import 'engine_output.dart';

/// Consensus forecast (or an explicitly observed start).
class PredictionResult {
  PredictionResult({
    required DateTime predictedDate,
    required this.cycleLength,
    required this.confidence,
    required this.windowDays,
    required List<EngineOutput> contributingEngines,
    this.isObserved = false,
  }) : predictedDate = calendarDate(predictedDate),
       contributingEngines = List.unmodifiable(contributingEngines);

  final DateTime predictedDate;
  final int cycleLength;
  final double confidence;
  final int windowDays;
  final List<EngineOutput> contributingEngines;
  final bool isObserved;

  DateRange get window => DateRange(
    addCalendarDays(predictedDate, -windowDays),
    addCalendarDays(predictedDate, windowDays),
  );
}
