# elara-core

elara-core is a pure Dart package that combines open-source menstrual cycle prediction methods into an ensemble for the Elara app. It is maintained by Md. Mazidul Islam Mahim.

## Why it exists

Elara is an offline, partner-facing menstrual cycle tracker built for husbands. The app runs entirely on-device, and this package is its prediction and decision engine. Bangladesh's heat index, humidity and air quality are part of the environmental inputs, with heat index and PM2.5 contributing to the severity calculation.

## How it works

OpenCiclo and Flowlytics run independently on the same period-start history. Their cycle-length predictions are weighted by confidence and merged into a forecast with an uncertainty window. OpenCiclo contributes a Bayesian shrinkage estimate based on a released population prior. Flowlytics contributes a recency-weighted average and symptom-based adjustments.

drip is dormant by default and, when enabled with temperature and mucus readings, contributes symptothermal shift analysis and can use an opt-in ELARA bridge for a period estimate. The Vani review found a weighted mean that overlaps Flowlytics.

The forecast feeds a deterministic phase classifier, an environmental severity calculation, and an action engine that returns conversation and romance scores, food ideas and cards. The severity calculation uses heat index, PM2.5, sunshine, season and hydration, while humidity and AQI category remain available as context. Confidence values are heuristic scores, and the fertile window is a calendar estimate.

## Using it

```dart
import 'package:elara_core/elara_core.dart';

void main() {
  final starts = [
    DateTime.utc(2026, 1, 1),
    DateTime.utc(2026, 1, 29),
    DateTime.utc(2026, 2, 26),
    DateTime.utc(2026, 3, 26),
  ];
  final history = starts.map((date) => CycleRecord(startDate: date)).toList();
  final prediction = ElaraFusion().predict(history)!;
  final phase = PhaseClassifier().classify(
    lastPeriod: history.last,
    cycleLength: prediction.cycleLength,
    date: DateTime.utc(2026, 3, 29),
  );
  final severity = SeverityModifier().calculate(
    EnvironmentConditions(
      heatIndex: 39,
      pm25: 70,
      aqiCategory: 3,
      sunshineHours: 4,
      season: Season.preMonsoon,
      hydrationLevel: 2,
    ),
    baseSeverity: 0.3,
  );
  final action = ActionEngine().recommend(phase: phase, severity: severity)!;

  print('Next start: ${prediction.predictedDate}, window: ${prediction.windowDays} days');
  print('Confidence: ${prediction.confidence}, phase: ${phase.phase}');
  print('Severity: ${severity.severityScore}');
  for (final card in action.cards) {
    print('${card.title}: ${card.body}');
  }
}
```

## Running the tests

Run `dart pub get && dart analyze && dart test` from the package directory.
A passing run reports a clean analysis and ends with `All tests passed!`.

## Attribution

The source projects and their licenses are listed in [ATTRIBUTION.md](ATTRIBUTION.md).

## License

The combined package is distributed under [AGPL-3.0](LICENSE).
