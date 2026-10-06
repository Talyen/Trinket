from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/internal/output_retention.py',
    'Scripts/lib/output-retention.sh',
    'Scripts/aggregate-performance-results.py',
    'Scripts/collect-performance-results.py',
    'Scripts/compare-performance.py',
    'Scripts/internal/performance/performance_model.py',
    'Scripts/performance-scenarios.py',
    'Scripts/performance.sh',
    'Scripts/performance_environment.py',
)


import copy
import hashlib
import json
import unittest
from unittest import mock
from pathlib import Path

import os
import shutil
import tempfile
import subprocess
import sys

from script_test_support import ROOT, load_script

module = load_script('performance_scenarios', 'performance-scenarios.py')


class PerformanceScenarioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.baseline = json.loads((ROOT / 'Performance/Baselines/simulator-60.json').read_text())

    def test_provenance_hashes_exact_diff_and_unusual_untracked_source_names(self) -> None:
        environment = load_script('performance_environment', 'performance_environment.py')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', '-c', 'commit.gpgsign=false', *args], cwd=root,
                                      check=True, capture_output=True).stdout
            git('init', '-q')
            tracked = root / 'tracked.swift'
            tracked.write_bytes(b'before\r\n')
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'baseline')
            tracked.write_bytes(b'after\r\n')
            untracked = root / 'new source\nfile.swift'
            untracked.write_bytes(b'new source')
            original = environment.command
            def command(*args, **kwargs):
                if args[0] != 'git':
                    return 'fixture toolchain'
                with mock.patch.object(environment.subprocess, 'check_output',
                                       side_effect=lambda command, **options: git(*command[1:])):
                    return original(*args, **kwargs)
            output = root / 'environment.json'
            with mock.patch.object(environment, 'command', side_effect=command), \
                    mock.patch.object(sys, 'argv', ['performance_environment.py', str(output), '2']):
                # main hashes repository-relative untracked paths.
                previous = Path.cwd()
                try:
                    os.chdir(root)
                    environment.main()
                finally:
                    os.chdir(previous)
            payload = json.loads(output.read_text())
            self.assertEqual(payload['trackedDiffSHA256'], hashlib.sha256(git('diff', '--binary', 'HEAD')).hexdigest())
            self.assertEqual(payload['untrackedSourceSHA256'], {untracked.name: hashlib.sha256(untracked.read_bytes()).hexdigest()})

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

    def test_inventory_requires_measurement_in_its_registered_method(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / 'TrinketUITests/Performance'
            tests.mkdir(parents=True)
            (root / 'BattlePerformance.xctestplan').write_text(json.dumps({
                'testTargets': [{'selectedTests': ['FixtureUITests']}],
            }))
            source = tests / 'FixtureUITests.swift'
            baseline = {
                'scenarios': ['options-reset-cancel'],
                'coverage': {'options-reset-cancel': {'group': 'app', 'test': 'FixtureUITests/testOptions'}},
            }
            for body in ('', 'measured("options-controls") {}',
                         '// measured("options-reset-cancel") {}\n',
                         '/* measured("options-reset-cancel") {} */'):
                with self.subTest(body=body), mock.patch.object(module, 'ROOT', root):
                    # A measurement in a different test cannot satisfy this owner.
                    source.write_text('func testOptions() { ' + body + ' }\n'
                                      'func testOther() { measured("options-reset-cancel") {} }')
                    with self.assertRaisesRegex(ValueError, 'missing measurement in FixtureUITests/testOptions'):
                        module.select(baseline, [])
            for call in ('measured(\n "options-reset-cancel") {}',
                         'finishMeasurement("options-reset-cancel", iteration: 1)',
                         'run(scenario: "options-reset-cancel")',
                         'measured("options-reset-\\(action)") {}'):
                with self.subTest(call=call), mock.patch.object(module, 'ROOT', root):
                    source.write_text('func testOptions() { ' + call + ' }')
                    self.assertEqual(module.select(baseline, [])['scenarios'], baseline['scenarios'])

    def test_method_names_in_log_strings_cannot_reassign_measurements(self) -> None:
        methods = module.test_measurements(
            'func testNavigation() {\n'
            '  let message = "func testFake()"\n'
            '  measured("navigation") {}\n'
            '}\n'
            'func testOther() { measured("other") {} }'
        )
        self.assertEqual(methods, {'testNavigation': ['navigation'], 'testOther': ['other']})

    def test_performance_runner_retains_success_and_partial_failure_evidence(self) -> None:
        for test_status in (0, 1):
            with self.subTest(test_status=test_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                (scripts / "lib").mkdir(parents=True)
                for name in ("performance.sh", "performance-scenarios.py", "collect-performance-results.py", "compare-performance.py", "internal/cli.py", "internal/performance/performance_model.py", "lib/lock.sh", "lib/verification-policy.sh", "cleanup-outputs.py", "internal/output_retention.py", "lib/output-retention.sh"):
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
                (tests / "AppPerformanceUITests.swift").write_text('func testNavigation() { measured("navigation") {} }')
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
                environment["GITHUB_ACTIONS"] = "true"
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
