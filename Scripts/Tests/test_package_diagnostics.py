from __future__ import annotations

import contextlib
import io
import tempfile
from pathlib import Path
from unittest.mock import patch

from script_test_support import ScriptRegressionTestCase, load_script, run_captured, write_json
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
            # A newline-free tail is still the only failure preview in quiet mode.
            sentinel = "ERROR: newline-free tail sentinel"
            log.write_text("prefix" * 20 + sentinel)
            with patch.object(script_diagnostics, "MAX_LOG_BYTES", len(sentinel)):
                output = script_diagnostics.excerpt(log)
            self.assertEqual(output[0], "tail+1: " + sentinel)
            self.assertIn("omitted (including log prefix)", output[-1])

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
                write_json(Path(str(prefix) + ".json"), {"issues": issues})
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

        with tempfile.TemporaryDirectory(prefix="package workers ") as directory:
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
                'build_stamp_path() { echo "$PWD/results/$2.stamp"; }\n'
                'assert_no_build_inputs_are_fresh() { :; }\n'
                'begin_build_stamps() { :; }\n'
                'touch_build_stamp() { :; }\n'
            )
            (scripts / "lib/app-build.sh").write_text(
                'trinket_set_package_scheme_args() { TRINKET_PACKAGE_SCHEME_ARGS=(--fixture-destination "$3"); }\n'
                'trinket_set_local_simulator_architecture_args() { TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS=(fixture); }\n'
            )
            (scripts / "xcode-runner.sh").write_text(
                'xcode_runner_prepare() {\n'
                '  printf "%s\\n" "$3" >"$PWD/results/$1.prefix"\n'
                '  XCODE_RUNNER_INVOCATION_ID="$1-current"\n'
                '  XCODE_RUNNER_RESULT_BUNDLE_PATH="$PWD/results/$1.xcresult"\n'
                '  XCODE_RUNNER_LOG_PATH="$PWD/results/$1.log"\n'
                '  XCODE_RUNNER_REPORT_PREFIX="$PWD/results/$1-current"\n'
                '}\n'
                'xcode_runner_write_manifest() { printf "{}" >"$2.json"; }\n'
                'xcode_runner_run() {\n'
                '  printf "%s\\n" "$@" >"$XCODE_RUNNER_REPORT_PREFIX.args"\n'
                '  printf \'{"issues":[{"file":"Shared.swift","line":1,"message":"shared compiler failure"}]}\' >"$XCODE_RUNNER_REPORT_PREFIX.json"\n'
                '  echo "retained markdown" >"$XCODE_RUNNER_REPORT_PREFIX.md"\n'
                '  echo "VERBOSE WORKER LOG"\n'
                '  return "${FIXTURE_STATUS:-65}"\n'
                '}\n'
            )
            for package in ('TrinketCore', 'BattleEngine'):
                products = root / 'dd' / package / 'Build/Products'
                products.mkdir(parents=True)
                (products / 'fixture.xctestrun').touch()
            cases = (
                (["--build-for-testing"], [], "65"),
                (["--build-for-testing"], ["--verbose"], "65"),
                (["--build-for-testing"], [], "0"),
                (["--destination", "id=fixture"], [], "0"),
                (["--destination", "id=fixture"], ["--include-balance-sweep-tests"], "0"),
                (["--destination", "id=fixture"], ["--iterations", "3", "--run-tests-until-failure"], "0"),
                (["--destination", "id=fixture"], ["--report-prefix", "custom run"], "0"),
                (["--no-build", "--destination", "id=fixture"], [], "0"),
            )
            for action, extra, status in cases:
                with self.subTest(action=action, extra=extra, status=status):
                    result = run_captured(
                        ["bash", str(scripts / "test-package.sh"), *action, *extra, "TrinketCore", "BattleEngine"],
                        env={**os.environ, "FIXTURE_STATUS": status, "GITHUB_ACTIONS": "true"},
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
                    if "--report-prefix" in extra:
                        self.assertEqual((root / "results/BattleEngine.prefix").read_text().strip(), "custom run-BattleEngine")
                    for args in (core_args, battle_args):
                        expected_destination = "generic/platform=iOS Simulator" if action == ["--build-for-testing"] else "id=fixture"
                        self.assertEqual(args[args.index("--fixture-destination") + 1], expected_destination)
                        self.assertEqual("-resultBundlePath" in args, action != ["--build-for-testing"])
                    if "--iterations" in extra:
                        for args in (core_args, battle_args):
                            self.assertEqual(args[args.index("-test-iterations") + 1], "3")
                            self.assertIn("-run-tests-until-failure", args)

            import shutil
            shutil.rmtree(root / 'dd/TrinketCore/Build/Products')
            (root / 'results/TrinketCore-current.args').unlink(missing_ok=True)
            missing = run_captured(
                ['bash', str(scripts / 'test-package.sh'), '--no-build', '--destination', 'id=fixture', 'TrinketCore'],
                env={**os.environ, 'FIXTURE_STATUS': '0', 'GITHUB_ACTIONS': 'true'},
            )
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn('Built products for TrinketCore are missing', missing.stderr)
            self.assertFalse((root / 'results/TrinketCore-current.args').exists())

            for mode in ("only-suite", "skip-suite"):
                with self.subTest(mode=mode):
                    result = run_captured(
                        ["bash", str(scripts / "test-package.sh"), "--destination", "id=fixture",
                         f"--{mode}", "BattleBalanceToolsTests/BalanceFindingsReporterTests", "BattleEngine"],
                        env={**os.environ, "FIXTURE_STATUS": "65", "GITHUB_ACTIONS": "true"},
                    )
                    self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
                    args = (root / "results/BattleEngine-current.args").read_text().splitlines()
                    self.assertIn(f"-{mode.replace('-suite', '-testing')}:BattleBalanceToolsTests/BalanceFindingsReporterTests", args)
                    self.assertNotIn("-skip-testing:BattleBalanceToolsTests", args)
                    self.assertIn("-skip-testing:BalanceSweepCLITests", args)
            for invalid in ("/Suite", "Target/", "Target/Suite/Method", "Target/-Suite"):
                result = run_captured(
                    ["bash", str(scripts / "test-package.sh"), "--only-suite", invalid, "BattleEngine"],
                    env={**os.environ, "GITHUB_ACTIONS": "true"},
                )
                self.assertEqual(result.returncode, 2, invalid)
