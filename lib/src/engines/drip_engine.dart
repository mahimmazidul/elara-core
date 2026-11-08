// Original work: drip and sympto by the bloodyhealth contributors
// https://gitlab.com/bloodyhealth/drip
// https://gitlab.com/bloodyhealth/sympto
// Original licenses: GPL-3.0-or-later and AGPL-3.0-or-later, respectively.
//
// Sympto-thermal detection logic ported to Dart by Md. Mazidul Islam Mahim, 2026.
// The period prediction bridge (_builtInBridge) is original ELARA work by
// Md. Mazidul Islam Mahim; it is an ELARA heuristic, not part of drip's method.
// See ATTRIBUTION.md for full details.

// Adapted from bloodyhealth/drip and its sympto 3.0.2 library.
// SPDX-License-Identifier: AGPL-3.0-or-later
// See ATTRIBUTION.md and LICENSES/ for sources, authors and license notices.

import 'dart:math' as math;

import '../models/calendar_date.dart';
import '../models/cycle_record.dart';
import '../models/engine_output.dart';
import 'engine_interface.dart';

/// A temperature reading in degrees Celsius. Excluded readings are not used.
class BbtReading {
  BbtReading(
      {required DateTime date, required this.celsius, this.excluded = false})
      : date = calendarDate(date) {
    if (!celsius.isFinite || celsius <= 0) {
      throw ArgumentError.value(
          celsius, 'celsius', 'must be positive and finite');
    }
  }

  final DateTime date;
  final double celsius;
  final bool excluded;
}

/// A drip/NFP mucus quality from 0 to 4. Excluded readings are not used.
class MucusReading {
  MucusReading(
      {required DateTime date, required this.quality, this.excluded = false})
      : date = calendarDate(date) {
    if (quality < 0 || quality > 4) {
      throw ArgumentError.value(quality, 'quality', 'must be between 0 and 4');
    }
  }

  final DateTime date;
  final int quality;
  final bool excluded;
}

/// Converts drip's feeling/texture inputs to NFP quality, or null if incomplete.
int? nfpMucusQuality(int? feeling, int? texture) {
  if (feeling == null || texture == null) return null;
  const feelingValues = [0, 1, 2, 4];
  const textureValues = [0, 3, 4];
  if (feeling < 0 ||
      feeling >= feelingValues.length ||
      texture < 0 ||
      texture >= textureValues.length) {
    throw ArgumentError('Invalid mucus feeling or texture category.');
  }
  return math.max(feelingValues[feeling], textureValues[texture]);
}

/// One recorded day for the standalone symptothermal detector.
/// The first day in each cycle is understood to be a recorded period start.
class DripCycleDay {
  DripCycleDay({required DateTime date, this.temperature, this.mucus})
      : date = calendarDate(date) {
    if (temperature != null && (!temperature!.isFinite || temperature! <= 0)) {
      throw ArgumentError.value(
          temperature, 'temperature', 'must be positive and finite');
    }
    if (mucus != null && (mucus! < 0 || mucus! > 4)) {
      throw ArgumentError.value(mucus, 'mucus', 'must be between 0 and 4');
    }
  }

  final DateTime date;
  final double? temperature;
  final int? mucus;
}

/// The phase and shift findings of the symptothermal rules.
///
/// [ovulationDetected] means both required shifts completed; it does not prove
/// ovulation occurred. [estimatedOvulationDate] is ELARA's proxy (the first
/// higher temperature), not an ovulation date supplied by drip. Confidence is
/// an ELARA evidence score, not a validated medical probability.
class DripDetectionResult {
  const DripDetectionResult({
    required this.cycleStartDate,
    required this.ovulationDetected,
    required this.estimatedOvulationDate,
    required this.temperatureShiftDay,
    required this.temperatureEvaluationComplete,
    required this.temperatureRule,
    required this.coverLine,
    required this.mucusPeakDay,
    required this.mucusEvaluationComplete,
    required this.preOvulatoryPhase,
    required this.periOvulatoryStart,
    required this.fertilePhase,
    required this.postOvulatoryStart,
    required this.confidence,
  });

  final DateTime cycleStartDate;
  final bool ovulationDetected;
  final DateTime? estimatedOvulationDate;
  final DateTime? temperatureShiftDay;
  final DateTime? temperatureEvaluationComplete;

