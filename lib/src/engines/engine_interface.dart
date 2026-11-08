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
