# Public-data backtest

`REPORT.md` records the original retrospective timing evaluation at commit `7457880b7d2c957de7aad103fabe79686fdf8a2d`. The two `*-audit.json` files and the two aggregate results JSON files preserve its inclusion counts and metrics. These files contain no raw participant records. Later model-development experiments, if any, are documented separately and must not be confused with this original baseline.

The [Utah/Creighton source](https://hive.utah.edu/records/3zhb1-48n69) is CC BY-NC with attribution; obtain additional permission when required for the intended use. The [Marquette source](https://epublications.marquette.edu/data_nfp/7/) states that participants consented to reuse, but does not clearly specify an open-data license. Check rights before use or redistribution. Do not commit the CSVs, person-level cases or predictions.

## Run the evaluation

From the repository root with Python 3 and Dart 3 installed:

```sh
dart pub get
dart analyze
python3 -m unittest discover -s test/backtest -p 'test_*.py' -v
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fL 'https://hive.utah.edu/records/3zhb1-48n69/files/CrMcyclelength_share.csv?download=1' -o "$WORK/utah.csv"
sha256sum "$WORK/utah.csv"
python3 test/backtest/prepare_utah.py "$WORK/utah.csv" > "$WORK/cases.jsonl" 2> "$WORK/audit.json"
dart run test/backtest/walk_forward.dart < "$WORK/cases.jsonl" > "$WORK/predictions.jsonl"
python3 test/backtest/summarize.py "$WORK/predictions.jsonl" > "$WORK/results.json"
cat "$WORK/audit.json"
cat "$WORK/results.json"
```

The original CSV's SHA-256 was `ad67a3eed731a038d6502a1eb42a9dcddf8f6c69a607a61b85f3798198043dac`. The evaluator calls the currently checked-out code. To reproduce the historical baseline precisely, create a separate checkout at commit `7457880b7d2c957de7aad103fabe79686fdf8a2d`, then copy the backtest scripts from this directory into that checkout before running them. Keep temporary files private: cases and predictions contain participant-level data.

## Marquette length-only check

The original analysis used a [third-party mirror pinned to commit `a328a640b253f54ba49e64239b03e83ae0c09a2e`](https://raw.githubusercontent.com/chiomajaco6/MenstrualCyclePrediction/a328a640b253f54ba49e64239b03e83ae0c09a2e/rawFedCycleData.csv), SHA-256 `985468f2db791a699f98ba437ee547d25f09a1aaeb82e792462e09a10a58a261`, because the publisher download was blocked. The mirror was spot-checked but not fully byte-verified against the publisher's version. Verify applicable data permissions before obtaining or using a copy. The script constructs arbitrary relative date anchors from recorded cycle lengths, since the file does not contain actual period-start dates:

```sh
python3 test/backtest/prepare_marquette.py "$MARQUETTE_CSV" > "$WORK/marquette-cases.jsonl" 2> "$WORK/marquette-audit.json"
dart run test/backtest/walk_forward.dart < "$WORK/marquette-cases.jsonl" > "$WORK/marquette-predictions.jsonl"
python3 test/backtest/summarize.py "$WORK/marquette-predictions.jsonl" > "$WORK/marquette-results.json"
```
