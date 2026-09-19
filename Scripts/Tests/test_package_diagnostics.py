from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from script_test_support import load_script

REPORT = load_script("package_diagnostics", "package-diagnostics.py")


class PackageDiagnosticsTests(unittest.TestCase):
    def test_aggregate_deduplicates_failures_bounds_detail_and_retains_every_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for package in ("A", "B", "C"):
                (root / f"{package}.status").write_text("0" if package == "C" else "65")
                (root / f"{package}.stdout").write_text("FULL WORKER OUTPUT\n" * 5000)
                prefix = root / f"{package}.diagnostics"
                (root / f"{package}.report").write_text(str(prefix))
                issues = [{"file": "Shared.swift", "line": 4, "message": "duplicate compiler error"}]
                issues += [{"file": "Other.swift", "line": i, "message": "huge " + "x" * 5000} for i in range(100)]
                Path(str(prefix) + ".json").write_text(json.dumps({"issues": issues}))
                Path(str(prefix) + ".md").write_text("full markdown report\n")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = REPORT.summarize(root, ["A", "B", "C", "Missing"])
            text = output.getvalue()
            self.assertEqual(status, 1)
            self.assertEqual(text.count("duplicate compiler error"), 1)
            self.assertIn("[A, B]", text)
            self.assertIn("C: PASS", text)
            self.assertIn("Missing: FAIL", text)
            self.assertNotIn("FULL WORKER OUTPUT", text)
            self.assertLess(len(text), 12000)
            self.assertIn("omitted", text)
            for package in ("A", "B", "C"):
                self.assertIn(str(root / f"{package}.diagnostics.json"), text)
                self.assertIn(str(root / f"{package}.stdout"), text)
            verbose = io.StringIO()
            with contextlib.redirect_stdout(verbose):
                self.assertEqual(REPORT.summarize(root, ["A"], verbose=True), 1)
            self.assertEqual(verbose.getvalue().count("FULL WORKER OUTPUT"), 5000)
            self.assertIn("full markdown report", verbose.getvalue())

    def test_missing_or_invalid_report_uses_bounded_worker_log_and_keeps_status(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "A.status").write_text("7")
            (root / "A.stdout").write_text("error: preflight failure\n" * 3000)
            (root / "A.report").write_text(str(root / "bad"))
            (root / "bad.json").write_text("not JSON")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(REPORT.summarize(root, ["A"]), 1)
            self.assertIn("exit 7", output.getvalue())
            self.assertIn("preflight failure", output.getvalue())
            self.assertLess(len(output.getvalue().splitlines()), 65)
            (root / "A.status").write_text("0")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(REPORT.summarize(root, ["A"]), 0)

    def test_package_wrapper_aggregates_this_run_and_preserves_failure_status(self):
        import os
        import shutil
        import subprocess
        from script_test_support import ROOT

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            shutil.copytree(ROOT / "Scripts", scripts)
            (scripts / "run-env.sh").write_text(
                'source Scripts/lib/args.sh\n'
                'trinket_run_env_init() { DERIVED_DATA_PATH="$PWD/dd"; RESULTS_DIR="$PWD/results"; }\n'
            )
            (scripts / "ensure-simulator.sh").write_text('trinket_sim_slot_ensure() { :; }\n')
            (scripts / "build-freshness.sh").write_text(
                'TRINKET_TEST_PACKAGES=(TrinketCore BattleEngine)\n'
                'prepare_generated_inputs() { :; }\n'
                'package_test_scheme() { echo "$1"; }\n'
                'package_derived_data_path() { echo "$PWD/dd/$1"; }\n'
                'touch_build_stamp() { :; }\n'
            )
            (scripts / "lib/app-build.sh").write_text(
                'trinket_set_package_scheme_args() { TRINKET_PACKAGE_SCHEME_ARGS=(fixture); }\n'
                'trinket_set_local_simulator_architecture_args() { TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS=(fixture); }\n'
            )
            (scripts / "xcode-runner.sh").write_text(
                'xcode_runner_prepare() {\n'
                '  XCODE_RUNNER_INVOCATION_ID="$1-current"\n'
                '  XCODE_RUNNER_RESULT_BUNDLE_PATH="$PWD/results/$1.xcresult"\n'
                '  XCODE_RUNNER_LOG_PATH="$PWD/results/$1.log"\n'
                '  XCODE_RUNNER_REPORT_PREFIX="$PWD/results/$1-current"\n'
                '}\n'
                'xcode_runner_run() {\n'
                '  printf \'{"issues":[{"file":"Shared.swift","line":1,"message":"shared compiler failure"}]}\' >"$XCODE_RUNNER_REPORT_PREFIX.json"\n'
                '  echo "retained markdown" >"$XCODE_RUNNER_REPORT_PREFIX.md"\n'
                '  echo "VERBOSE WORKER LOG"\n'
                '  return "${FIXTURE_STATUS:-65}"\n'
                '}\n'
            )
            for extra, status in (([], "65"), (["--verbose"], "65"), ([], "0")):
                with self.subTest(extra=extra, status=status):
                    result = subprocess.run(
                        ["bash", str(scripts / "test-package.sh"), "--build-for-testing", *extra, "TrinketCore", "BattleEngine"],
                        env={**os.environ, "FIXTURE_STATUS": status}, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, int(status != "0"), result.stdout + result.stderr)
                    self.assertEqual(result.stdout.count("VERBOSE WORKER LOG"), 2 if extra else 0)
                    if status != "0" and not extra:
                        self.assertEqual(result.stdout.count("shared compiler failure"), 1)
                    self.assertIn("TrinketCore: " + ("PASS" if status == "0" else "FAIL"), result.stdout)
                    self.assertIn("BattleEngine-current.json", result.stdout)
