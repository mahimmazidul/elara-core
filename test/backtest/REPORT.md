# ELARA-core: retrospective public-data backtest

**Run:** 8 November 2026  
**Package:** `elara-core` commit `7457880b7d2c957de7aad103fabe79686fdf8a2d`  
**Runtime:** Dart 3.13.7; default `ElaraFusion()` settings, with no symptoms, temperature or mucus inputs.

## Bottom line

The actual Dart ensemble was tested on two public longitudinal datasets. On the stronger, date-verified Utah evaluation, the next-period estimate was off by **3.03 days on average** and was within three days of the next recorded start **75.0%** of the time. Its own variable-width prediction window contained the observed start **83.2%** of the time; its average radius was ±3.98 days. These are retrospective sample results, not guarantees or clinically validated probabilities.

The secondary Marquette check produced a 2.24-day average absolute error and 79.8% within three days. It is weaker evidence about dates: the source provides cycle lengths rather than actual start dates, so we reconstructed arbitrary date anchors from those recorded lengths. The copy used was a third-party mirror, not a byte-verified download from the publisher.

## Data and sources

**Primary — Utah/Creighton.** Stanford and Najmabadi, *Menstrual Cycles Length of Women in the USA and Canada, 1990–2013*, University of Utah Hive: [dataset](https://hive.utah.edu/records/3zhb1-48n69), [DOI](https://doi.org/10.7278/S50d-4gxs-s4hj), [source README and license](https://hive.utah.edu/records/3zhb1-48n69/files/Najmabadi_README20230824.txt?download=1). The official CSV has 3,324 cycle rows from 581 participants. The source README specifies **CC BY-NC**, requiring attribution and limiting licensed use to noncommercial purposes; check intended use and obtain permission where necessary. The source cohort consisted of fertility-care users in the US and Canada, generally aged 18–40 with regular bleeding at enrollment. The downloaded CSV's MD5 (`9fbde613a3bbe1799ddaebd2a192ecf8`) matches the publisher's listing; its SHA-256 is `ad67a3eed731a038d6502a1eb42a9dcddf8f6c69a607a61b85f3798198043dac`.

**Secondary — Marquette.** Fehring, *Menstrual Cycle Data* (2012), [Marquette University record](https://epublications.marquette.edu/data_nfp/7/). The publisher describes anonymized human-subject data and states that participants agreed to reuse; the page does not specify a clear open-data license. Verify permission before commercial use or redistribution. A publisher download was blocked by a Cloudflare challenge in the command-line environment, so this evaluation used a [public GitHub mirror pinned to commit `a328a640b253f54ba49e64239b03e83ae0c09a2e`](https://raw.githubusercontent.com/chiomajaco6/MenstrualCyclePrediction/a328a640b253f54ba49e64239b03e83ae0c09a2e/rawFedCycleData.csv), SHA-256 `985468f2db791a699f98ba437ee547d25f09a1aaeb82e792462e09a10a58a261`. Beginning, middle and end records were spot-checked against the publisher's file as accessed through the web reader, but the entire mirror was not cryptographically verified against it. This file contains 1,665 rows from 159 participant IDs; four IDs with duplicate cycle numbers were excluded entirely, removing 32 rows, including one conflicting length. A separate [published study](https://www.science.org/doi/10.1126/sciadv.adg9646) also identifies the Utah and Marquette records as sources of consecutive-cycle datasets, but this backtest uses its own exclusions and protocol.

The raw files and participant-level predictions are not included in this report or repository. Aggregate output and reproducibility scripts are in this evaluation folder.

## Protocol

For each eligible record, forecast at the most recent cycle start using only that start and earlier, consecutive recorded starts. Score against the subsequent outcome, then move forward. No target length, subsequent date, symptoms, demographic information or future record was given to the predictor. The actual `ElaraFusion`, `OpenCicloEngine`, and `FlowlyticsEngine` classes were called. In the default ensemble only OpenCiclo and Flowlytics contributed; drip was inactive without BBT and mucus data.

For Utah, the outcome is the next **recorded** period start. We require consecutive cycle numbers, strictly increasing dates, a current cycle documented as non-conception, and agreement between the measured next-start gap, the reported cycle length and the recorded end date. A sequence resets after a missing cycle number or inconsistency. There were 2,743 adjacent row pairs: 186 had nonconsecutive cycle numbers and one had a length/start discrepancy. The 581 terminal rows have no following row to score. This leaves **2,556 forecasts from 497 people**. All 41 eligible outcomes longer than 50 days were retained; targets were not filtered to Flowlytics' historical-input range. The file has 180 conception rows with missing length: a conception-cycle start can close the previous non-conception cycle, but no conception cycle is itself scored as a completed target.

For Marquette, only `ClientID`, `CycleNumber` and `LengthofCycle` were used. The first anchor date is artificial, and subsequent anchors are formed by adding already completed cycle lengths. The current cycle's reported length becomes the outcome only after the forecast. Cycle numbers must be consecutive; a next record is required and the last row of each participant is not scored. After excluding duplicate-number IDs, this yielded **1,478 forecasts from 144 people**. Calendar completeness, the meaning of all reproductive-category codes, and any participant overlap with the Utah study could not be independently established from these extracts.

The evaluation is conditional on a usable next outcome being recorded. In particular, it does not capture all missed logging, pregnancies, interrupted follow-up, or users whose cycles were not represented. All primary metrics weight each forecast equally; repeated forecasts from one person are correlated.

## Main results

| Metric | Utah/Creighton | Marquette, length-only |
|---|---:|---:|
| Participants with scored forecasts | 497 | 144 |
| Forecasts | 2,556 | 1,478 |
| Mean absolute error | 3.03 days | 2.24 days |
| Median absolute error | 2 days | 2 days |
| Exact day | 15.6% | 18.1% |
| Within ±1 day | 41.4% | 47.4% |
| Within ±2 days | 61.3% | 67.1% |
| Within ±3 days | 75.0% | 79.8% |
| Within ±5 days | 88.5% | 92.4% |
| Error greater than 7 days | 6.8% | 3.1% |
| In ELARA's returned window | 83.2% | 85.7% |
| Mean returned window radius | ±3.98 days | ±3.66 days |
| Person-weighted mean absolute error | 3.47 days | 2.59 days |

A radius of ±4 days means a nine-day inclusive calendar range around the predicted date. The returned radius varies across forecasts; it is not a fixed ±4-day promise. A participant-weighted MAE first averages errors for each person, then gives each person equal weight. The maximum Utah error was 68 days, illustrating that some forecasts can be much farther off than the average.

For Utah, a 3,000-replicate participant-cluster bootstrap gave a 95% percentile interval of **2.77–3.31 days** for forecast-weighted MAE and **81.4%–84.8%** for window coverage. For Marquette, the corresponding intervals were **2.03–2.46 days** and **83.6%–87.7%**. These reflect sampling uncertainty in these cohorts, not uncertainty about transport to another population.

## Baselines and history

All figures below are mean absolute errors in days. Comparisons within each row use exactly the same eligible forecasts.

| Evaluation subset | ELARA | Fixed 28-day cycle | OpenCiclo alone | Flowlytics alone | Last observed cycle | Median of prior cycles |
|---|---:|---:|---:|---:|---:|---:|
| Utah, all 2,556 forecasts | 3.03 | 3.59 | 3.13 | 3.17 | — | — |
| Utah, ≥1 previous completed cycle, 1,968 forecasts | 2.75 | 3.44 | 2.86 | 2.90 | 3.41 | 2.98 |
| Marquette, all 1,478 forecasts | 2.24 | 2.89 | 2.33 | 2.28 | — | — |
| Marquette, ≥1 previous completed cycle, 1,334 forecasts | 2.15 | 2.85 | 2.25 | 2.17 | 2.77 | 2.22 |

Last-cycle and historical-median baselines cannot be computed with no completed earlier cycle, so their fair comparisons are in the rows restricted to at least one. The personal median is rounded to the nearest day, with positive half-days rounded up. A fixed 28-day cycle means 28 days from the latest observed start.

For Utah, the 588 forecasts with no earlier completed cycle in their current contiguous segment had a 3.97-day MAE; 1,120 forecasts with at least three completed cycles had a 2.39-day MAE. These groups differ in who and what was observed, so this is an association, not proof that additional logging causes that improvement.

As an exploratory history-based variability split among Utah forecasts with at least three prior completed cycles, those whose past lengths spanned at most seven days had 1.84-day MAE (832 forecasts); those spanning more than seven days had 4.01-day MAE (288 forecasts). This range is an evaluation bin, not a clinical diagnosis. People may move between bins over time.

## Interpretation and limitations

The default ensemble performed better than the fixed-28-day and last-cycle baselines on these selected samples. Its confidence score and window are heuristics, however; the observed coverage is not evidence that an individual prediction has an 83% probability of being correct, and the ensemble does not specify a nominal 80% or 95% coverage level.

The Utah data were not part of OpenCiclo's released mcPHASES-derived population prior, but [OpenCiclo's developers previously used Utah for an external evaluation](https://github.com/OpenCiclo/OpenCiclo-web/blob/main/MODEL_CARD.md). Thus the Utah cohort is external to that released prior, but it is not a wholly unseen benchmark for the upstream project. We did not tune the package to either dataset during this evaluation.

These older North American fertility-care cohorts are not representative of all users, especially adolescents, people with irregular cycles or conditions affecting menstruation, people using hormonal contraception, or a Bangladeshi app population. The tests cover **next-period timing only**, not phase classification, ovulation, fertility, contraception, symptoms, environmental severity, or health outcomes. Prospective, consented evaluation in the intended population and clinical review are needed before making medical or contraception claims.

## Verification and reproduction

The independent harness checks that changing only the future outcome does not change the Dart forecast, and tests gap, discrepancy, duplicate and conception handling using synthetic fixtures. Three harness tests passed; `dart analyze` found no issues. Separately, the package's existing 108 tests passed and its analyzer was clean. No source logic was changed for this baseline backtest.

See `README.md` in this directory for reproducible commands, the adjacent files for the scripts, `utah-audit.json` and `marquette-audit.json` for aggregate inclusion counts, and `results.json` / `marquette-results.json` for detailed aggregate metrics and bootstrap intervals. The scripts intentionally do not bundle either source dataset.
