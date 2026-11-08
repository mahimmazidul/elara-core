#!/usr/bin/env python3
"""Prepare a secondary, length-only walk-forward check of Fehring's data.

The input data do not include actual calendar start dates. We reconstruct
arbitrary UTC dates by cumulatively adding previously observed cycle lengths;
thus this tests cycle-length error, not calendar-record completeness. Requires
consecutive cycle numbers and excludes all participants with duplicate cycle
numbers. The current length is used only as the future evaluation target.
Input and output are participant-level; keep them local and check data rights.
"""

import argparse
import collections
import csv
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

REQUIRED = {"ClientID", "CycleNumber", "LengthofCycle"}


def prepare(csv_path):
    path = Path(csv_path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    people = collections.defaultdict(list)
    audit = collections.Counter()
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        missing = REQUIRED - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing columns: {sorted(missing)}")
        for row in reader:
            audit["total_rows"] += 1
            person = row["ClientID"].strip()
            if not person:
                raise ValueError("Missing participant ID")
            number = int(row["CycleNumber"].strip())
            value = float(row["LengthofCycle"].strip())
            if number < 1 or not value.is_integer() or value <= 0:
                raise ValueError("Invalid cycle number or cycle length")
            people[person].append({"number": number, "length": int(value)})

    cases, eligible_people = [], set()
    histories = collections.Counter()
    for person, rows in sorted(people.items()):
        rows.sort(key=lambda row: row["number"])
        numbers = [r["number"] for r in rows]
        if len(numbers) != len(set(numbers)):
            audit["excluded_participants_duplicate_cycle_numbers"] += 1
            audit["excluded_rows_duplicate_cycle_numbers"] += len(rows)
            continue
        # The epoch is arbitrary: relative lengths, not true calendar dates.
        history = [dt.date(2000, 1, 1)]
        audit["retained_participants"] += 1
        audit["retained_rows"] += len(rows)
        for current, following in zip(rows, rows[1:]):
            if following["number"] != current["number"] + 1:
                audit["excluded_pair_nonconsecutive_cycle_number"] += 1
                history = [dt.date(2000, 1, 1)]
                continue
            target = history[-1] + dt.timedelta(days=current["length"])
            prior = [(b - a).days for a, b in zip(history, history[1:])]
            cases.append({
                "person": person,
                "age_at_first_cycle": None,
                "history": [day.isoformat() for day in history],
                "actual_next_start": target.isoformat(),
                "reported_target_length": current["length"],
                "prior_range_days": max(prior) - min(prior) if len(prior) >= 3 else None,
            })
            eligible_people.add(person)
            histories[len(prior)] += 1
            audit["eligible_forecasts"] += 1
            # This length is known only after the current cycle is complete.
            history.append(target)

    audit["participants_total"] = len(people)
    audit["participants_with_eligible_forecasts"] = len(eligible_people)
    manifest = {
        "source_sha256": digest,
        "date_note": "Artificial dates reconstructed from the study's recorded cycle lengths; no actual dates are claimed.",
        "counts": dict(sorted(audit.items())),
        "forecasts_by_number_of_prior_completed_cycles": {
            str(k): v for k, v in sorted(histories.items())
        },
    }
    return cases, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", help="Path to FedCycleData071012 CSV")
    args = parser.parse_args()
    cases, audit = prepare(args.csv)
    for case in cases:
        print(json.dumps(case, separators=(",", ":")))
    print(json.dumps(audit, indent=2), file=sys.stderr)


if __name__ == "__main__":
    main()
