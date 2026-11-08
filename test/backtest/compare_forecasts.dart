// Compare the real baseline Dart ensemble to a frozen experimental candidate.
// Input/output contain participant-level data: keep them private.
import 'dart:convert';
import 'dart:io';

import 'package:elara_core/elara_core.dart';

import 'frozen_candidate.dart';

Map<String, Object> score(
    PredictionResult result, DateTime last, DateTime truth) {
  final error = result.predictedDate.difference(truth).inDays;
  if (result.predictedDate.difference(last).inDays != result.cycleLength ||
      result.isObserved ||
      result.window.contains(truth) != (error.abs() <= result.windowDays)) {
    throw StateError('Inconsistent forecast');
  }
  return {
    'prediction_length': result.cycleLength,
    'error_days': error,
    'window_days': result.windowDays,
    'score': result.confidence,
  };
}

Future<void> main() async {
  final baseline = historicalFusion();
  final candidate = FrozenCandidate();
  var count = 0;
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    final item = jsonDecode(line) as Map<String, dynamic>;
    final history = (item['history'] as List<dynamic>)
        .map(
            (day) => CycleRecord(startDate: DateTime.parse('${day}T00:00:00Z')))
        .toList();
    if (history.isEmpty) throw StateError('History is empty');

    // Predict before extracting target data.
    final before = baseline.predict(history);
    final after = candidate.predict(history);
    if (before == null || after == null) {
      throw StateError('Expected both forecasts');
    }
    final truth = DateTime.parse('${item['actual_next_start']}T00:00:00Z');
    final last = history.last.startDate;
    final actual = truth.difference(last).inDays;
    if (actual <= 0 || actual != item['reported_target_length']) {
      throw StateError('Bad or inconsistent target');
    }
    if ((after.cycleLength - before.cycleLength).abs() > 3 ||
        after.windowDays != before.windowDays ||
        after.confidence != before.confidence) {
      throw StateError('The frozen adjustment violated its constraints');
    }
    stdout.writeln(jsonEncode({
      'person': item['person'],
      'prior_completed_cycles': history.length - 1,
      'prior_range_days': item['prior_range_days'],
      'actual_length': actual,
      'baseline': score(before, last, truth),
      'candidate': score(after, last, truth),
    }));
    count++;
  }
  stderr.writeln('Compared $count participant forecasts.');
}
