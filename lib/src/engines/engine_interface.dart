// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import '../models/cycle_record.dart';
import '../models/engine_output.dart';

abstract class CyclePredictionEngine {
  /// Human-readable engine name for attribution and result inspection.
  String get name;

  /// Whether the engine has been enabled and has its required inputs.
  bool get isActive;

  /// [history] is sorted oldest to newest. Null means no forecast is available.
  EngineOutput? predict(List<CycleRecord> history);
}
