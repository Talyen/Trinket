from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/aggregate-performance-results.py',
    'Scripts/collect-performance-results.py',
    'Scripts/compare-performance.py',
    'Scripts/internal/performance/performance_model.py',
    'Scripts/performance-scenarios.py',
    'Scripts/performance.sh',
    'Scripts/performance_environment.py',
)


import copy
import importlib.util
import json
import unittest
from pathlib import Path

import os
import shutil
import tempfile
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('performance_scenarios', ROOT / 'Scripts/performance-scenarios.py')
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class PerformanceScenarioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.baseline = json.loads((ROOT / 'Performance/Baselines/simulator-60.json').read_text())

    def test_full_selection_and_group_selection_keep_exact_coverage(self) -> None:
        full = module.select(self.baseline, [])
        self.assertEqual(set(full['scenarios']), set(full['coverage']))
        group = next(iter(full['coverage'].values()))['group']
        selected = module.select(self.baseline, [group])
        self.assertTrue(selected['scenarios'])
        self.assertTrue(all(entry['group'] == group for entry in selected['coverage'].values()))
        scenario = selected['scenarios'][0]
        one = module.select(self.baseline, [scenario])
        self.assertEqual(one['scenarios'], [scenario])
        self.assertEqual(one['testScenarios'], {one['coverage'][scenario]['test']: [scenario]})

    def test_removed_route_mapping_is_not_silent(self) -> None:
        broken = copy.deepcopy(self.baseline)
        contract = broken['routeContracts'][0]
        del contract['routes'][next(iter(contract['routes']))]
        with self.assertRaisesRegex(ValueError, 'navigation changed'):
            module.select(broken, [])

    def test_unknown_selection_and_unregistered_tests_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, 'unknown'):
            module.select(self.baseline, ['not-a-scenario'])
        broken = copy.deepcopy(self.baseline)
        first = next(iter(broken['coverage']))
        broken['coverage'][first]['test'] = 'MissingUITests/testMissing'
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            module.select(broken, [])
        del broken['coverage'][first]
        with self.assertRaisesRegex(ValueError, 'differ'):
            module.select(broken, [])


    def test_performance_runner_retains_success_and_partial_failure_evidence(self) -> None:
        for test_status in (0, 1):
            with self.subTest(test_status=test_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                (scripts / "lib").mkdir(parents=True)
                for name in ("performance.sh", "performance-scenarios.py", "collect-performance-results.py", "compare-performance.py", "internal/cli.py", "internal/performance/performance_model.py", "lib/lock.sh"):
                    (scripts / name).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                (scripts / "performance_environment.py").write_text(
                    "import pathlib, sys; pathlib.Path(sys.argv[1]).write_text('{}')\n"
                )
                baseline = root / "Performance/Baselines/simulator-60.json"
                baseline.parent.mkdir(parents=True)
                baseline.write_text(json.dumps({
                    "scenarios": ["navigation"], "mode": "observe",
                    "coverage": {"navigation": {"group": "app", "test": "AppPerformanceUITests/testNavigation"}},
                    "goals": {"minimumAverageFPS": 59, "minimumOnePercentLowFPS": 59, "maximumSevereStallCount": 0},
                }))
                (root / "BattlePerformance.xctestplan").write_text(json.dumps({
                    "testTargets": [{"selectedTests": ["AppPerformanceUITests"]}]
                }))
                tests = root / "TrinketUITests/Performance"
                tests.mkdir(parents=True)
                (tests / "AppPerformanceUITests.swift").write_text("func testNavigation() {}")
                report = {
                    "scenario": "navigation", "schemaVersion": 5, "iteration": 1,
                    "averageFPS": 30, "onePercentLowFPS": 20, "p95FrameMs": 50,
                    "p99FrameMs": 50, "maxFrameMs": 50, "missedDeadlineCount": 1,
                    "missedDeadlineRatio": 0.1, "severeStallCount": 1,
                }
                stub = scripts / "test.sh"
                stub.write_text(
                    '#!/bin/bash\nmkdir -p "$RESULTS_DIR"\n'
                    + 'echo "$TRINKET_XCODE_WALL_TIMEOUT_SECONDS" > "$RESULTS_DIR/wall-budget.txt"\n'
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
                self.assertGreaterEqual(int((reports[0].parent / "TestResults/wall-budget.txt").read_text()), 1200)
                self.assertFalse((root / ".DerivedData/.performance.lock").exists())
                environment["TRINKET_PERFORMANCE_OUTPUT_DIR"] = str(reports[0].parent)
                reused = subprocess.run([str(scripts / "performance.sh")], env=environment, capture_output=True, text=True)
                self.assertNotEqual(reused.returncode, 0)
                self.assertIn("already exists", reused.stderr)
