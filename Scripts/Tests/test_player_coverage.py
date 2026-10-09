"""Requested profiles fail closed; cleanup and failed journeys retain their verdict."""
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/coverage_profiles.py', 'Scripts/player-coverage.sh', 'Scripts/ensure-simulator.sh',
    'Scripts/test.sh', '.github/workflows/player-coverage.yml',
)

import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script

MODULE = load_script('coverage_profiles', 'coverage_profiles.py')


class PlayerCoverageTests(unittest.TestCase):
    def test_explicit_runtime_and_device_requests_never_fall_back(self):
        runtimes = [dict(identifier=f'ios-{version}', version=version, platform='iOS', isAvailable=True)
                    for version in ('26.9', '26.10', '27.1')]
        types = [dict(identifier='compact')]
        self.assertEqual(MODULE.select_profile(runtimes, types, 'compact', 26)['identifier'], 'ios-26.10')
        for requested_type, major in [('tablet', 26), ('compact', 25)]:
            with self.subTest(device=requested_type, major=major), self.assertRaisesRegex(ValueError, 'unavailable'):
                MODULE.select_profile(runtimes, types, requested_type, major)
        runtimes[2]['supportedDeviceTypes'] = [dict(identifier='tablet')]
        with self.assertRaisesRegex(ValueError, 'incompatible'):
            MODULE.select_profile(runtimes, types, 'compact', 27)

    def test_native_text_size_restores_after_body_or_setting_failure(self):
        for fail in ('body', 'setting'):
            current, events = ['medium'], []
            def run(*args):
                events.append(args)
                if len(args) == 4:
                    current[0] = args[-1]
                    if fail == 'setting' and args[-1] == 'large':
                        raise RuntimeError('failed setter')
                return current[0]
            with self.subTest(fail=fail), self.assertRaises(RuntimeError):
                with MODULE.native_text_size('owned', 'large', run):
                    raise RuntimeError('journey failed')
            self.assertEqual(current[0], 'medium')
            self.assertIn(('ui', 'owned', 'content_size', 'medium'), events)
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            with MODULE.native_text_size('owned', 'large', lambda *args: 'unsupported'):
                self.fail('must not start unsupported profile')

    def test_failed_profile_is_recorded_and_other_settings_still_execute(self):
        current = ['large']
        def run(*args):
            if len(args) == 4:
                current[0] = args[-1]
            return current[0]
        with tempfile.TemporaryDirectory() as temporary, patch.object(MODULE, 'record_identity'), \
                patch.object(MODULE, 'simctl', side_effect=run), \
                patch.object(MODULE.subprocess, 'run', side_effect=[SimpleNamespace(returncode=1),
                    SimpleNamespace(returncode=0), SimpleNamespace(returncode=0)]) as command:
            # Default arguments bind at definition time: inject the native-setting
            # context through its real implementation with the controlled runner.
            native = MODULE.native_text_size
            with patch.object(MODULE, 'native_text_size', side_effect=lambda udid, size: native(udid, size, run)):
                output = Path(temporary) / 'profiles'
                self.assertEqual(MODULE.run_profiles('owned', output), 1)
            rows = json.loads((output / 'profiles.json').read_text())
            self.assertEqual([row['status'] for row in rows], ['failed', 'passed', 'passed'])
            self.assertEqual(command.call_count, 3)
            self.assertEqual(current[0], 'large')
            environment = command.call_args.kwargs['env']
            self.assertEqual(environment['TRINKET_UI_PLAN'], 'Profiles')
            self.assertEqual(environment['TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION'], '1')

    def test_soak_failure_does_not_hide_career_or_recovery_results(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            (scripts / 'player-coverage.sh').write_text((ROOT / 'Scripts/player-coverage.sh').read_text())
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" SIMULATOR_UDID=owned SIMULATOR_DESTINATION=fixture; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            for name, code in [('build-for-testing.sh', 0), ('test-package.sh', 0), ('test.sh', 1)]:
                path = scripts / name
                path.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name} $*" >> "$PWD/calls"\nexit {code}\n')
                path.chmod(0o755)
            binaries = root / 'bin'
            binaries.mkdir()
            python = binaries / 'python3'
            python.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$PWD/calls"\nexit 0\n')
            python.chmod(0o755)
            result = subprocess.run(['bash', 'Scripts/player-coverage.sh', 'soak'], cwd=root,
                                    env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}'}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            calls = (root / 'calls').read_text().splitlines()
            self.assertEqual(sum('--scenarios 1 --horizon 10' in line for line in calls), 20)
            self.assertEqual(sum('test-package.sh --build-for-testing' in line for line in calls), 1)
            self.assertEqual(sum('--crash-proof' in line for line in calls), 1)
            self.assertIn('--policy random-v1', next(line for line in calls if '--seed 102' in line))

    def test_advisory_status_propagates_failed_or_cancelled_requested_jobs(self):
        workflow = (ROOT / '.github/workflows/player-coverage.yml').read_text()
        command = workflow.split('      - name: Report actual requested-job conclusions', 1)[1].split('        run: |\n', 1)[1]
        command = '\n'.join(line[10:] for line in command.splitlines())
        with tempfile.TemporaryDirectory() as temporary:
            for profiles, soak, expected in [('success', 'skipped', 0), ('failure', 'success', 1),
                                              ('success', 'cancelled', 1)]:
                result = subprocess.run(['bash', '-ec', command], env={**os.environ,
                    'PROFILES': profiles, 'SOAK': soak, 'GITHUB_STEP_SUMMARY': str(Path(temporary) / 'summary')},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
