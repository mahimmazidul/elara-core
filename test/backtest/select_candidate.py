#!/usr/bin/env python3
"""Select the predeclared history adjustment using development participants only.

Input is the private output of prepare_utah.py and the matching predictions
from the unmodified Dart engine. The resulting JSON contains aggregates only.
See EXPERIMENT_PLAN.md. This is experimental selection, not the production
predictor; any selected adjustment must be checked in actual Dart on holdout.
"""
import argparse
import datetime as dt
import itertools
import json
import math
import statistics
from pathlib import Path

from split_cases import partition

PRIORS = (28, 29, 30)
STRENGTHS = (1, 2, 4)
BLENDS = (0.25, 0.50, 0.75, 1.00)
MAX_SHIFT = 3


def dart_round_positive(value):
    # Dart's round() rounds positive half-values away from zero.
    return math.floor(value + 0.5)


def adjusted(base, prior_lengths, prior, strength, blend):
    if not prior_lengths:
        return base
    n = len(prior_lengths)
    personal = statistics.median(prior_lengths)
    target = (n * personal + strength * prior) / (n + strength)
    candidate = dart_round_positive((1 - blend) * base + blend * target)
    return max(base - MAX_SHIFT, min(base + MAX_SHIFT, candidate))


def load_rows(cases_path, predictions_path):
    cases = [json.loads(line) for line in Path(cases_path).read_text().splitlines() if line.strip()]
    predictions = [json.loads(line) for line in Path(predictions_path).read_text().splitlines() if line.strip()]
    if len(cases) != len(predictions):
        raise ValueError("Mismatched number of cases and predictions")
    output = []
    for case, pred in zip(cases, predictions):
        if partition(case["person"]) != "development":
            raise ValueError("Holdout participant supplied to selection; refusing to tune")
        if case["person"] != pred["person"]:
            raise ValueError("Cases and predictions out of order")
        starts = [dt.date.fromisoformat(day) for day in case["history"]]
        lengths = [(b-a).days for a, b in zip(starts, starts[1:])]
        target = (dt.date.fromisoformat(case["actual_next_start"]) - starts[-1]).days
        if target != pred["actual_length"] or target != case["reported_target_length"]:
            raise ValueError("Target mismatch")
        output.append((pred["elara"]["prediction_length"], lengths, target,
                       pred["elara"]["window_days"]))
    return output, len({c["person"] for c in cases})


def metrics(rows, params=None):
    errors, covered, changed = [], 0, 0
    for base, lengths, target, radius in rows:
        new = base if params is None else adjusted(base, lengths, *params)
        ae = abs(new - target)
        errors.append(ae)
        covered += ae <= radius
        changed += new != base
    return {"forecasts": len(rows), "mean_absolute_error_days": statistics.mean(errors),
            "within_3_days": sum(e <= 3 for e in errors)/len(rows),
            "window_coverage": covered/len(rows), "changed_forecasts": changed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("development_cases")
    parser.add_argument("development_predictions")
    args = parser.parse_args()
    rows, people = load_rows(args.development_cases, args.development_predictions)
    options = []
    for prior, strength, blend in itertools.product(PRIORS, STRENGTHS, BLENDS):
        params = (prior, strength, blend)
        result = metrics(rows, params)
        options.append({"prior_days": prior, "strength": strength, "blend": blend, **result})
    options.sort(key=lambda o: (o["mean_absolute_error_days"], o["blend"],
                                -o["strength"], abs(o["prior_days"]-29), o["prior_days"]))
    print(json.dumps({
        "development_participants": people,
        "candidate_count": len(options),
        "baseline": metrics(rows),
        "selected": options[0],
        "top_10": options[:10],
    }, indent=2))


if __name__ == "__main__":
    main()
