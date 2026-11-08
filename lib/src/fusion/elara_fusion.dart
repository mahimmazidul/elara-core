// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'dart:math' as math;

import '../engines/drip_engine.dart';
import '../engines/engine_interface.dart';
import '../engines/flowlytics_engine.dart';
import '../engines/openciclo_engine.dart';
import '../models/calendar_date.dart';
import '../models/cycle_record.dart';
import '../models/engine_output.dart';
import '../models/prediction_result.dart';

/// Confidence-weighted consensus. Scores are not clinically calibrated.
class ElaraFusion {
  ElaraFusion({List<CyclePredictionEngine>? engines})
      : engines = List.unmodifiable(engines ??
            [
              OpenCicloEngine(),
              FlowlyticsEngine(),
              DripEngine(),
            ]);

  final List<CyclePredictionEngine> engines;

  PredictionResult? predict(List<CycleRecord> history) {
    completedCycleLengths(history);
    if (history.isEmpty) return null;
    final start = history.last.startDate;
    final results = <EngineOutput>[];
    for (final engine in engines) {
      if (!engine.isActive) continue;
      final result = engine.predict(history);
      if (result == null) continue;
      if (result.predictedDate !=
          addCalendarDays(start, result.predictedLength.round())) {
        throw StateError(
            '${engine.name} returned an inconsistent date and cycle length.');
      }
      results.add(result);
    }
    if (results.isEmpty) return null;

    // A reported period start is an observation, not a forecast to average.
    final observed = results.where((result) => result.observedStart).toList();
    if (observed.isNotEmpty) {
      final first = observed.first;
      if (observed
          .any((result) => result.predictedDate != first.predictedDate)) {
        throw StateError(
            'Engines reported conflicting observed period starts.');
      }
      return PredictionResult(
        predictedDate: first.predictedDate,
        cycleLength: first.predictedLength.round(),
        confidence: 1,
        windowDays: 0,
        contributingEngines: observed,
        isObserved: true,
      );
    }

    final weighted = results.where((result) => result.confidence > 0).toList();
    if (weighted.isEmpty) return null;
    if (weighted.length == 1) {
      final only = weighted.single;
      return PredictionResult(
        predictedDate: only.predictedDate,
        cycleLength: only.predictedLength.round(),
        confidence: only.confidence * 0.8,
        windowDays: only.windowDays,
        contributingEngines: weighted,
      );
    }

    final totalWeight =
        weighted.fold<double>(0, (sum, result) => sum + result.confidence);
    final mean = weighted.fold<double>(0,
            (sum, result) => sum + result.predictedLength * result.confidence) /
        totalWeight;
    final variance = weighted.fold<double>(0, (sum, result) {
          final difference = result.predictedLength - mean;
          return sum + result.confidence * difference * difference;
        }) /
        totalWeight;
    final meanWindow = weighted.fold<double>(
            0, (sum, result) => sum + result.confidence * result.windowDays) /
        totalWeight;
    final disagreement = math.sqrt(variance);
    final window = math.sqrt(variance + meanWindow * meanWindow).ceil();

    // If engines disagree wildly, confidence goes down. Disagreement is not
    // a feature. The scale of five days is an ELARA fusion choice, not a model.
    final averageConfidence = totalWeight / weighted.length;
    final confidence =
        (averageConfidence / (1 + disagreement / 5)).clamp(0.0, 1.0);
    final cycleLength = mean.round();
    return PredictionResult(
      predictedDate: addCalendarDays(start, cycleLength),
      cycleLength: cycleLength,
      confidence: confidence,
      windowDays: window,
      contributingEngines: weighted,
    );
  }
}
