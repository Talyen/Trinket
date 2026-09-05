#!/usr/bin/env python3
"""Execution-free coverage for top-level wrappers lacking dedicated tests.

Covers --help/unknown-arg paths for test.sh, build-for-testing.sh,
test-scripts.sh, and performance.sh without requiring Xcode or simulators.
"""

import json
import os
import shutil
import tempfile
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def run_script(name: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(ROOT / "Scripts" / name), *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


class ExecWrapperTests(unittest.TestCase):
    def test_performance_runner_retains_success_and_partial_failure_evidence(self) -> None:
        for test_status in (0, 1):
            with self.subTest(test_status=test_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                (scripts / "lib").mkdir(parents=True)
                for name in ("performance.sh", "collect-performance-results.py", "compare-performance.py", "performance_model.py", "lib/lock.sh"):
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                (scripts / "performance_environment.py").write_text(
                    "import pathlib, sys; pathlib.Path(sys.argv[1]).write_text('{}')\n"
                )
                baseline = root / "Performance/Baselines/simulator-60.json"
                baseline.parent.mkdir(parents=True)
                baseline.write_text(json.dumps({
                    "scenarios": ["navigation"], "mode": "observe",
                    "goals": {"minimumAverageFPS": 59, "minimumOnePercentLowFPS": 59, "maximumSevereStallCount": 0},
                }))
                report = {
                    "scenario": "navigation", "schemaVersion": 5, "iteration": 1,
                    "averageFPS": 30, "onePercentLowFPS": 20, "p95FrameMs": 50,
                    "p99FrameMs": 50, "maxFrameMs": 50, "missedDeadlineCount": 1,
                    "missedDeadlineRatio": 0.1, "severeStallCount": 1,
                }
                stub = scripts / "test.sh"
                stub.write_text(
                    '#!/bin/bash\nmkdir -p "$RESULTS_DIR"\n'
                    + 'cat > "$RESULTS_DIR/run.log" <<REPORT\n'
                    + "TRINKET_PERFORMANCE_REPORT " + json.dumps(report) + "\nREPORT\n"
                    + f"exit {test_status}\n"
                )
                stub.chmod(0o755)
                environment = {key: value for key, value in os.environ.items() if not key.startswith("TRINKET_PERFORMANCE_")}
                result = subprocess.run([str(scripts / "performance.sh")], env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, test_status, result.stdout + result.stderr)
                reports = list((root / ".DerivedData/PerformanceResults").glob("*/reports.json"))
                self.assertEqual(len(reports), 1)
                self.assertEqual(len(json.loads(reports[0].read_text())["reports"]), 1)
                self.assertFalse((root / ".DerivedData/.performance.lock").exists())
                environment["TRINKET_PERFORMANCE_OUTPUT_DIR"] = str(reports[0].parent)
                reused = subprocess.run([str(scripts / "performance.sh")], env=environment, capture_output=True, text=True)
                self.assertNotEqual(reused.returncode, 0)
                self.assertIn("already exists", reused.stderr)

    def test_help_exits_zero(self) -> None:
        for script, extra in (
            ("test.sh", []),
            ("build-for-testing.sh", []),
            ("test-scripts.sh", []),
            ("performance.sh", []),
        ):
            # performance.sh has no --help; it validates env first, so only
            # assert the wrappers that document --help here.
            if script == "performance.sh":
                continue
            result = run_script(script, "--help")
            self.assertEqual(result.returncode, 0, script + result.stderr)
            self.assertIn("Usage:", result.stdout, script)

    def test_unknown_arg_fails(self) -> None:
        for script in ("build-for-testing.sh", "test-scripts.sh"):
            result = run_script(script, "--definitely-not-a-flag")
            self.assertNotEqual(result.returncode, 0, script)
            self.assertIn("Unknown argument", result.stderr, script)

    def test_test_sh_unknown_option_fails(self) -> None:
        result = run_script("test.sh", "--definitely-not-a-flag")
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("Unknown option", result.stderr)

    def test_simulator_names_single_sourced(self) -> None:
        config = (ROOT / "Scripts" / "config" / "simulator-names.env").read_text()
        self.assertIn("Trinket Run", config)
        self.assertIn("Trinket Agent", config)
        shell = (ROOT / "Scripts" / "lib" / "simctl.sh").read_text()
        self.assertIn("simulator-names.env", shell)
        python = (ROOT / "Scripts" / "simctl_json.py").read_text()
        self.assertIn("simulator-names.env", python)

    def test_destructive_git_commands_single_sourced(self) -> None:
        config = (ROOT / "Scripts" / "config" / "destructive-git-commands.txt").read_text()
        names = [line.strip() for line in config.splitlines() if line.strip() and not line.startswith("#")]
        self.assertEqual(names, ["reset", "checkout", "restore", "clean", "switch", "branch", "push"])
        shim = (ROOT / "Scripts" / "bin" / "git").read_text()
        self.assertIn("destructive-git-commands.txt", shim)
        guard = (ROOT / "Scripts" / "git-safety-guard.mjs").read_text()
        self.assertIn("destructive-git-commands.txt", guard)

    def test_format_roots_derived_from_packages(self) -> None:
        text = (ROOT / "Scripts" / "format-dirs.env").read_text()
        self.assertIn("TRINKET_TEST_PACKAGES", text)
        self.assertNotIn("Packages/TrinketCore/Tests", text)


if __name__ == "__main__":
    unittest.main()
