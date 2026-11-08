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
  }) : predictedDate = calendarDate(predictedDate),
       lengthProbabilities = lengthProbabilities == null
           ? null
           : Map.unmodifiable(lengthProbabilities) {
    if (engineName.trim().isEmpty) {
      throw ArgumentError('engineName cannot be empty');
    }
    if (!predictedLength.isFinite || predictedLength <= 0) {
      throw ArgumentError.value(
        predictedLength,
        'predictedLength',
        'must be positive and finite',
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
