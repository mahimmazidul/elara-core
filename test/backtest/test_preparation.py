"""Synthetic invariants for the independent public-data evaluation harness."""
import csv
import datetime as dt
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import prepare_marquette
import prepare_utah

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def write_csv(path, fields, rows):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def utah_row(person, number, start, length, status="No"):
    day = dt.date.fromisoformat(start)
    end = day + dt.timedelta(days=(length or 14) - 1)
    return {
        "new_id": person, "age": 27, "cycle_number": number,
        "cycle_start_date": f"{day.month}/{day.day}/{day.year % 100:02d}",
        "cycle_end_date": f"{end.month}/{end.day}/{end.year % 100:02d}",
        "cycle_length": "" if length is None else length,
        "conception_cycle": status,
    }


class UtahPreparationTests(unittest.TestCase):
    def test_future_targets_gaps_mismatch_and_conception(self):
        rows = [
            utah_row("a", 1, "2024-01-01", 28),
            utah_row("a", 2, "2024-01-29", 28),
            utah_row("a", 3, "2024-02-26", 31),
            utah_row("a", 5, "2024-03-29", 28),  # cycle 4 is missing
            utah_row("a", 6, "2024-04-26", 27),  # 28 days until next
            utah_row("a", 7, "2024-05-24", 28),
            utah_row("a", 8, "2024-06-21", None, "Yes"),
            utah_row("a", 9, "2024-07-20", 28),
            utah_row("a", 10, "2024-08-17", 28),
            utah_row("b", 1, "2024-01-01", 28),  # no following start
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.csv"
            write_csv(path, list(rows[0]), rows)
            cases, audit = prepare_utah.prepare(path)
        self.assertEqual(audit["counts"]["eligible_forecasts"], 5)
        self.assertEqual(audit["counts"]["excluded_pair_nonconsecutive_cycle_number"], 1)
        self.assertEqual(audit["counts"]["excluded_pair_reported_length_next_start_mismatch"], 1)
        self.assertEqual(audit["counts"]["excluded_pair_current_cycle_not_documented_nonconception"], 1)
        self.assertEqual([c["history"] for c in cases], [
            ["2024-01-01"],
            ["2024-01-01", "2024-01-29"],
            ["2024-03-29"],
            ["2024-05-24"],
            ["2024-07-20"],
        ])
        self.assertEqual([c["actual_next_start"] for c in cases], [
            "2024-01-29", "2024-02-26", "2024-04-26", "2024-06-21", "2024-08-17"
        ])
        self.assertTrue(all(c["history"][-1] < c["actual_next_start"] for c in cases))


class MarquettePreparationTests(unittest.TestCase):
    def test_duplicate_participants_excluded_and_dates_are_relative(self):
        rows = [
            {"ClientID": "a", "CycleNumber": n, "LengthofCycle": length}
            for n, length in [(1, 28), (2, 29), (3, 27), (4, 30), (6, 31), (7, 32)]
        ]
        rows += [
            {"ClientID": "b", "CycleNumber": n, "LengthofCycle": length}
            for n, length in [(1, 28), (1, 29), (2, 30)]
        ]
        rows += [{"ClientID": "c", "CycleNumber": 1, "LengthofCycle": 28}]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.csv"
            write_csv(path, ["ClientID", "CycleNumber", "LengthofCycle"], rows)
            cases, audit = prepare_marquette.prepare(path)
        self.assertEqual(audit["counts"]["excluded_participants_duplicate_cycle_numbers"], 1)
        self.assertEqual(audit["counts"]["excluded_rows_duplicate_cycle_numbers"], 3)
        self.assertEqual(audit["counts"]["excluded_pair_nonconsecutive_cycle_number"], 1)
        self.assertEqual(audit["counts"]["eligible_forecasts"], 4)
        self.assertEqual(cases[0]["history"], ["2000-01-01"])
        self.assertEqual(cases[0]["actual_next_start"], "2000-01-29")
        self.assertEqual(cases[1]["history"], ["2000-01-01", "2000-01-29"])
        self.assertEqual(cases[1]["actual_next_start"], "2000-02-27")
        self.assertEqual(cases[3]["history"], ["2000-01-01"])  # after gap
        self.assertEqual(cases[3]["reported_target_length"], 31)


class ActualDartEngineTests(unittest.TestCase):
    def test_predictions_do_not_change_when_only_future_target_changes(self):
        starts = ["2026-01-01", "2026-01-29", "2026-02-26", "2026-03-26"]
        target_dates = ["2026-04-23", "2026-05-08", "2026-04-16"]
        cases = []
        for i, target in enumerate(target_dates):
            delta = (dt.date.fromisoformat(target) - dt.date.fromisoformat(starts[-1])).days
            cases.append({
                "person": str(i), "age_at_first_cycle": 18 + i,
                "history": starts, "actual_next_start": target,
                "reported_target_length": delta, "prior_range_days": 0,
            })
        completed = subprocess.run(
            [os.environ.get("DART", "dart"), "run", "test/backtest/walk_forward.dart"],
            cwd=ROOT, input="".join(json.dumps(c) + "\n" for c in cases),
            text=True, capture_output=True, check=True,
        )
        predictions = [json.loads(line) for line in completed.stdout.splitlines()]
        self.assertEqual(len(predictions), 3)
        elara = [p["elara"] for p in predictions]
        self.assertEqual([p["prediction_length"] for p in elara], [28, 28, 28])
        self.assertEqual([p["window_days"] for p in elara], [2, 2, 2])
        self.assertTrue(all(p["score"] == elara[0]["score"] for p in elara))
        self.assertEqual([p["error_days"] for p in elara], [0, -15, 7])


if __name__ == "__main__":
    unittest.main()
