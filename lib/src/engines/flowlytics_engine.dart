// Adapted from Flowlytics' enhanced prediction and navigator engines.
// Flowlytics is AGPL-3.0; see ATTRIBUTION.md for the source and notices.
import 'dart:math' as math;

import '../models/calendar_date.dart';
import '../models/cycle_record.dart';
import '../models/engine_output.dart';
import 'engine_interface.dart';

/// A dated, caller-supplied observation. Strings use Flowlytics' symptom names.
///
/// [confirmedFlowStart] must mean a *new* period start, not ongoing bleeding.
class FlowSymptoms {
  FlowSymptoms({
    required DateTime date,
    this.confirmedFlowStart = false,
    this.spotting = false,
    List<String> physical = const [],
    List<String> moods = const [],
    List<String> skin = const [],
  })  : date = calendarDate(date),
        physical = List.unmodifiable(physical),
        moods = List.unmodifiable(moods),
        skin = List.unmodifiable(skin);

  final DateTime date;
  final bool confirmedFlowStart;
  final bool spotting;
  final List<String> physical;
  final List<String> moods;
  final List<String> skin;
}

/// Flowlytics' enhanced recency-weighted predictor and symptom navigator.
class FlowlyticsEngine implements CyclePredictionEngine {
  FlowlyticsEngine({this.baselineCycle = 28, this.symptoms}) {
    if (baselineCycle < 1) {
      throw ArgumentError.value(
          baselineCycle, 'baselineCycle', 'must be positive');
    }
  }

  final int baselineCycle;
  final FlowSymptoms? symptoms;

  @override
  String get name => 'Flowlytics';

  @override
  bool get isActive => true;

  @override
  EngineOutput? predict(List<CycleRecord> history) {
    final lengths = completedCycleLengths(history)
        .where((length) => length >= 15 && length <= 50)
        .toList();
    // Flowlytics uses today's date for an empty log. We have no clock input,
    // so without a start date there is no anchored forecast to return.
    if (history.isEmpty) return null;

    final recent = lengths.reversed.take(6).toList();
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (var i = 0; i < recent.length; i++) {
      final weight = math.max(1.0 - i * 0.1, 0.1);
      weightedSum += recent[i] * weight;
      totalWeight += weight;
    }
    final average =
        recent.isEmpty ? baselineCycle : (weightedSum / totalWeight).round();
    final deviation = lengths.length < 2
        ? 1.5
        : math.sqrt(lengths.fold<double>(0, (sum, value) {
              final difference = value - average;
              return sum + difference * difference;
            }) /
            lengths.length);
    final windowDays = deviation.round().clamp(1, 4);
    final confidence = _confidence(deviation, lengths.length);
    final start = history.last.startDate;
    var predictedDate = addCalendarDays(start, average);
    var observedStart = false;
    final observation = symptoms;

    // The enhanced navigator uses the observation day as "today". Require it
    // explicitly so forecasts stay deterministic and never read a device clock.
    if (observation != null && observation.date.isAfter(start)) {
      final daysAway = calendarDaysBetween(observation.date, predictedDate);
      if (observation.confirmedFlowStart) {
        predictedDate = observation.date;
        observedStart = true;
      } else if (observation.spotting ||
          observation.physical.contains('Spotting')) {
        // Flowlytics shifts on spotting too; unlike confirmed flow, it remains
        // an estimate and must not become an ensemble-wide observed override.
        predictedDate = observation.date;
      } else if (_hasAny(
              observation.physical, const {'Cramps', 'Backache', 'Bloating'}) &&
          daysAway <= 4 &&
          daysAway > 0) {
        predictedDate = addCalendarDays(predictedDate, -2);
      } else if ((_hasAny(
                  observation.moods, const {'Sensitive', 'Anxious', 'Tired'}) ||
              _hasAny(observation.skin, const {'Breakouts', 'Oily'})) &&
          daysAway <= 6 &&
          daysAway >= 0) {
        predictedDate = addCalendarDays(predictedDate, -1);
      }
    }
    final adjustedLength = calendarDaysBetween(start, predictedDate);
    if (adjustedLength <= 0) return null;

    return EngineOutput(
      engineName: name,
      predictedDate: predictedDate,
      predictedLength: adjustedLength.toDouble(),
      confidence: confidence,
      windowDays: windowDays,
      observedStart: observedStart,
    );
  }
}

bool _hasAny(List<String> values, Set<String> choices) =>
    values.any(choices.contains);

double _confidence(double deviation, int count) {
  if (count < 3) return 0.40;
  if (deviation < 1) return 0.95;
  if (deviation < 2) return 0.85;
  if (deviation < 4) return 0.65;
  if (deviation < 7) return 0.45;
  return 0.30;
}
