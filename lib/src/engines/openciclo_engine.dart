// Based on OpenCiclo, Copyright 2026 Emma Flora Harbison & Luis Rey Sánchez.
// SPDX-License-Identifier: Apache-2.0
// The upstream notice and license are retained in ATTRIBUTION.md and LICENSES/.

import 'dart:math' as math;

import '../models/calendar_date.dart';
import '../models/cycle_record.dart';
import '../models/engine_output.dart';
import 'engine_interface.dart';

/// OpenCiclo's released v0.2.1 shrinkage-median/Laplace forecast.
///
/// With no reference date, the forecast is made as of the last recorded start,
/// just as upstream does. An explicit reference date conditions the displayed
/// distribution on dates not yet past; it never calls the system clock.
class OpenCicloEngine implements CyclePredictionEngine {
  OpenCicloEngine({DateTime? referenceDate})
      : referenceDate =
            referenceDate == null ? null : calendarDate(referenceDate);

  // These are the aggregate values in the released mcPHASES artifact, not
  // guesses from a paper or a different population.
  static const populationMedian = 30.5;
  static const populationMad = 3.0;
  static const populationMean = 29.50769230769231;
  static const shrinkageK = 2.0;
  static const minimumScale = 0.75;
  static const minimumLength = 1;
  static const maximumLength = 90;

  final DateTime? referenceDate;

  @override
  String get name => 'OpenCiclo';

  @override
  bool get isActive => true;

  @override
  EngineOutput? predict(List<CycleRecord> history) {
    final lengths = completedCycleLengths(history);
    if (history.isEmpty) return null;

    final n = lengths.length;
    final weight = n / (n + shrinkageK);
    final personal = n == 0
        ? populationMedian
        : _median(lengths.map((e) => e.toDouble()).toList());

    // This is shrinkage. The prior matters most when there isn't much history.
    final point = weight * personal + (1 - weight) * populationMedian;
    var personalScale = populationMad;
    if (n >= 2) {
      final mad = _median(lengths.map((e) => (e - point).abs()).toList());
      personalScale =
          mad < 1e-9 ? minimumScale : math.max(mad / math.ln2, minimumScale);
    }
    final scale = math.max(
      weight * personalScale +
          (1 - weight) * math.max(populationMad, minimumScale),
      minimumScale,
    );

    final masses = <int, double>{};
    final closest =
        point.clamp(minimumLength.toDouble(), maximumLength.toDouble());
    final maximumLogMass = -(closest - point).abs() / scale;
    for (var day = minimumLength; day <= maximumLength; day++) {
      masses[day] = math.exp(-(day - point).abs() / scale - maximumLogMass);
    }
    final total = masses.values.fold<double>(0, (a, b) => a + b);
    for (final day in masses.keys.toList()) {
      masses[day] = masses[day]! / total;
    }

    final lastStart = history.last.startDate;
    final elapsed = referenceDate == null
        ? 0
        : calendarDaysBetween(lastStart, referenceDate!);
    final firstVisible = math.max(minimumLength, elapsed);
    final visible = <int, double>{
      for (final entry in masses.entries)
        if (entry.key >= firstVisible) entry.key: entry.value,
    };
    if (visible.isEmpty) {
      // Upstream uses a uniform display distribution once its support is past.
      final uniform = 1 / (maximumLength - minimumLength + 1);
      for (var i = 0; i <= maximumLength - minimumLength; i++) {
        visible[firstVisible + i] = uniform;
      }
    } else {
      final visibleTotal = visible.values.fold<double>(0, (a, b) => a + b);
      for (final day in visible.keys.toList()) {
        visible[day] = visible[day]! / visibleTotal;
      }
    }

    var modalLength = visible.keys.first;
    for (final entry in visible.entries) {
      if (entry.value > visible[modalLength]!) modalLength = entry.key;
    }
    final lower = _quantile(visible, 0.1);
    final upper = _quantile(visible, 0.9);
    final radius = math.max(modalLength - lower, upper - modalLength);

    // OpenCiclo exposes this exact +/-2-day probability; ELARA uses it as a
    // fusion weight. It is not a calibrated chance that the date is correct.
    final confidence = visible.entries
        .where((entry) => (entry.key - modalLength).abs() <= 2)
        .fold<double>(0, (sum, entry) => sum + entry.value)
        .clamp(0.0, 1.0);

    return EngineOutput(
      engineName: name,
      predictedDate: addCalendarDays(lastStart, modalLength),
      predictedLength: modalLength.toDouble(),
      confidence: confidence,
      windowDays: radius,
      lengthProbabilities: visible,
      modelPoint: point,
      modelScale: scale,
    );
  }
}

double _median(List<double> values) {
  values.sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}

int _quantile(Map<int, double> probabilities, double target) {
  var cumulative = 0.0;
  for (final entry in probabilities.entries) {
    cumulative += entry.value;
    if (cumulative >= target) return entry.key;
  }
  return probabilities.keys.last;
}
