// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'calendar_date.dart';

/// A model's forecast. Confidence is an engine-specific score, not a diagnosis.
class EngineOutput {
  EngineOutput({
    required this.engineName,
    required DateTime predictedDate,
    required this.predictedLength,
    required this.confidence,
    required this.windowDays,
    this.observedStart = false,
    Map<int, double>? lengthProbabilities,
    this.modelPoint,
    this.modelScale,
  })  : predictedDate = calendarDate(predictedDate),
        lengthProbabilities = lengthProbabilities == null
            ? null
            : Map.unmodifiable(lengthProbabilities) {
    if (engineName.trim().isEmpty) {
      throw ArgumentError('engineName cannot be empty');
    }
    if (!predictedLength.isFinite || predictedLength < 1) {
      throw ArgumentError.value(
        predictedLength,
        'predictedLength',
        'must be finite and at least one day',
      );
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0 and 1',
      );
    }
    if (windowDays < 0) {
      throw ArgumentError.value(
        windowDays,
        'windowDays',
        'must not be negative',
      );
    }
  }

  final String engineName;
  final DateTime predictedDate;
  final double predictedLength;
  final double confidence;
  final int windowDays;

  /// A caller explicitly reported a new period start, not merely a symptom.
  final bool observedStart;

  /// For engines which produce a distribution over cycle lengths.
  final Map<int, double>? lengthProbabilities;
  final double? modelPoint;
  final double? modelScale;
}
