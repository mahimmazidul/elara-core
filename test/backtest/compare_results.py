#!/usr/bin/env python3
"""Summarize a paired Dart candidate comparison with participant bootstrap."""
import argparse
import collections
import json
import math
import random
import statistics
from pathlib import Path


def quantile(values, fraction):
    values = sorted(values)
    pos = (len(values)-1) * fraction
    low, high = math.floor(pos), math.ceil(pos)
    return values[low] + (values[high]-values[low]) * (pos-low)


def summary(rows):
    n = len(rows)
    if not n:
        return None
    people = collections.defaultdict(list)
    for row in rows:
        people[row["person"]].append(row)
    result = {"forecasts": n, "participants": len(people)}
    for name in ("baseline", "candidate"):
        errors = [r[name]["error_days"] for r in rows]
        abs_errors = [abs(e) for e in errors]
        individual_mae = [statistics.mean(abs(r[name]["error_days"]) for r in group)
                          for group in people.values()]
        result[name] = {
            "mae_days": statistics.mean(abs_errors),
            "person_weighted_mae_days": statistics.mean(individual_mae),
            "median_ae_days": statistics.median(abs_errors),
            "mean_signed_error_days_late_positive": statistics.mean(errors),
            "exact_rate": sum(e == 0 for e in abs_errors) / n,
            "within_1_day_rate": sum(e <= 1 for e in abs_errors) / n,
            "within_2_days_rate": sum(e <= 2 for e in abs_errors) / n,
            "within_3_days_rate": sum(e <= 3 for e in abs_errors) / n,
            "over_7_days_rate": sum(e > 7 for e in abs_errors) / n,
            "window_coverage": sum(abs(r[name]["error_days"]) <= r[name]["window_days"] for r in rows) / n,
            "mean_window_radius_days": statistics.mean(r[name]["window_days"] for r in rows),
        }
    result["candidate_minus_baseline_mae_days"] = result["candidate"]["mae_days"] - result["baseline"]["mae_days"]
    result["candidate_minus_baseline_within_3"] = result["candidate"]["within_3_days_rate"] - result["baseline"]["within_3_days_rate"]
    result["candidate_minus_baseline_coverage"] = result["candidate"]["window_coverage"] - result["baseline"]["window_coverage"]
    result["changed_forecasts"] = sum(r["candidate"]["prediction_length"] != r["baseline"]["prediction_length"] for r in rows)
    return result


def bootstrap(rows, seed=20261108, replicates=5000):
    people = collections.defaultdict(list)
    for row in rows:
        people[row["person"]].append(row)
    aggregates = []
    for group in people.values():
        aggregates.append((len(group),
                           sum(abs(r["candidate"]["error_days"]) for r in group),
                           sum(abs(r["baseline"]["error_days"]) for r in group)))
    rng = random.Random(seed)
    deltas = []
    for _ in range(replicates):
        sample = rng.choices(aggregates, k=len(aggregates))
        deltas.append((sum(x[1] for x in sample)-sum(x[2] for x in sample)) / sum(x[0] for x in sample))
    return {"replicates": replicates, "seed": seed, "resampling_unit": "participant",
            "candidate_minus_baseline_mae_95_percentile_interval_days": [
                quantile(deltas,.025), quantile(deltas,.975)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("comparison", help="Private JSONL from compare_forecasts.dart")
    args = parser.parse_args()
    rows = [json.loads(line) for line in Path(args.comparison).read_text().splitlines() if line.strip()]
    if not rows:
        raise ValueError("Empty input")
    groups = {
        "all": rows,
        "zero_prior_completed": [r for r in rows if r["prior_completed_cycles"] == 0],
        "one_prior_completed": [r for r in rows if r["prior_completed_cycles"] == 1],
        "two_prior_completed": [r for r in rows if r["prior_completed_cycles"] == 2],
        "at_least_one_prior_completed": [r for r in rows if r["prior_completed_cycles"] >= 1],
        "at_least_three_prior_completed": [r for r in rows if r["prior_completed_cycles"] >= 3],
        "range_at_most_7_minimum_3_prior": [r for r in rows if r["prior_completed_cycles"] >= 3 and r["prior_range_days"] <= 7],
        "range_over_7_minimum_3_prior": [r for r in rows if r["prior_completed_cycles"] >= 3 and r["prior_range_days"] > 7],
        "target_15_to_50_sensitivity": [r for r in rows if 15 <= r["actual_length"] <= 50],
        "target_outside_15_to_50": [r for r in rows if not 15 <= r["actual_length"] <= 50],
    }
    out = {name: summary(group) for name, group in groups.items()}
    out["all"]["paired_bootstrap"] = bootstrap(rows)
    print(json.dumps(out, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
