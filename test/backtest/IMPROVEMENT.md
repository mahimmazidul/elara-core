# Experimental personal-history adjustment

## Result

The optional adjustment produced a small improvement in average error on a participant-held-out portion of the Utah/Creighton dataset. The improvement is uncertain: a participant-cluster bootstrap interval includes both a modest benefit and a slight worsening. Accordingly, the existing predictor remains the **default**, and the new adjustment is **experimental and opt-in**.

```dart
final prediction = ElaraFusion(experimentalPersonalization: true).predict(history);
```

On 731 held-out forecasts from 147 participants:

| Metric | Existing default | Experimental opt-in |
|---|---:|---:|
| Mean absolute error | 2.733 days | 2.692 days |
| Person-weighted mean absolute error | 2.977 days | 2.938 days |
| Exact day | 16.14% | 17.24% |
| Within ±1 day | 41.72% | 44.46% |
| Within ±2 days | 62.38% | 63.34% |
| Within ±3 days | 74.42% | 74.28% |
| In the returned window | 84.40% | 84.54% |
| Mean window radius | ±3.98 days | ±3.98 days |
| Mean signed error, positive is late | −0.11 days | −0.39 days |

The estimated reduction in forecast-weighted MAE is **0.041 days**, or about one hour. The 95% participant-cluster percentile bootstrap interval for the **candidate minus baseline** MAE is **−0.086 to +0.009 days**, based on 5,000 resamples. It includes zero; this experiment does not establish that the opt-in improves accuracy for the wider population. The selected candidate changed 241 of 731 point forecasts. The uncertainty radius and heuristic confidence score are unchanged, although the window moves with the adjusted point.

Among the six held-out targets longer than 50 days, average absolute error was 24.83 days for the baseline and 25.50 days for the candidate. This subgroup is too small for a reliable comparison, but it illustrates the need to assess long and irregular cycles rather than rely on the overall average. All long outcomes were retained in the primary metrics.

## Method

The original baseline and quality filters are described in `REPORT.md`. Before examining candidate results, `EXPERIMENT_PLAN.md` fixed a deterministic participant split: 350 development participants contributed 1,825 forecasts, and 147 different held-out participants contributed 731. Each participant's forecasts are kept together, and each walk-forward forecast uses only the current recorded start and earlier starts. The original full-cohort baseline had already been inspected, and upstream OpenCiclo developers had previously evaluated this cohort, so this is a held-out **subset**, not a wholly unseen external population.

A grid of 36 simple candidates was evaluated on development participants only. The selected candidate reduced development MAE from 3.145 to 3.111 days. Its point adjustment uses the median `m` of the `n` completed historical cycle lengths:

1. Calculate a shrinkage point `(n × m + 28) / (n + 1)`.
2. Combine 25% of the existing fused point with 75% of that point and round to a calendar day.
3. Restrict the change to at most three days in either direction from the existing point.

With no completed earlier cycle, the point remains unchanged. A confirmed observed start still wins unchanged. The same uncertainty radius, confidence score and contributing engine results are preserved; the score remains a heuristic, not a calibrated probability. The held-out results passed the preregistered minimum-MAE and noninferiority gates, but the estimated gain is small and its bootstrap interval crosses zero. We therefore retained the existing default.

The frozen test implementation was checked against `ElaraFusion(experimentalPersonalization: true)` on all 2,556 Utah forecasts, with identical dates, windows and scores. No Marquette records were used for selection or for this experiment.

## Scope and data rights

The [Utah dataset](https://hive.utah.edu/records/3zhb1-48n69) was created by Joseph Stanford and Shahpar Najmabadi and is distributed under CC BY-NC with attribution. The project owner reported separate permission for commercial use in this model's development; this does not confer permission on other users of the dataset. Anyone reproducing or using derived work should check the applicable terms and obtain permission where needed. The CSV and participant-level cases/predictions are not stored in this repository.

The source consists of historical US/Canadian fertility-care users, not a representative Bangladesh app population. This experiment covers next-period timing without symptoms, BBT or mucus; it does not validate clinical, ovulation or contraceptive use. The effect with custom engines or symptom-adjusted forecasts has not been evaluated. Further prospective, consented testing across intended users and cycle patterns is needed.

## Reproduce

From the repository root with Dart and Python, after obtaining the Utah CSV under applicable terms, use a private temporary directory:

```sh
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
dart pub get
python3 test/backtest/prepare_utah.py "$UTAH_CSV" > "$WORK/cases.jsonl" 2> "$WORK/audit.json"
python3 test/backtest/split_cases.py "$WORK/cases.jsonl" "$WORK/dev.jsonl" "$WORK/holdout.jsonl"
dart run test/backtest/walk_forward.dart < "$WORK/dev.jsonl" > "$WORK/dev-predictions.jsonl"
python3 test/backtest/select_candidate.py "$WORK/dev.jsonl" "$WORK/dev-predictions.jsonl" > "$WORK/selection.json"
dart run test/backtest/compare_forecasts.dart --verify-production < "$WORK/holdout.jsonl" > "$WORK/holdout-comparisons.jsonl"
python3 test/backtest/compare_results.py "$WORK/holdout-comparisons.jsonl" > "$WORK/holdout-summary.json"
cat "$WORK/selection.json"
cat "$WORK/holdout-summary.json"
```

`development-selection.json`, `development-comparison.json`, `split-counts.json` and `holdout-comparison.json` contain the aggregate recorded outputs. Participant-level intermediate files must remain private and must not be committed.
