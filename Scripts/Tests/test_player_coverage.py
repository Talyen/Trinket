"""Requested profiles fail closed; cleanup and failed journeys retain their verdict."""
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/coverage_profiles.py', 'Scripts/player-coverage.sh', 'Scripts/ensure-simulator.sh',
    'Scripts/test.sh', '.github/workflows/player-coverage.yml', '.github/actions/coverage-products/action.yml',
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
                    for version in ('26.9', '26.10', '27.1', '18.0', '18.7')]
        types = [dict(identifier='compact')]
        self.assertEqual(MODULE.select_profile(runtimes, types, 'compact', 26)['identifier'], 'ios-26.10')
        self.assertEqual(MODULE.select_profile(runtimes, types, 'compact', 18)['identifier'], 'ios-18.7')
        for requested_type, major in [('tablet', 26), ('compact', 25)]:
            with self.subTest(device=requested_type, major=major), self.assertRaisesRegex(ValueError, 'unavailable'):
                MODULE.select_profile(runtimes, types, requested_type, major)
        runtimes[2]['supportedDeviceTypes'] = [dict(identifier='tablet')]
        with self.assertRaisesRegex(ValueError, 'incompatible'):
            MODULE.select_profile(runtimes, types, 'compact', 27)

    def test_runtime_preparation_installs_missing_major_and_validates_the_result(self):
        for name in ('compact', 'ios18'):
            device, major = MODULE.PROFILES[name]
            types = json.dumps({'devicetypes': [dict(identifier=device)]})
            missing = json.dumps({'runtimes': []})
            available = json.dumps({'runtimes': [dict(identifier=f'ios-{major}', version=f'{major}.0',
                                                       platform='iOS', isAvailable=True)]})
            with self.subTest(profile=name), patch.object(MODULE, 'simctl', side_effect=[types, missing, available]), \
                    patch.object(MODULE.subprocess, 'run') as install:
                MODULE.prepare_profile(name)
                install.assert_called_once_with(
                    ['xcodebuild', '-downloadPlatform', 'iOS', '-buildVersion', f'{major}.0',
                     '-architectureVariant', 'universal'], check=True, timeout=1800)
            with patch.object(MODULE, 'simctl', side_effect=[types, available]), \
                    patch.object(MODULE.subprocess, 'run') as install:
                MODULE.prepare_profile(name)
                install.assert_not_called()
            with patch.object(MODULE, 'simctl', side_effect=[types, missing, missing]), \
                    patch.object(MODULE.subprocess, 'run'), self.assertRaisesRegex(ValueError, f'unavailable iOS {major}'):
                MODULE.prepare_profile(name)

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
        current, writes = ['large'], []
        def run(*args):
            if len(args) == 4:
                current[0] = args[-1]
                writes.append(args[-1])
            return current[0]
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'RESULTS_DIR': '/fixture/built-results'}), \
                patch.object(MODULE, 'record_identity'), \
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
            self.assertEqual(writes, [MODULE.TEXT_SIZES[1], 'large'])
            environment = command.call_args.kwargs['env']
            self.assertEqual(environment['RESULTS_DIR'], '/fixture/built-results')
            self.assertEqual(environment['TRINKET_UI_PLAN'], 'Profiles')
            self.assertEqual(environment['TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION'], '1')

    def test_profile_artifacts_keep_screenshots_and_fall_back_to_full_bundle(self):
        for category, export_fails in [('passed', False), ('passed', True), ('passed', 'empty'), ('test-failure', False)]:
            with self.subTest(category=category, export_fails=export_fails), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                results, output = root / 'TestResults', root / 'artifact'
                results.mkdir()
                output.mkdir()
                (results / 'ci-diagnostics.json').write_text(json.dumps(dict(category=category)))
                bundle = results / 'profile.xcresult'
                bundle.mkdir()
                (bundle / 'Info.plist').write_text('audit evidence')
                def run(command, **kwargs):
                    if command[0] == 'xcrun':
                        if export_fails is True:
                            raise subprocess.TimeoutExpired(command, 60)
                        if not export_fails:
                            screenshots = Path(command[command.index('--output-path') + 1])
                            screenshots.mkdir()
                            (screenshots / 'audit.png').write_bytes(b'fixture pixels')
                with patch.object(MODULE.subprocess, 'run', side_effect=run) as command:
                    MODULE.stage_results(results, output)
                exports = [call.args[0] for call in command.call_args_list if call.args[0][0] == 'xcrun']
                self.assertEqual(len(exports), int(category == 'passed'))
                if exports:
                    self.assertIn('*.png', exports[0])
                self.assertEqual((output / bundle.name / 'Info.plist').exists(), bool(export_fails))

    def test_soak_failure_does_not_hide_career_or_recovery_results(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            (scripts / 'player-coverage.sh').write_text((ROOT / 'Scripts/player-coverage.sh').read_text())
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" RESULTS_DIR="$PWD/data/TestResults" SIMULATOR_UDID=owned SIMULATOR_DESTINATION=fixture; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            for name, code in [('build-for-testing.sh', 0), ('test-package.sh', 0), ('test.sh', 1)]:
                path = scripts / name
                path.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name} $* results=$RESULTS_DIR" >> "$PWD/calls"\nexit {code}\n')
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
            cohorts = [line.split() for line in calls if '--batch' in line]
            self.assertEqual(len(cohorts), 1)
            self.assertIn('--coverage-portfolio', cohorts[0])
            self.assertIn('--horizon 10', ' '.join(cohorts[0]))
            self.assertEqual(sum('test-package.sh --build-for-testing' in line for line in calls), 1)
            self.assertEqual(sum('--crash-proof' in line for line in calls), 1)
            self.assertIn(f'test.sh ui --no-build RepeatedPlayUITests results={root.resolve()}/data/TestResults', calls)

    def test_ios18_failure_still_runs_purchase_recovery_and_durable_store_checks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            (scripts / 'player-coverage.sh').write_text((ROOT / 'Scripts/player-coverage.sh').read_text())
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" RESULTS_DIR="$PWD/data/TestResults" SIMULATOR_UDID=owned SIMULATOR_DESTINATION=fixture-ios18; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            for name in ('test.sh', 'test-package.sh'):
                path = scripts / name
                path.write_text('''#!/bin/sh
printf '%s\n' "$0 $* major=$TRINKET_SIM_OS_MAJOR purchase=$TEST_RUNNER_TRINKET_REQUIRED_PURCHASE screenshots=$TRINKET_UI_SUCCESS_SCREENSHOTS" >> "$PWD/calls"
exit 0
''')
                path.chmod(0o755)
            binaries = root / 'bin'
            binaries.mkdir()
            python = binaries / 'python3'
            python.write_text('''#!/bin/sh
case "$*" in
  *'definition --name ios18') printf 'fixture-phone\t18\n' ;;
  *'--classes Smoke') printf 'SmokeBattleTests StarterOnboardingSmokeTests FullGamePurchaseSmokeTests\n' ;;
  *'coverage_profiles.py run'*) exit 1 ;;
  *) exit 2 ;;
esac
''')
            python.chmod(0o755)
            result = subprocess.run(['bash', 'Scripts/player-coverage.sh', 'ios18'], cwd=root,
                                    env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}',
                                         'TRINKET_COVERAGE_NO_BUILD': '1'}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            calls = (root / 'calls').read_text().splitlines()
            self.assertEqual(len(calls), 3)
            self.assertIn('smoke --no-build SmokeBattleTests StarterOnboardingSmokeTests FullGamePurchaseSmokeTests', calls[0])
            self.assertIn('FullGamePurchaseUITests', calls[1])
            self.assertIn('BattleLifecycleUITests/testCommittedRewardSurvivesTerminationWithoutReseeding', calls[1])
            self.assertIn('--destination fixture-ios18 TrinketPersistence', calls[2])
            self.assertTrue(all('major=18 purchase=1 screenshots=1' in call for call in calls))

    def test_advisory_status_propagates_failed_or_cancelled_requested_jobs(self):
        workflow = (ROOT / '.github/workflows/player-coverage.yml').read_text()
        command = workflow.split('      - name: Report actual requested-job conclusions', 1)[1].split('        run: |\n', 1)[1]
        command = '\n'.join(line[10:] for line in command.splitlines())
        with tempfile.TemporaryDirectory() as temporary:
            for runtime, compatibility, profiles, soak, expected in [('success', 'success', 'success', 'skipped', 0),
                    ('success', 'failure', 'success', 'success', 1), ('success', 'cancelled', 'success', 'skipped', 1),
                    ('skipped', 'skipped', 'failure', 'success', 1), ('success', 'success', 'success', 'cancelled', 1),
                    ('failure', 'skipped', 'skipped', 'skipped', 1), ('cancelled', 'skipped', 'skipped', 'skipped', 1),
                    ('skipped', 'skipped', 'success', 'skipped', 0)]:
                result = subprocess.run(['bash', '-ec', command], env={**os.environ,
                    'IOS18_RUNTIME': runtime, 'COMPATIBILITY': compatibility, 'PROFILES': profiles,
                    'SOAK': soak, 'GITHUB_STEP_SUMMARY': str(Path(temporary) / 'summary')},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