  /// 0 = regular, 1 = first exception, 2 = second exception.
  final int? temperatureRule;
  final double? coverLine;
  final DateTime? mucusPeakDay;
  final DateTime? mucusEvaluationComplete;
  final DateRange? preOvulatoryPhase;

  /// Null if the recorded cycle has not yet left its pre-ovulatory phase.
  final DateTime? periOvulatoryStart;

  /// Null when the peri-ovulatory phase is open-ended or has not yet started.
  final DateRange? fertilePhase;

  /// The post-ovulatory phase starts at 18:00 on this date in upstream sympto.
  final DateTime? postOvulatoryStart;
  final double confidence;
}

typedef PeriodBridgeFn = EngineOutput? Function(DripDetectionResult detection);

class DripEngineConfig {
  const DripEngineConfig({
    this.enabled = false,
    this.useBuiltInBridge = false,
  });

  final bool enabled;

  /// Opts into an ELARA heuristic. Drip itself does not predict a period date.
  final bool useBuiltInBridge;
}

/// Dormant until enabled and both series contain at least one usable reading.
class DripEngine implements CyclePredictionEngine {
  DripEngine({
    this.config = const DripEngineConfig(),
    List<BbtReading>? bbt,
    List<MucusReading>? mucus,
    this.periodBridge,
  })  : bbt = bbt == null ? null : List.unmodifiable(bbt),
        mucus = mucus == null ? null : List.unmodifiable(mucus) {
    _ensureUniqueDays(bbt?.map((e) => e.date) ?? const [], 'BBT');
    _ensureUniqueDays(mucus?.map((e) => e.date) ?? const [], 'mucus');
  }

  final DripEngineConfig config;
  final List<BbtReading>? bbt;
  final List<MucusReading>? mucus;
  final PeriodBridgeFn? periodBridge;

  @override
  String get name => 'drip';

  @override
  bool get isActive =>
      config.enabled &&
      bbt != null &&
      mucus != null &&
      bbt!.any((reading) => !reading.excluded) &&
      mucus!.any((reading) => !reading.excluded);

