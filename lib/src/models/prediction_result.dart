// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

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
  })  : predictedDate = calendarDate(predictedDate),
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
