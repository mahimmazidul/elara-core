import '../models/cycle_record.dart';
import '../models/engine_output.dart';

abstract class CyclePredictionEngine {
  String get name;
  bool get isActive;

  /// [history] is sorted oldest to newest. Null means no forecast is available.
  EngineOutput? predict(List<CycleRecord> history);
}
