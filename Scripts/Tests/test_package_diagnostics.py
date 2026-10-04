from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/config/diagnostic-limits.env',
    'Scripts/internal/diagnostics/diagnostic_limits.py',
    'Scripts/internal/diagnostics/diagnostic_model.py',
    'Scripts/package-diagnostics.py',
    'Scripts/script_diagnostics.py',
    'Scripts/test-package.sh',
    'Scripts/phase-timing.py',
    'Scripts/lib/args.sh',
    'Scripts/lib/verification-policy.sh',
)


import contextlib
import io
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from script_test_support import ScriptRegressionTestCase, load_script
import script_diagnostics

REPORT = load_script("package_diagnostics", "package-diagnostics.py")


class PackageDiagnosticsTests(ScriptRegressionTestCase):
    def test_failure_excerpt_stops_scanning_when_earliest_context_fills_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "worker.log"
            log.write_text("".join(f"ERROR {index}\n" for index in range(3000)))
            with patch.object(script_diagnostics, "FAILURE_RE", wraps=script_diagnostics.FAILURE_RE) as matcher:
                output = script_diagnostics.excerpt(log)
            budget = script_diagnostics.MAX_LINES - 1
            self.assertEqual(output[:-1], [f"{index + 1}: ERROR {index}" for index in range(budget)])
            self.assertIn("omitted", output[-1])
            self.assertLessEqual(matcher.search.call_count, script_diagnostics.MAX_LINES)

    def test_truncated_excerpt_labels_tail_positions_and_preserves_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "worker.log"
            tail = "error: tail sentinel\ncontext\n"
            log.write_text("prefix\n" * 20 + "partial-line\n" + tail)
            with patch.object(script_diagnostics, "MAX_LOG_BYTES", len(tail) + 4):
                output = script_diagnostics.excerpt(log)
            self.assertEqual(output[:2], ["tail+1: error: tail sentinel", "tail+2: context"])
            self.assertIn("omitted (including log prefix)", output[-1])
            self.assertIn("full log retained", output[-1])

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
            for payload in ("not JSON", 'null', '{"issues": null}', '{"issues": {"message": "broken"}}', '{"issues": [null]}'):
                with self.subTest(payload=payload):
                    (root / "bad.json").write_text(payload)
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
        import subprocess

        with tempfile.TemporaryDirectory() as directory:
            root = self.make_repo_fixture(directory, (
                'Scripts/test-package.sh', 'Scripts/package-diagnostics.py',
                'Scripts/script_diagnostics.py', 'Scripts/phase-timing.py',
                'Scripts/lib/args.sh', 'Scripts/lib/verification-policy.sh',
                'Scripts/config/diagnostic-limits.env', 'Scripts/internal/diagnostics/diagnostic_limits.py',
            ))
            scripts = root / "Scripts"
            (scripts / 'test-timing.py').write_text('')
            (scripts / "run-env.sh").write_text(
                'source Scripts/lib/args.sh\n'
                'trinket_run_env_init() { DERIVED_DATA_PATH="$PWD/dd"; RESULTS_DIR="$PWD/results"; }\n'
                'trinket_track_test_guests() { :; }\n'
            )
            (scripts / "ensure-simulator.sh").write_text('trinket_sim_slot_ensure() { :; }\n')
            (scripts / "build-freshness.sh").write_text(
                'TRINKET_TEST_PACKAGES=(TrinketCore BattleEngine)\n'
                'prepare_generated_inputs() { :; }\n'
                'package_test_scheme() { echo "$1"; }\n'
                'package_derived_data_path() { echo "$PWD/dd/$1"; }\n'
                'begin_build_stamps() { :; }\n'
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
                '  printf "%s\\n" "$@" >"$XCODE_RUNNER_REPORT_PREFIX.args"\n'
                '  printf \'{"issues":[{"file":"Shared.swift","line":1,"message":"shared compiler failure"}]}\' >"$XCODE_RUNNER_REPORT_PREFIX.json"\n'
                '  echo "retained markdown" >"$XCODE_RUNNER_REPORT_PREFIX.md"\n'
                '  echo "VERBOSE WORKER LOG"\n'
                '  return "${FIXTURE_STATUS:-65}"\n'
                '}\n'
            )
            cases = (
                (["--build-for-testing"], [], "65"),
                (["--build-for-testing"], ["--verbose"], "65"),
                (["--build-for-testing"], [], "0"),
                (["--destination", "id=fixture"], [], "0"),
                (["--destination", "id=fixture"], ["--include-balance-sweep-tests"], "0"),
            )
            for action, extra, status in cases:
                with self.subTest(action=action, extra=extra, status=status):
                    result = subprocess.run(
                        ["bash", str(scripts / "test-package.sh"), *action, *extra, "TrinketCore", "BattleEngine"],
                        env={**os.environ, "FIXTURE_STATUS": status, "GITHUB_ACTIONS": "true"}, capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, int(status != "0"), result.stdout + result.stderr)
                    self.assertEqual(result.stdout.count("VERBOSE WORKER LOG"), 2 if "--verbose" in extra else 0)
                    if status != "0" and not extra:
                        self.assertEqual(result.stdout.count("shared compiler failure"), 1)
                    self.assertIn("TrinketCore: " + ("PASS" if status == "0" else "FAIL"), result.stdout)
                    self.assertIn("BattleEngine-current.json", result.stdout)
                    battle_args = (root / "results/BattleEngine-current.args").read_text().splitlines()
                    excluded = action != ["--build-for-testing"] and "--include-balance-sweep-tests" not in extra
                    for target in ("BattleBalanceToolsTests", "BalanceSweepCLITests"):
                        self.assertEqual(f"-skip-testing:{target}" in battle_args, excluded)
                    core_args = (root / "results/TrinketCore-current.args").read_text().splitlines()
                    self.assertFalse(any(arg.startswith("-skip-testing:") for arg in core_args))
