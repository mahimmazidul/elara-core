// Frozen development-selected candidate. Runs the existing Dart ensemble;
// this file lives in test/ and is not part of the public library API.
import 'dart:math' as math;

import 'package:elara_core/elara_core.dart';

// Explicit engines preserve the historical, unadjusted ensemble even if the
// library's default behavior changes in the future.
ElaraFusion historicalFusion() => ElaraFusion(engines: [
      OpenCicloEngine(),
      FlowlyticsEngine(),
      DripEngine(),
    ]);

class FrozenCandidate {
  final ElaraFusion _original = historicalFusion();

  PredictionResult? predict(List<CycleRecord> history) {
    final base = _original.predict(history);
    if (base == null || base.isObserved || history.length < 2) return base;
    final lengths = <int>[
      for (var i = 1; i < history.length; i++)
        history[i].startDate.difference(history[i - 1].startDate).inDays,
    ]..sort();
    if (lengths.any((n) => n <= 0)) {
      throw ArgumentError('Cycle starts must be strictly increasing.');
    }
    final n = lengths.length;
    final median = n.isOdd
        ? lengths[n ~/ 2].toDouble()
        : (lengths[n ~/ 2 - 1] + lengths[n ~/ 2]) / 2;
    // Chosen on development participants only: prior 28, strength 1,
    // candidate blend .75. Point change bounded to 3 days.
    final historyPoint = (n * median + 28) / (n + 1);
    final newPoint = (0.25 * base.cycleLength + 0.75 * historyPoint).round();
    final capped = math.max(
        base.cycleLength - 3, math.min(base.cycleLength + 3, newPoint));
    return PredictionResult(
      predictedDate: history.last.startDate.add(Duration(days: capped)),
      cycleLength: capped,
      windowDays: base.windowDays,
      confidence: base.confidence,
      contributingEngines: base.contributingEngines,
    );
  }
}
