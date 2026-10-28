#!/usr/bin/env python3
"""Exhaustive UI summaries distinguish coverage gaps from passed execution."""

from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from script_test_support import load_script

reporter = load_script("exhaustive_report_regressions", "report-exhaustive-ci.py")


def pages(*outcomes):
    return [{"jobs": [{"name": f"tests / Exhaustive UI ({index})", "conclusion": outcome,
                       "status": "completed", "html_url": f"https://example.invalid/jobs/{index}"}]}
            for index, outcome in enumerate(outcomes)]


class ExhaustiveReportRegressionTests(unittest.TestCase):
    def test_incomplete_job_cannot_claim_a_success_conclusion(self):
        for status in ('in_progress', 'success', 'skipped', None):
            payload = pages('success')
            payload[0]['jobs'][0]['status'] = status
            with self.subTest(status=status):
                summary, warnings = reporter.report(payload)
                self.assertIn('attention required', summary)
                self.assertTrue(warnings)
                self.assertNotIn('| success |', summary)

    def test_malformed_jobs_fail_closed_with_a_bounded_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            jobs = Path(directory) / 'jobs.json'
            for payload in ([None], [{'jobs': [None]}], [{'jobs': [{'name': None}]}]):
                jobs.write_text(json.dumps(payload))
                with self.subTest(payload=payload), patch.object(sys, 'argv', ['report-exhaustive-ci.py', str(jobs), '--require-execution']), \
                     patch.dict(os.environ, {'GITHUB_STEP_SUMMARY': ''}), redirect_stdout(io.StringIO()) as output:
                    self.assertEqual(reporter.main(), 1)
                    self.assertIn('status unknown', output.getvalue())

    def test_summary_does_not_pass_partial_execution(self):
        for outcomes, title in ((["success", "skipped"], "incomplete"),
                                (["skipped", "skipped"], "not run"),
                                (["success", "success"], "passed"),
                                (["failure", "skipped"], "attention required")):
            with self.subTest(outcomes=outcomes):
                summary, warnings = reporter.report(pages(*outcomes))
                self.assertIn(f"Exhaustive UI: {title} (advisory)", summary)
                self.assertEqual(bool(warnings), "failure" in outcomes)
                if "skipped" in outcomes:
                    self.assertIn("provide no execution evidence", summary)

    def test_mixed_execution_remains_advisory_unless_execution_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            jobs = Path(directory) / "jobs.json"
            jobs.write_text(json.dumps(pages("success", "skipped")))
            for required, expected in ((False, 0), (True, 1)):
                arguments = ["report-exhaustive-ci.py", str(jobs)]
                if required:
                    arguments.append("--require-execution")
                with self.subTest(required=required), patch.object(sys, "argv", arguments), \
                     patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}), redirect_stdout(io.StringIO()):
                    self.assertEqual(reporter.main(), expected)


if __name__ == "__main__":
    unittest.main()
