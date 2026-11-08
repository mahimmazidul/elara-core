#!/usr/bin/env python3
# Copyright (c) 2026 Md. Mazidul Islam Mahim
# ELARA-core — Ensemble Menstrual Cycle Prediction Engine
# https://github.com/mahimmazidul/elara-core
#
# Original work by the author. Not derived from any ported engine.
# Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
# The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

"""Prepare leakage-free walk-forward cases from the Utah Creighton CSV.

Print newline-delimited cases to stdout and an aggregate audit to stderr. The
output contains participant-level information and should remain local. No raw
records are bundled with this evaluation; the source data are CC BY-NC.
"""

import argparse
import collections
import csv
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

REQUIRED = {
    "new_id", "age", "cycle_number", "cycle_start_date", "cycle_end_date",
    "cycle_length", "conception_cycle",
}


def parse_date(value):
    return dt.datetime.strptime(value.strip(), "%m/%d/%y").date()


def prepare(csv_path):
    path = Path(csv_path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    people = collections.defaultdict(list)
    audit = collections.Counter()
    statuses = collections.Counter()

    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        missing = REQUIRED - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing required columns: {sorted(missing)}")
        for row in reader:
            audit["total_rows"] += 1
            person = row["new_id"].strip()
            if not person:
                raise ValueError("Missing participant ID; cannot establish sequences")
            number = int(row["cycle_number"])
            if number < 1:
                raise ValueError("Cycle numbers must be positive")
            start = parse_date(row["cycle_start_date"])
            end = parse_date(row["cycle_end_date"])
            age = int(row["age"]) if row["age"].strip() else None
            raw_length = row["cycle_length"].strip()
            length = int(raw_length) if raw_length else None
            status = row["conception_cycle"].strip().lower()
            statuses[status] += 1
            if length is None:
                audit["rows_without_reported_length"] += 1
            elif length <= 0:
                raise ValueError("Nonpositive reported cycle length")
            elif (end - start).days + 1 != length:
                audit["row_end_length_mismatches"] += 1
            people[person].append({"number": number, "start": start,
                                   "end": end, "age": age,
                                   "length": length, "status": status})

    cases = []
    eligible_people = set()
    segments = 0
    histories = collections.Counter()
    for person, rows in sorted(people.items()):
        rows.sort(key=lambda r: (r["number"], r["start"]))
        history = [rows[0]["start"]]
        segments += 1
        for current, following in zip(rows, rows[1:]):
            audit["within_person_adjacent_row_pairs"] += 1
            if history[-1] != current["start"]:
                raise AssertionError("History must end at the current start")
            gap = (following["start"] - current["start"]).days
            reason = None
            if following["number"] != current["number"] + 1:
                reason = "nonconsecutive_cycle_number"
            elif gap <= 0:
                reason = "nonincreasing_start_date"
            elif current["status"] != "no":
                reason = "current_cycle_not_documented_nonconception"
            elif current["length"] is None:
                reason = "current_cycle_length_missing"
            elif current["length"] != gap:
                reason = "reported_length_next_start_mismatch"
            elif (current["end"] - current["start"]).days + 1 != gap:
                reason = "reported_end_next_start_mismatch"
            if reason is not None:
                audit[f"excluded_pair_{reason}"] += 1
                # A break is safer than treating an unknown/missing cycle as
                # one observed long cycle or using it in later histories.
                history = [following["start"]]
                segments += 1
                continue

            prior_lengths = [(b - a).days for a, b in zip(history, history[1:])]
            case = {
                "person": person,
                "age_at_first_cycle": current["age"],
                "history": [day.isoformat() for day in history],
                "actual_next_start": following["start"].isoformat(),
                # This field is used only to cross-check labels after scoring.
                "reported_target_length": current["length"],
                "prior_range_days": (max(prior_lengths) - min(prior_lengths))
                    if len(prior_lengths) >= 3 else None,
            }
            cases.append(case)
            eligible_people.add(person)
            histories[len(prior_lengths)] += 1
            audit["eligible_forecasts"] += 1
            if gap > 50 or gap < 15:
                audit["eligible_target_lengths_outside_15_50"] += 1
            # Only append the next start once it would actually have happened.
            history.append(following["start"])

    audit["participants_total"] = len(people)
    audit["participants_with_eligible_forecasts"] = len(eligible_people)
    audit["segments_including_singletons"] = segments
    audit["terminal_rows_without_following_row"] = len(people)
    manifest = {
        "source_sha256": digest,
        "conception_status_rows": dict(sorted(statuses.items())),
        "counts": dict(sorted(audit.items())),
        "forecasts_by_number_of_prior_completed_cycles": {
            str(k): v for k, v in sorted(histories.items())
        },
    }
    return cases, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", help="Path to official CrMcyclelength_share.csv")
    args = parser.parse_args()
    cases, audit = prepare(args.csv)
    for case in cases:
        print(json.dumps(case, separators=(",", ":")))
    print(json.dumps(audit, indent=2), file=sys.stderr)


if __name__ == "__main__":
    main()
