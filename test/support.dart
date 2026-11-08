// Copyright (c) 2026 Md. Mazidul Islam Mahim
// ELARA-core — Ensemble Menstrual Cycle Prediction Engine
// https://github.com/mahimmazidul/elara-core
//
// Original work by the author. Not derived from any ported engine.
// Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
// The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

import 'package:elara_core/elara_core.dart';

DateTime day(DateTime start, int offset) =>
    DateTime.utc(start.year, start.month, start.day + offset);

List<CycleRecord> historyFor(List<int> lengths, {DateTime? first}) {
  final starts = <CycleRecord>[
    CycleRecord(startDate: first ?? DateTime.utc(2025, 1, 1)),
  ];
  for (final length in lengths) {
    starts.add(CycleRecord(startDate: day(starts.last.startDate, length)));
  }
  return starts;
}
