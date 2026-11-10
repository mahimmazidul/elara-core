// Original work: Flowlytics by its contributors
// https://github.com/harshit2k4/flowlytics
// Original license: GNU AGPL v3.0
//
// Adapted for ELARA by Md. Mazidul Islam Mahim, 2026.
// Prediction and navigator logic restructured for the Dart package.
// See ATTRIBUTION.md for full details.

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

  /// The in-band range upstream Flowlytics used to keep one improbable entry
  /// out of its mean. Applied to the mean only; see [predict].
  static const int minimumPlausibleLength = 15;
  static const int maximumPlausibleLength = 50;

  /// The widest window this component will report.
  ///
  /// Not a statistical constant: it is the span over which a calendar estimate
  /// carries any information at all. Beyond it the honest answer is that this
  /// engine cannot place the next start, and the fusion layer should say so
  /// rather than print a radius with no relationship to the data.
  static const int maximumWindowDays = 60;

  @override
  String get name => 'Flowlytics';

  @override
  bool get isActive => true;

  @override
  EngineOutput? predict(List<CycleRecord> history) {
    // Every completed interval is kept. Upstream Flowlytics used a 15-50 day
    // band to keep one wild entry out of the mean, which is a reasonable guard
    // for *location* and a catastrophic one for *dispersion*: dropping the
    // observations that make a cycle irregular makes an irregular cycle look
    // regular, and the uncertainty the engine reports then describes a history
    // the user does not have. The band is applied to the mean only, below.
    final allLengths = completedCycleLengths(history);
    final plausible = allLengths
        .where((length) =>
            length >= minimumPlausibleLength &&
            length <= maximumPlausibleLength)
        .toList();
    // Flowlytics uses today's date for an empty log. We have no clock input,
    // so without a start date there is no anchored forecast to return.
    if (history.isEmpty) return null;

    // The band is inapplicable when it excludes everything: a person whose
    // recorded cycles are all longer than 50 days has shown that her normal
    // cycle is longer than the band, and answering with the 28-day baseline
    // would be a guess dressed as arithmetic. Use the observations instead.
    final locations = plausible.isEmpty ? allLengths : plausible;

    final recent = locations.reversed.take(6).toList();
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (var i = 0; i < recent.length; i++) {
      final weight = math.max(1.0 - i * 0.1, 0.1);
      weightedSum += recent[i] * weight;
      totalWeight += weight;
    }
    final average =
        recent.isEmpty ? baselineCycle : (weightedSum / totalWeight).round();

    // Dispersion over every observation, around its own centre, with Bessel's
    // correction. Two corrections to what this used to do:
    //
    //   * the spread is no longer measured against a recency-weighted, rounded
    //     location, which understated it whenever the two disagreed;
    //   * it is no longer measured only over the in-band subset.
    //
    // With one completed interval there is nothing to measure, so the upstream
    // default stands.
    final deviation =
        allLengths.length < 2 ? 1.5 : _sampleStandardDeviation(allLengths);
    final windowDays = deviation.ceil().clamp(1, maximumWindowDays);
    final confidence = _confidence(deviation, allLengths.length);
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

/// Sample standard deviation (n-1), the unbiased estimate of a person's own
/// cycle-to-cycle variability. Returns 0 for a constant history, which the
/// caller floors to a one-day window.
double _sampleStandardDeviation(List<int> values) {
  final mean =
      values.fold<double>(0, (sum, value) => sum + value) / values.length;
  final sumSquares = values.fold<double>(
      0, (sum, value) => sum + (value - mean) * (value - mean));
  return math.sqrt(sumSquares / (values.length - 1));
}

double _confidence(double deviation, int count) {
  if (count < 3) return 0.40;
  if (deviation < 1) return 0.95;
  if (deviation < 2) return 0.85;
  if (deviation < 4) return 0.65;
  if (deviation < 7) return 0.45;
  return 0.30;
}
