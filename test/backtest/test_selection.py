# Copyright (c) 2026 Md. Mazidul Islam Mahim
# ELARA-core — Ensemble Menstrual Cycle Prediction Engine
# https://github.com/mahimmazidul/elara-core
#
# Original work by the author. Not derived from any ported engine.
# Licensed under Apache 2.0. See LICENSES/Apache-2.0.txt for details.
# The combined elara-core package is distributed under AGPL-3.0; see LICENSE.

"""Synthetic checks for the participant split and candidate selection."""
import json
import tempfile
import unittest
from pathlib import Path

import select_candidate
import split_cases


class SplitAndSelectionTests(unittest.TestCase):
    def test_participant_split_is_deterministic_and_has_both_groups(self):
        people = [str(i) for i in range(1000)]
        first = {person: split_cases.partition(person) for person in people}
        second = {person: split_cases.partition(person) for person in people}
        self.assertEqual(first, second)
        self.assertEqual(set(first.values()), {"development", "holdout"})

    def test_candidate_uses_only_previous_lengths_and_is_bounded(self):
        self.assertEqual(select_candidate.adjusted(30, [], 28, 1, .75), 30)
        self.assertEqual(select_candidate.adjusted(30, [25, 28], 28, 1, .75), 28)
        self.assertEqual(select_candidate.adjusted(80, [20, 20, 20], 28, 1, .75), 77)
        self.assertEqual(select_candidate.dart_round_positive(28.5), 29)

    def test_selection_refuses_holdout_participants(self):
        person = next(str(i) for i in range(1000)
                      if split_cases.partition(str(i)) == "holdout")
        case = {"person": person, "history": ["2026-01-01"],
                "actual_next_start": "2026-01-29", "reported_target_length": 28}
        prediction = {"person": person, "actual_length": 28,
                      "elara": {"prediction_length": 29, "window_days": 4}}
        with tempfile.TemporaryDirectory() as directory:
            cases = Path(directory) / "cases.jsonl"
            predictions = Path(directory) / "predictions.jsonl"
            cases.write_text(json.dumps(case) + "\n")
            predictions.write_text(json.dumps(prediction) + "\n")
            with self.assertRaisesRegex(ValueError, "Holdout participant"):
                select_candidate.load_rows(cases, predictions)


if __name__ == "__main__":
    unittest.main()