  /// Analyze all available observations for the most recent cycle.
  DripDetectionResult? detect(List<CycleRecord> history) {
    if (!isActive) return null;
    completedCycleLengths(history);
    if (history.isEmpty) return null;

    final days = <DateTime, _DayBuilder>{};
    for (final start in history) {
      days.putIfAbsent(start.startDate, () => _DayBuilder(start.startDate));
    }
    for (final reading in bbt!) {
      final day =
          days.putIfAbsent(reading.date, () => _DayBuilder(reading.date));
      if (!reading.excluded) day.temperature = reading.celsius;
    }
    for (final reading in mucus!) {
      final day =
          days.putIfAbsent(reading.date, () => _DayBuilder(reading.date));
      if (!reading.excluded) day.mucus = reading.quality;
    }
    final sorted = days.values.map((e) => e.build()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final cycles = <List<DripCycleDay>>[];
    for (var i = 0; i < history.length; i++) {
      final start = history[i].startDate;
      final end = i + 1 < history.length ? history[i + 1].startDate : null;
      cycles.add(sorted
          .where((day) =>
              !day.date.isBefore(start) &&
              (end == null || day.date.isBefore(end)))
          .toList());
    }
    return SymptoThermalDetector().detect(
      cycles.last,
      previousCycle: cycles.length > 1 ? cycles[cycles.length - 2] : null,
      earlierCycles: cycles.length > 2
          ? cycles.sublist(0, cycles.length - 2).reversed.toList()
          : const [],
    );
  }

  @override
  EngineOutput? predict(List<CycleRecord> history) {
    final detection = detect(history);
    if (detection == null) return null;
    final bridge = periodBridge;
    final result = bridge != null
        ? bridge(detection)
        : config.useBuiltInBridge
            ? _builtInBridge(detection)
            : null;
    if (result == null) return null;
    if (result.observedStart) {
      throw StateError(
          'A symptothermal bridge cannot mark a period start as observed.');
    }
    final expected = addCalendarDays(
        detection.cycleStartDate, result.predictedLength.round());
    if (result.predictedDate != expected) {
      throw StateError(
          'The bridge date must match its cycle length and recorded start.');
    }
    return EngineOutput(
      engineName: name,
      predictedDate: result.predictedDate,
      predictedLength: result.predictedLength,
      confidence: result.confidence,
      windowDays: result.windowDays,
      lengthProbabilities: result.lengthProbabilities,
      modelPoint: result.modelPoint,
      modelScale: result.modelScale,
    );
  }

  EngineOutput? _builtInBridge(DripDetectionResult detection) {
    final proxy = detection.estimatedOvulationDate;
    if (!detection.ovulationDetected || proxy == null) return null;

    // ELARA heuristic, not drip: first higher temperature as an approximate
    // ovulation proxy, then +14 days. This is experimental and unvalidated.
    final prediction = addCalendarDays(proxy, 14);
    final length = calendarDaysBetween(detection.cycleStartDate, prediction);
    if (length <= 0) return null;
    return EngineOutput(
      engineName: name,
      predictedDate: prediction,
      predictedLength: length.toDouble(),
      confidence: detection.confidence * 0.5,
      windowDays: 4,
    );
  }
}

/// Core mucus-and-temperature portion of sympto 3.0.2, including the 5-day
/// and minus-8 pre-ovulatory rules. This intentionally does not use cervix data.
class SymptoThermalDetector {
  DripDetectionResult detect(
    List<DripCycleDay> cycle, {
    List<DripCycleDay>? previousCycle,
    List<List<DripCycleDay>> earlierCycles = const [],
  }) {
    _validateCycle(cycle);
    if (previousCycle != null) _validateCycle(previousCycle);
    for (final earlier in earlierCycles) {
      _validateCycle(earlier);
    }

    DateRange? prePhase;
    if (previousCycle != null && _combinedShift(previousCycle) != null) {
      final previous = [previousCycle, ...earlierCycles];
      final firstHighDays = <int>[];
      for (final past in previous) {
        final shift = _combinedShift(past);
        if (shift != null) {
          firstHighDays.add(calendarDaysBetween(
                  past.first.date, shift.temperature.firstHigh.date) +
              1);
        }
      }
      var preLength = 5;
      if (firstHighDays.isNotEmpty) {
        final minusEight = firstHighDays.reduce(math.min) - 8;
        if (minusEight < 5 || firstHighDays.length >= 12) {
          preLength = minusEight;
        }
      }
      if (preLength > 0) {
        final scheduledEnd = addCalendarDays(cycle.first.date, preLength - 1);
        final candidates = cycle
            .take(preLength)
            .where((day) => !day.date.isAfter(scheduledEnd))
            .toList();
        final fertileIndex =
            candidates.indexWhere((day) => day.mucus != null && day.mucus! > 1);
        final preDays = fertileIndex < 0
            ? candidates
            : candidates.take(fertileIndex).toList();
        if (preDays.isNotEmpty) {
          final end = preDays.length == candidates.length
              ? scheduledEnd
              : preDays.last.date;
          prePhase = DateRange(cycle.first.date, end);
          if (preDays.length == cycle.length) {
            return _buildDetection(cycle, prePhase, null, null, null);
          }
        }
      }
    }

    final periStart =
        prePhase == null ? cycle.first.date : addCalendarDays(prePhase.end, 1);
    final temperature = _temperatureShift(cycle);
    final mucus = temperature == null
        ? null
        : _mucusShift(cycle, temperature.evaluationComplete);
    return _buildDetection(cycle, prePhase, periStart, temperature, mucus);
  }
}

DripDetectionResult _buildDetection(
  List<DripCycleDay> cycle,
  DateRange? prePhase,
  DateTime? periStart,
  _TemperatureShift? temperature,
  _MucusShift? mucus,
) {
  final both = temperature != null && mucus != null;
  DateTime? end;
  if (both) {
    end = temperature.evaluationComplete.date
            .isAfter(mucus.evaluationComplete.date)
        ? temperature.evaluationComplete.date
        : mucus.evaluationComplete.date;
  }
  return DripDetectionResult(
    cycleStartDate: cycle.first.date,
    ovulationDetected: both,
    estimatedOvulationDate: both ? temperature.firstHigh.date : null,
    temperatureShiftDay: temperature?.firstHigh.date,
    temperatureEvaluationComplete: temperature?.evaluationComplete.date,
    temperatureRule: temperature?.rule,
    coverLine: temperature?.coverLine,
    mucusPeakDay: mucus?.peak.date,
    mucusEvaluationComplete: mucus?.evaluationComplete.date,
    preOvulatoryPhase: prePhase,
    periOvulatoryStart: periStart,
    fertilePhase:
        periStart != null && end != null ? DateRange(periStart, end) : null,
    postOvulatoryStart: end,
    confidence: both ? 0.5 : 0.0,
  );
}

class _TemperatureShift {
  const _TemperatureShift(
      this.firstHigh, this.evaluationComplete, this.coverLine, this.rule);
  final DripCycleDay firstHigh;
  final DripCycleDay evaluationComplete;
  final double coverLine;
  final int rule;
}

class _MucusShift {
  const _MucusShift(this.peak, this.evaluationComplete);
  final DripCycleDay peak;
  final DripCycleDay evaluationComplete;
}

class _CombinedShift {
  const _CombinedShift(this.temperature, this.mucus);
  final _TemperatureShift temperature;
  final _MucusShift mucus;
}

_CombinedShift? _combinedShift(List<DripCycleDay> cycle) {
  final temperature = _temperatureShift(cycle);
  if (temperature == null) return null;
  final mucus = _mucusShift(cycle, temperature.evaluationComplete);
  return mucus == null ? null : _CombinedShift(temperature, mucus);
}

_TemperatureShift? _temperatureShift(List<DripCycleDay> cycle) {
  final readings = cycle.where((day) => day.temperature != null).toList();
  final rounded =
      readings.map((day) => (day.temperature! * 20).round() / 20).toList();
  for (var i = 6; i < readings.length; i++) {
    final cover = rounded.sublist(i - 6, i).reduce(math.max);
    if (rounded[i] <= cover || i + 2 >= readings.length) continue;
    final second = rounded[i + 1];
    final third = rounded[i + 2];
    if (second > cover && third > cover && third - cover >= 0.2 - 0.0001) {
      return _TemperatureShift(readings[i], readings[i + 2], cover, 0);
    }
    if (i + 3 >= readings.length) continue;
    final fourth = rounded[i + 3];
    if (second > cover && third > cover && fourth > cover) {
      return _TemperatureShift(readings[i], readings[i + 3], cover, 1);
    }
    final secondLow = second <= cover;
    final thirdLow = third <= cover;
    if (secondLow != thirdLow && fourth - cover >= 0.2 - 0.0001) {
      return _TemperatureShift(readings[i], readings[i + 3], cover, 2);
    }
  }
  return null;
}

_MucusShift? _mucusShift(List<DripCycleDay> cycle, DripCycleDay tempEnd) {
  final observations = cycle.where((day) => day.mucus != null).toList();
  var best = 0;
  final tempEndIndex = cycle.indexOf(tempEnd);
  for (var i = 0; i < observations.length; i++) {
    final day = observations[i];
    best = math.max(best, day.mucus!);
    if (best < 2 || day.mucus != best || i + 3 >= observations.length) continue;
    final following = observations.sublist(i + 1, i + 4);
    if (following.any((next) => next.mucus! >= best)) continue;
    final peakIndex = cycle.indexOf(day);
    var noLaterPeakBeforeTempEnd = true;
    for (var j = peakIndex + 1; j <= tempEndIndex; j++) {
      final value = cycle[j].mucus;
      if (value != null && value >= best) {
        noLaterPeakBeforeTempEnd = false;
        break;
      }
    }
    if (noLaterPeakBeforeTempEnd) return _MucusShift(day, following.last);
  }
  return null;
}

void _validateCycle(List<DripCycleDay> cycle) {
  if (cycle.isEmpty) {
    throw ArgumentError('A symptothermal cycle must not be empty.');
  }
  for (var i = 1; i < cycle.length; i++) {
    if (!cycle[i].date.isAfter(cycle[i - 1].date)) {
      throw ArgumentError(
          'Symptothermal days must be strictly ordered and unique.');
    }
  }
}

void _ensureUniqueDays(Iterable<DateTime> dates, String kind) {
  final seen = <DateTime>{};
  for (final day in dates) {
    if (!seen.add(day)) throw ArgumentError('Duplicate $kind reading on $day.');
  }
}

class _DayBuilder {
  _DayBuilder(this.date);
  final DateTime date;
  double? temperature;
  int? mucus;
  DripCycleDay build() =>
      DripCycleDay(date: date, temperature: temperature, mucus: mucus);
}
