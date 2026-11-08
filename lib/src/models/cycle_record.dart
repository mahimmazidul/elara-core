// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'calendar_date.dart';

/// One recorded period start and, if known, its bleeding duration in days.
class CycleRecord {
  CycleRecord({required DateTime startDate, this.periodDuration})
      : startDate = calendarDate(startDate) {
    if (periodDuration != null && periodDuration! < 1) {
      throw ArgumentError.value(
        periodDuration,
        'periodDuration',
        'must be positive',
      );
    }
  }

  final DateTime startDate;
  final int? periodDuration;
}

/// The engine contract requires oldest-to-newest starts with no duplicates.
List<int> completedCycleLengths(List<CycleRecord> history) {
  final lengths = <int>[];
  for (var i = 1; i < history.length; i++) {
    final length = calendarDaysBetween(
      history[i - 1].startDate,
      history[i].startDate,
    );
    if (length <= 0) {
      throw ArgumentError(
        'Cycle starts must be strictly increasing, with no duplicates.',
      );
    }
    lengths.add(length);
  }
  return lengths;
}
