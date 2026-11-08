// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

// Runs the actual elara_core implementations, not a Python reimplementation.
// Input and output are participant-level JSON lines; keep both local.
import 'dart:convert';
import 'dart:io';

import 'package:elara_core/elara_core.dart';

Map<String, Object> scoreEngine(
    EngineOutput out, DateTime last, DateTime truth) {
  final predicted = out.predictedDate;
  if (predicted.difference(last).inDays != out.predictedLength.round()) {
    throw StateError('Engine date and length disagree');
  }
  return {
    'prediction_length': out.predictedLength.round(),
    'error_days': predicted.difference(truth).inDays,
    'window_days': out.windowDays,
    'score': out.confidence,
  };
}

Map<String, Object> scoreLength(int length, DateTime last, DateTime truth) => {
      'prediction_length': length,
      'error_days': last.add(Duration(days: length)).difference(truth).inDays,
    };

Future<void> main() async {
  final fusion = ElaraFusion(); // Default settings; Drip has no BBT/mucus.
  final openciclo = OpenCicloEngine();
  final flowlytics = FlowlyticsEngine();
  var count = 0;

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final item = jsonDecode(line) as Map<String, dynamic>;
    final starts = (item['history'] as List<dynamic>)
        .map((day) => DateTime.parse('${day}T00:00:00Z'))
        .toList(growable: false);
    if (starts.isEmpty) throw StateError('An anchor start is required');
    final history = starts.map((date) => CycleRecord(startDate: date)).toList();
    final last = history.last.startDate;
    final prior = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final days = starts[i].difference(starts[i - 1]).inDays;
      if (days <= 0) throw StateError('History must strictly increase');
      prior.add(days);
    }

    // Make every forecast before extracting the future outcome. The target
    // length, next start, age and future rows never enter any prediction.
    final forecast = fusion.predict(history);
    final open = openciclo.predict(history);
    final flow = flowlytics.predict(history);
    if (forecast == null ||
        open == null ||
        flow == null ||
        forecast.isObserved) {
      throw StateError('Expected three non-observed forecasts');
    }
    final names =
        forecast.contributingEngines.map((e) => e.engineName).toList();
    if (names.join(',') != 'OpenCiclo,Flowlytics') {
      throw StateError('Unexpected default contributing engines: $names');
    }

    final truth = DateTime.parse('${item['actual_next_start']}T00:00:00Z');
    final actualLength = truth.difference(last).inDays;
    if (actualLength <= 0 || actualLength != item['reported_target_length']) {
      throw StateError('Invalid or inconsistent target');
    }
    if (forecast.predictedDate.difference(last).inDays !=
        forecast.cycleLength) {
      throw StateError('Fusion date and length disagree');
    }
    final error = forecast.predictedDate.difference(truth).inDays;
    final coveredByDate = !truth.isBefore(forecast.window.start) &&
        !truth.isAfter(forecast.window.end);
    if (coveredByDate != (error.abs() <= forecast.windowDays)) {
      throw StateError('Window coverage is inconsistent');
    }

    final sorted = [...prior]..sort();
    int? median;
    if (sorted.isNotEmpty) {
      final i = sorted.length ~/ 2;
      median = sorted.length.isOdd
          ? sorted[i]
          : ((sorted[i - 1] + sorted[i]) / 2).round();
    }
    final result = {
      'person': item['person'],
      'age_at_first_cycle': item['age_at_first_cycle'],
      'prior_completed_cycles': prior.length,
      'prior_range_days': item['prior_range_days'],
      'actual_length': actualLength,
      'elara': {
        'prediction_length': forecast.cycleLength,
        'error_days': error,
        'window_days': forecast.windowDays,
        'score': forecast.confidence,
      },
      'openciclo': scoreEngine(open, last, truth),
      'flowlytics': scoreEngine(flow, last, truth),
      'fixed28': scoreLength(28, last, truth),
      if (prior.isNotEmpty) 'last_cycle': scoreLength(prior.last, last, truth),
      if (median != null) 'personal_median': scoreLength(median, last, truth),
    };
    stdout.writeln(jsonEncode(result));
    count++;
  }
  stderr.writeln('Scored $count forecasts with elara_core.');
}
