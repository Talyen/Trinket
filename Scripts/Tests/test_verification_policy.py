"""Routine laptop verification cannot start compiled or simulator workloads."""
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/lib/verification-policy.sh',
    'Scripts/handoff.sh',
    'Scripts/test.sh',
    'Scripts/test-package.sh', 'Scripts/test-package-host.sh', 'Scripts/test-ci-packages.sh',
    'Scripts/build-for-testing.sh',
    'Scripts/performance.sh',
    'Scripts/ci-gate.sh',
    'Scripts/test-deploy.sh',
    'Scripts/playthrough-sweep.sh',
    'Scripts/lib/app-build.sh',
)

import subprocess
import tempfile
from pathlib import Path
from script_test_support import ROOT, ScriptRegressionTestCase


class VerificationPolicyTests(ScriptRegressionTestCase):
    def test_playthrough_refuses_local_work_before_simulator_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            for name in ('playthrough-sweep.sh', 'lib/verification-policy.sh'):
                (scripts / name).write_text((ROOT / 'Scripts' / name).read_text())
            # The fixture must never boot a real simulator, even before the fix.
            (scripts / 'run-env.sh').write_text('trinket_run_env_init() { echo prepared > preparation; return 99; }\n')
            (scripts / 'ensure-simulator.sh').write_text('')
            for settings, expected in (({}, 2), ({'GITHUB_ACTIONS': 'true'}, 99),
                                       ({'TRINKET_ALLOW_HEAVY_LOCAL': '1'}, 99)):
                with self.subTest(settings=settings):
                    prepared = root / 'preparation'
                    prepared.unlink(missing_ok=True)
                    result = subprocess.run(['bash', 'Scripts/playthrough-sweep.sh'], cwd=root,
                                            env=self.verification_environment(**settings), capture_output=True, text=True)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    self.assertEqual(prepared.exists(), expected == 99)

    def test_heavy_entrypoints_refuse_local_work_before_preparation(self):
        for command in (
            ['Scripts/test.sh', 'smoke', 'SmokeBattleTests'],
            ['Scripts/test.sh', 'ui', 'BattleFlowUITests'],
            ['Scripts/test.sh', 'unit'],
            ['Scripts/test-package.sh', 'TrinketCore'],
            ['Scripts/test-package-host.sh', 'TrinketCore'],
            ['Scripts/test-ci-packages.sh', 'TrinketCore'],
            ['Scripts/build-for-testing.sh', '--app-only'],
            ['Scripts/performance.sh', '--group', 'battle'],
            ['Scripts/ci-gate.sh'],
            ['Scripts/test-deploy.sh'],
        ):
            with self.subTest(command=command):
                result = subprocess.run(['bash', *command], cwd=ROOT, env=self.verification_environment(),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn('CI-owned', result.stderr)
                self.assertNotIn('run-env mode=', result.stdout)

    def test_ci_policy_and_deliberate_local_diagnostics(self):
        command = 'source Scripts/lib/verification-policy.sh; trinket_require_heavy_verification test; env'
        ci = subprocess.run(['bash', '-ec', command], cwd=ROOT, env=self.verification_environment(GITHUB_ACTIONS='true'),
                            capture_output=True, text=True)
        self.assertEqual(ci.returncode, 0, ci.stderr)
        local = subprocess.run(['bash', '-ec', command], cwd=ROOT,
                               env=self.verification_environment(TRINKET_ALLOW_HEAVY_LOCAL='1'), capture_output=True, text=True)
        self.assertEqual(local.returncode, 0, local.stderr)
        self.assertIn('TRINKET_PACKAGE_TEST_JOBS=1', local.stdout)
        self.assertIn('TRINKET_MAX_CONCURRENT_UI=1', local.stdout)

    def test_local_handoff_lists_heavy_work_as_deferred(self):
        result = subprocess.run(['bash', 'Scripts/handoff.sh', '--dry-run', '--smoke', '--paths',
                                 'Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Accessibility/AccessibilityID.swift'],
                                cwd=ROOT, env=self.verification_environment(), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        local, deferred = result.stdout.split('Deferred to CI:', 1)
        self.assertNotIn('test-package.sh', local)
        self.assertNotIn('build.sh', local)
        self.assertNotIn('test.sh smoke', local)
        self.assertIn('test-package.sh TrinketFeatureSupport', deferred)
        self.assertIn('test.sh smoke', deferred)

    def test_game_builds_keep_the_local_architecture_with_two_workers(self):
        command = 'source Scripts/lib/app-build.sh; trinket_set_local_simulator_architecture_args iphonesimulator Debug; printf "%s\\n" "${TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS[@]}"'
        result = subprocess.run(['bash', '-ec', command], cwd=ROOT, env=self.verification_environment(),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[-2:], ['-jobs', '2'])
