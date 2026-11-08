#!/usr/bin/env python3
"""Deterministically separate participant-level JSONL into development/holdout.

All records from a participant go to the same partition. Files are sensitive
and must stay local. The prefix and 70/30 rule must remain fixed when
reproducing the published experiment.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path

SALT = "elara-person-split-2026-11-v1:"


def partition(person):
    digest = hashlib.sha256((SALT + str(person)).encode("utf-8")).digest()
    bucket = int.from_bytes(digest[:8], "big") % 10
    return "development" if bucket < 7 else "holdout"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cases", help="Prepared participant-level JSONL")
    parser.add_argument("development", help="Private output path")
    parser.add_argument("holdout", help="Private output path")
    args = parser.parse_args()
    counts = collections.Counter()
    people = {"development": set(), "holdout": set()}
    with Path(args.cases).open(encoding="utf-8") as source, \
            Path(args.development).open("w", encoding="utf-8") as dev, \
            Path(args.holdout).open("w", encoding="utf-8") as holdout:
        for line in source:
            if not line.strip():
                continue
            case = json.loads(line)
            group = partition(case["person"])
            counts[group] += 1
            people[group].add(case["person"])
            (dev if group == "development" else holdout).write(line)
    assert people["development"].isdisjoint(people["holdout"])
    print(json.dumps({group: {"forecasts": counts[group], "participants": len(people[group])}
                      for group in ("development", "holdout")}, indent=2))


if __name__ == "__main__":
    main()
