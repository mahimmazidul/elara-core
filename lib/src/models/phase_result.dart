// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'calendar_date.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulatory,
  lutealEarly,
  lutealLate,
  unknown,
}

enum LutealSubphase { early, late }

/// Calendar-based estimates only. They cannot confirm ovulation or fertility.
class PhaseResult {
  const PhaseResult({
    required this.phase,
    required this.phaseDay,
    required this.cycleDay,
    required this.ovulationDay,
    required this.fertileWindow,
    required this.isFertile,
    required this.lutealSubphase,
    required this.daysUntilPeriod,
    required this.daysUntilOvulation,
  });

  final CyclePhase phase;
  final int? phaseDay;
  final int cycleDay;
  final int ovulationDay;
  final DateRange fertileWindow;

  /// Whether the date is in the modeled window; null when the cycle is overdue.
  /// This is not confirmation of fertility or infertility.
  final bool? isFertile;
  final LutealSubphase? lutealSubphase;

  /// Signed day counts: a negative value means the estimate is overdue/past.
  final int daysUntilPeriod;
  final int daysUntilOvulation;
}
