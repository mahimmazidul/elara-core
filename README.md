# elara-core

elara-core is a pure Dart library for combining menstrual-cycle forecasts,
estimating a cycle phase, and offering optional environmental and action
prompts. It runs locally, has no runtime package dependencies, and makes no
network calls. Predictions and scores are estimates, not facts about a person.

## Why it exists

ELARA is intended for an offline-first, partner-facing app, including use in
Bangladesh where heat, air quality and seasonal conditions can matter to daily
comfort. The core is separate from the app so that cycle data can be processed
on the device without an account or external prediction service. Suggestions
are starting points for a respectful conversation, not a substitute for
asking what someone actually wants.

## How it works

By default the ensemble runs OpenCiclo's released population-prior shrinkage
model and Flowlytics' recency-weighted predictor. Each returns a cycle length,
a score and a window. Fusion weights lengths by those scores, widens the
window when engines disagree, and reduces confidence when there is only one
contributor or the results differ. A caller-confirmed new period start takes
precedence over forecasts. The engines' scores have different meanings and
are **not calibrated probabilities**; the combined confidence and window
have not been clinically validated.

Vani was inspected but skipped: its mean and weighted-mean strategies do not
add a distinct method. drip's symptothermal detector is included but dormant
by default. Its temperature and mucus rules produce fertility-phase findings,
not a next-period forecast. Even with both series supplied and the engine
enabled, it contributes to fusion only when the caller supplies a
`PeriodBridgeFn` or explicitly opts into ELARA's experimental bridge. That
bridge treats the first higher-temperature day as an approximate ovulation
proxy and adds 14 days; it is not drip's method. Its evidence score of 0.5,
0.5 bridge penalty and four-day window are engineering assumptions, not
clinical estimates. The detector exposes the qualifying temperature and mucus
shifts, their completion dates, and the phase boundaries; the post-ovulatory
boundary is at 18:00 on the indicated day, as in sympto.

The phase classifier uses fixed calendar arithmetic and a 14-day luteal
assumption. Its fertile window is only a model estimate, can overlap bleeding,
and cannot confirm ovulation or fertility. On or after the predicted start
date, the phase and `isFertile` become unknown unless a new start is recorded.
The classifier requires an estimated cycle length of at least 15 days. The
package is not a medical device, diagnostic tool, or contraceptive method;
do not use it to make pregnancy-prevention or other medical decisions.

Environmental modifiers follow the supplied thresholds; AQI category and
humidity are accepted but have no independently specified coefficients. The
climate modifier is capped at +0.5, so with the default base severity of zero
it cannot trigger the action rule for severity above 0.6. A caller may supply
an explicit baseline where appropriate. The resulting severity is an additive
index, not a probability, and can be negative or exceed one. The action table
has no rule for menstrual days after day five or for an unknown phase, so it
returns no action in those cases. Its scores are generic prompts, not a
measurement of mood, desire or consent.

## How to use it

Provide period starts in strictly increasing order. Dates are treated as
calendar days: their year, month and day fields are preserved and returned
as UTC-midnight `DateTime` values, avoiding daylight-saving shifts. No system
clock is read by the forecasting engines; choose the phase date explicitly.

```dart
import 'package:elara_core/elara_core.dart';

void main() {
  final history = [
    CycleRecord(startDate: DateTime.utc(2026, 1, 1)),
    CycleRecord(startDate: DateTime.utc(2026, 1, 29)),
    CycleRecord(startDate: DateTime.utc(2026, 2, 26)),
    CycleRecord(startDate: DateTime.utc(2026, 3, 26)),
    CycleRecord(startDate: DateTime.utc(2026, 4, 23), periodDuration: 5),
  ];

  final prediction = ElaraFusion().predict(history);
  if (prediction == null) return;

  final phase = PhaseClassifier().classify(
    lastPeriod: history.last,
    cycleLength: prediction.cycleLength,
    date: DateTime.utc(2026, 4, 26),
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
  final action = ActionEngine().recommend(phase: phase, severity: severity);

  print('Estimated next start: ${prediction.predictedDate}');
  print('Estimated phase: ${phase.phase}');
  print('Food ideas: ${action?.foodSuggestions}');
}
```

If `prediction.isObserved` is true, the date is a caller-confirmed new start,
not a future forecast. Add that start to the history before continuing the
pipeline. A prediction can otherwise be in the past if no recent period has
been recorded. `OpenCicloEngine(referenceDate: ...)` can condition its own
distribution on an explicit as-of date; Flowlytics does not do this.

To use the optional ELARA drip bridge with real observations, construct it
explicitly and include it in a custom ensemble:

```dart
DripEngine makeDrip(List<BbtReading> bbt, List<MucusReading> mucus) {
  return DripEngine(
    config: const DripEngineConfig(enabled: true, useBuiltInBridge: true),
    bbt: bbt,
    mucus: mucus,
  );
}
```

Pass that engine in `ElaraFusion(engines: [OpenCicloEngine(),
FlowlyticsEngine(), makeDrip(bbt, mucus)])`. Both series must be non-null
and each must contain at least one non-excluded reading. Insufficient usable
observations do not produce a built-in forecast. Excluded readings are ignored;
as in upstream sympto, the rules operate on
recorded observations, which are not necessarily consecutive calendar days.
A supplied `periodBridge` takes precedence over the built-in bridge. With no
bridge, `drip.detect(history)` still exposes its findings but `predict`
returns null. `ovulationDetected` means the two method rules were satisfied;
it is not proof that ovulation occurred.

## Running tests

Install Dart 3.0 or later, then run:

```sh
dart pub get
dart analyze
dart test
```

The tests include fixtures checked against OpenCiclo's released model and
sympto 3.0.2, along with fusion, boundary and full-pipeline tests.

## Attribution

The upstream projects, their exact inspected revisions, and their licenses
are listed in [ATTRIBUTION.md](ATTRIBUTION.md).

## License

The combined package is distributed under [AGPL-3.0](LICENSE). The upstream
Apache-2.0, GPL-3.0-or-later and AGPL-3.0-or-later notices and license texts
are retained in [LICENSES](LICENSES/). See [NOTICE](NOTICE).
