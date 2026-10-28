"""Requested profiles fail closed; cleanup and failed journeys retain their verdict."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script, run_captured, write_executable, write_json

MODULE = load_script('coverage_profiles', 'coverage_profiles.py')
CLEANUP = load_script('ci_runtime_cleanup', 'ci-runtime-cleanup.py')


class PlayerCoverageTests(unittest.TestCase):
    def test_profile_simctl_queries_have_a_deadline(self):
        with patch.object(MODULE.subprocess, 'check_output', return_value='inventory\n') as query:
            self.assertEqual(MODULE.simctl('list', 'runtimes', '-j'), 'inventory')
        query.assert_called_once_with(['xcrun', 'simctl', 'list', 'runtimes', '-j'], text=True, timeout=30)
        with patch.object(MODULE.subprocess, 'check_output', side_effect=subprocess.TimeoutExpired('simctl', 30)):
            with self.assertRaises(subprocess.TimeoutExpired):
                MODULE.simctl('list', 'runtimes', '-j')

    def test_runtime_cleanup_preserves_busy_foreign_and_non_deletable_images(self):
        identifiers = [f'00000000-0000-0000-0000-{index:012d}' for index in range(1, 5)]
        images = {identifier: dict(identifier=identifier, state='Ready', deletable=True,
                                   platformIdentifier='com.apple.platform.iphonesimulator') for identifier in identifiers}
        images[identifiers[1]]['state'] = 'Deleting'
        del images[identifiers[1]]['deletable']
        images[identifiers[2]]['platformIdentifier'] = 'com.apple.platform.watchsimulator'
        images[identifiers[3]]['deletable'] = False
        timeout = subprocess.TimeoutExpired(['xcrun', 'simctl', 'runtime', 'list'], 10)
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(CLEANUP.subprocess, 'check_output', side_effect=[timeout, json.dumps(images)]) as inventory, \
                patch.object(CLEANUP.subprocess, 'run') as delete:
            CLEANUP.cleanup(Path(directory), dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted'))
            delete.assert_called_once_with(['xcrun', 'simctl', 'runtime', 'delete', identifiers[0]], check=True, timeout=180)
            self.assertEqual([call.kwargs['timeout'] for call in inventory.call_args_list], [10, 30])
            receipt = json.loads((Path(directory) / 'runtime-cleanup.json').read_text())
            self.assertEqual([attempt['status'] for attempt in receipt['inventory_attempts']], ['timeout', 'passed'])

    def test_runtime_cleanup_never_deletes_from_incomplete_or_exhausted_inventory(self):
        identifier = '00000000-0000-0000-0000-000000000001'
        valid = dict(identifier=identifier, state='Ready', deletable=True, platformIdentifier='com.apple.platform.iphonesimulator')
        bad = json.dumps({identifier: valid, '00000000-0000-0000-0000-000000000002': {}})
        timeout = subprocess.TimeoutExpired(['xcrun', 'simctl', 'runtime', 'list'], 10)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            for replies, expected in [([bad], ValueError), ([timeout, timeout], subprocess.TimeoutExpired)]:
                with patch.object(CLEANUP.subprocess, 'check_output', side_effect=replies), \
                        patch.object(CLEANUP.subprocess, 'run') as delete, self.assertRaises(expected):
                    try:
                        CLEANUP.cleanup(output, dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted'))
                    finally:
                        delete.assert_not_called()
                receipt = json.loads((output / 'runtime-cleanup.json').read_text())
                self.assertEqual(receipt['status'], 'failed')
            self.assertEqual([attempt['status'] for attempt in receipt['inventory_attempts']], ['timeout', 'timeout'])
            with patch.object(CLEANUP.subprocess, 'check_output') as inventory, self.assertRaises(ValueError):
                CLEANUP.cleanup(output, dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='self-hosted'))
            inventory.assert_not_called()

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

    def test_exact_runtime_does_not_switch_to_newer_or_incompatible_minor(self):
        runtimes = [dict(identifier='ios-27.0', version='27.0', platform='iOS', isAvailable=True,
                         supportedDeviceTypes=[dict(identifier='phone')]),
                    dict(identifier='ios-27.1', version='27.1', platform='iOS', isAvailable=True,
                         supportedDeviceTypes=[dict(identifier='duo')])]
        types = [dict(identifier='phone')]
        self.assertEqual(MODULE.select_profile(runtimes, types, 'phone', 27, '27.0.0')['identifier'], 'ios-27.0')
        for version, error in [('27.2', 'unavailable'), ('27.1', 'incompatible'), ('26.0', 'conflicting'), ('27', 'invalid')]:
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, error):
                MODULE.select_profile(runtimes, types, 'phone', 27, version)

    def test_runtime_version_ties_select_the_newest_build_in_either_inventory_order(self):
        older = dict(identifier='ios-26.2', version='26.2.0', buildversion='23C52',
                     platform='iOS', isAvailable=True)
        newer = dict(older, version='26.2', buildversion='23C54')
        for runtimes in ([older, newer], [newer, older]):
            for version in (None, '26.2'):
                with self.subTest(inventory=runtimes, version=version):
                    self.assertEqual(MODULE.select_profile(runtimes, [dict(identifier='phone')],
                                                          'phone', 26, version), newer)

    def test_parallel_runtime_trains_preserve_device_compatibility_without_minor_fallback(self):
        phone = dict(identifier='ios-27.1', version='27.1', buildversion='24A94232',
                     platform='iOS', isAvailable=True, supportedDeviceTypes=[dict(identifier='phone')])
        duo = dict(phone, buildversion='24A94425', supportedDeviceTypes=[dict(identifier='duo')])
        for runtimes in ([phone, duo], [duo, phone]):
            for version in (None, '27.1'):
                with self.subTest(inventory=runtimes, version=version):
                    self.assertEqual(MODULE.select_profile(runtimes, [dict(identifier='phone')],
                                                          'phone', 27, version), phone)
        with self.assertRaisesRegex(ValueError, 'incompatible'):
            MODULE.select_profile([phone, dict(duo, version='27.2')], [dict(identifier='phone')], 'phone', 27)

    def test_runtime_preparation_installs_missing_major_and_validates_the_result(self):
        for name, architecture, variant in [('compact', 'arm64', 'arm64'),
                                             ('ios18', 'x86_64', 'universal')]:
            device, major = MODULE.PROFILES[name]
            types = json.dumps({'devicetypes': [dict(identifier=device)]})
            missing = json.dumps({'runtimes': []})
            available = json.dumps({'runtimes': [dict(identifier=f'ios-{major}', version=f'{major}.0',
                                                       platform='iOS', isAvailable=True)]})
            with self.subTest(profile=name), patch.object(MODULE.platform, 'machine', return_value=architecture), \
                    patch.object(MODULE, 'simctl', side_effect=[types, missing, available]), \
                    patch.object(MODULE.subprocess, 'run') as install:
                MODULE.prepare_profile(name)
                install.assert_called_once_with(
                    ['xcodebuild', '-downloadPlatform', 'iOS', '-buildVersion', f'{major}.0',
                     '-architectureVariant', variant], check=True, timeout=1800)
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

    def test_duo_preparation_requires_27_1_even_when_27_0_is_installed(self):
        device, major = MODULE.PROFILES['duo']
        types = json.dumps({'devicetypes': [dict(identifier=device)]})
        older = dict(identifier='ios-27.0', version='27.0', platform='iOS', isAvailable=True)
        supported = dict(identifier='ios-27.1', version='27.1', platform='iOS', isAvailable=True,
                         supportedDeviceTypes=[dict(identifier=device)])
        with patch.object(MODULE, 'simctl', side_effect=[types, json.dumps({'runtimes': [older]}),
                json.dumps({'runtimes': [older, supported]})]), \
                patch.object(MODULE.platform, 'machine', return_value='arm64'), \
                patch.object(MODULE.subprocess, 'run') as install:
            MODULE.prepare_profile('duo')
            install.assert_called_once_with(
                ['xcodebuild', '-downloadPlatform', 'iOS', '-buildVersion', '27.1',
                 '-architectureVariant', 'arm64'], check=True, timeout=1800)
        with self.assertRaisesRegex(ValueError, 'unavailable iOS 27.1'):
            MODULE.select_profile([older], [dict(identifier=device)], device, major)
        self.assertEqual(MODULE.select_profile([older, supported], [dict(identifier=device)], device, major), supported)

    def test_failed_profile_is_recorded_and_other_settings_still_execute(self):
        for policy in [(), ('all',), ('representative',)]:
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
                    self.assertEqual(MODULE.run_profiles('owned', output, *policy), 1)
                rows = json.loads((output / 'profiles.json').read_text())
                self.assertEqual([row['status'] for row in rows], ['failed', 'passed', 'passed'])
                self.assertEqual(command.call_count, 3)
                self.assertEqual(current[0], 'large')
                self.assertEqual(writes, [MODULE.TEXT_SIZES[1], 'large'])
                self.assertEqual([row['nativeAuditsRequested'] for row in rows],
                                 [False, True, False] if policy == ('representative',) else [True] * 3)
                self.assertEqual([call.kwargs['env']['TEST_RUNNER_TRINKET_PROFILE_AUDIT_POLICY']
                                  for call in command.call_args_list], [policy[0] if policy else 'all'] * 3)
                environment = command.call_args.kwargs['env']
                self.assertEqual(environment['RESULTS_DIR'], '/fixture/built-results')
                self.assertEqual(environment['TRINKET_UI_PLAN'], 'Profiles')
                self.assertEqual(environment['TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION'], '1')
        with self.assertRaisesRegex(ValueError, 'unsupported native audit policy'):
            MODULE.run_profiles('owned', Path('/unused'), 'typo')

    def test_profile_artifacts_keep_screenshots_and_fall_back_to_full_bundle(self):
        for category, export_fails in [('passed', False), ('passed', True), ('passed', 'empty'), ('test-failure', False)]:
            with self.subTest(category=category, export_fails=export_fails), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                results, output = root / 'TestResults', root / 'artifact'
                results.mkdir()
                output.mkdir()
                write_json(results / 'ci-diagnostics.json', dict(category=category))
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
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\ntrinket_host_admit() { :; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" RESULTS_DIR="$PWD/data/TestResults" SIMULATOR_UDID=owned SIMULATOR_DESTINATION=fixture; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            for name, code in [('build-for-testing.sh', 0), ('test-package.sh', 0), ('test.sh', 1)]:
                write_executable(scripts / name, f'#!/bin/sh\nprintf "%s\\n" "{name} $* results=$RESULTS_DIR" >> "$PWD/calls"\nexit {code}\n')
            binaries = root / 'bin'
            binaries.mkdir()
            write_executable(binaries / 'python3', '#!/bin/sh\nprintf "%s\\n" "$*" >> "$PWD/calls"\nexit 0\n')
            run_captured(['bash', 'Scripts/player-coverage.sh', 'soak'], cwd=root, env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}'}, expected=1)
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
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\ntrinket_host_admit() { :; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" RESULTS_DIR="$PWD/data/TestResults" SIMULATOR_UDID=owned SIMULATOR_DESTINATION=fixture-ios18; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            for name in ('test.sh', 'test-package.sh'):
                write_executable(scripts / name, '''#!/bin/sh
printf '%s\n' "$0 $* major=$TRINKET_SIM_OS_MAJOR purchase=$TEST_RUNNER_TRINKET_REQUIRED_PURCHASE screenshots=$TRINKET_UI_SUCCESS_SCREENSHOTS" >> "$PWD/calls"
exit 0
''')
            binaries = root / 'bin'
            binaries.mkdir()
            write_executable(binaries / 'python3', '''#!/bin/sh
case "$*" in
  *'definition --name ios18') printf 'fixture-phone\t18\n' ;;
  *'--classes Smoke') printf 'SmokeBattleTests SmokeShellTests FullGamePurchaseSmokeTests\n' ;;
  *'coverage_profiles.py run'*) printf '%s\n' "$*" > "$PWD/profile-command"; exit 1 ;;
  *) exit 2 ;;
esac
''')
            run_captured(
                ['bash', 'Scripts/player-coverage.sh', 'ios18'],
                cwd=root,
                env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}', 'TRINKET_COVERAGE_NO_BUILD': '1'},
                expected=1,
            )
            calls = (root / 'calls').read_text().splitlines()
            self.assertTrue((root / 'profile-command').read_text().strip().endswith('--audit-policy all'))
            self.assertEqual(len(calls), 3)
            self.assertIn('smoke --no-build SmokeBattleTests SmokeShellTests FullGamePurchaseSmokeTests', calls[0])
            self.assertIn('FullGamePurchaseUITests', calls[1])
            self.assertIn('BattleLifecycleUITests/testCommittedRewardSurvivesTerminationWithoutReseeding', calls[1])
            self.assertIn('--destination fixture-ios18 TrinketPersistence', calls[2])
            self.assertTrue(all('major=18 purchase=1 screenshots=1' in call for call in calls))

    def test_nightly_audit_sampling_retains_weekly_manual_and_soak_coverage(self):
        workflow = (ROOT / '.github/workflows/player-coverage.yml').read_text()
        self.assertIn("- cron: '0 8 * * 0'", workflow)
        for job, scope in [('ios18-runtime', 'compatibility'), ('compatibility', 'compatibility'), ('profiles', 'profiles')]:
            section = workflow.split(f'  {job}:\n', 1)[1].split('    runs-on:', 1)[0]
            condition = f"(github.event_name == 'schedule' && github.event.schedule != '0 9 * * 0') || inputs.scope == '{scope}' || inputs.scope == 'all'"
            self.assertIn(f'if: {condition}', section)
            self.assertIn(f"${{{{ {condition} }}}}", workflow)
        self.assertEqual(workflow.count(
            "TRINKET_COVERAGE_AUDIT_POLICY: ${{ github.event.schedule == '0 8 * * 1-6' && 'representative' || 'all' }}"), 2)
        self.assertIn("if: github.event.schedule == '0 9 * * 0' || inputs.scope == 'soak' || inputs.scope == 'all'", workflow)

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
                result = run_captured(
                    ['bash', '-ec', command], cwd=ROOT,
                    env={
                        **os.environ,
                        'JOB_RESULTS': json.dumps({name: {'result': result} for name, result in zip(
                            ('ios18-runtime', 'compatibility', 'profiles', 'soak'), (runtime, compatibility, profiles, soak))}),
                        'COMPATIBILITY_REQUESTED': str(runtime != 'skipped').lower(),
                        'PROFILES_REQUESTED': str(profiles != 'skipped').lower(),
                        'SOAK_REQUESTED': str(soak != 'skipped').lower(),
                        'GITHUB_STEP_SUMMARY': str(Path(temporary) / 'summary'),
                    },
                )
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_unavailable_device_runtime_does_not_suppress_other_hosted_profiles(self):
        workflow = (ROOT / '.github/workflows/player-coverage.yml').read_text()
        step = workflow.split('      - name: Run requested profiles serially', 1)[1]
        command = step.split('        run: |\n', 1)[1].split('      - name:', 1)[0]
        command = '\n'.join(line[10:] for line in command.splitlines())
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Scripts').mkdir()
            binaries = root / 'bin'
            binaries.mkdir()
            write_executable(binaries / 'python3', '''#!/bin/sh
printf 'prepare %s\n' "$4" >> "$PWD/calls"
if [ "$4" = "$FAILED_PREREQUISITE" ]; then exit 2; fi
''')
            write_executable(root / 'Scripts/player-coverage.sh', '''#!/bin/sh
printf 'run %s\n' "$1" >> "$PWD/calls"
if [ "$1" = "$FAILED_JOURNEY" ]; then exit 1; fi
''')
            for prerequisite, journey, expected in [('compact', 'tablet', 1), ('', '', 0)]:
                with self.subTest(prerequisite=prerequisite, journey=journey):
                    calls = root / 'calls'
                    calls.unlink(missing_ok=True)
                    result = run_captured(['bash', '-ec', command], cwd=root, env={
                        **os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}',
                        'FAILED_PREREQUISITE': prerequisite, 'FAILED_JOURNEY': journey,
                        'GITHUB_STEP_SUMMARY': str(root / 'summary'),
                    })
                    self.assertEqual(result.returncode, expected, result.stderr)
                    self.assertEqual(calls.read_text().splitlines(),
                                     ['prepare compact'] + ([] if prerequisite else ['run compact'])
                                     + ['prepare tablet', 'run tablet', 'prepare duo', 'run duo'])

    def test_duo_rotation_still_executes_when_settings_profiles_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / 'Scripts'
            (scripts / 'lib').mkdir(parents=True)
            (scripts / 'player-coverage.sh').write_text((ROOT / 'Scripts/player-coverage.sh').read_text())
            (scripts / 'lib/verification-policy.sh').write_text('trinket_require_heavy_verification() { return 0; }\ntrinket_host_admit() { :; }\n')
            (scripts / 'run-env.sh').write_text('''trinket_run_env_init() { export DERIVED_DATA_PATH="$PWD/data" RESULTS_DIR="$PWD/data/TestResults" SIMULATOR_UDID=owned; }
trinket_sim_slot_ensure() { :; }
trinket_run_env_install_self_clean() { :; }
''')
            (scripts / 'ensure-simulator.sh').write_text('ensure_test_simulator_logged() { :; }\n')
            write_executable(scripts / 'test.sh', '''#!/bin/sh
printf '%s\\n' "$* plan=$TRINKET_UI_PLAN duo=$TEST_RUNNER_TRINKET_DUO_PROFILE" >> "$PWD/calls"
''')
            binaries = root / 'bin'
            binaries.mkdir()
            write_executable(binaries / 'python3', '''#!/bin/sh
case "$*" in
  *'definition --name duo') printf 'fixture-duo\\t27\\n' ;;
  *'coverage_profiles.py run'*) printf '%s\\n' "$*" > "$PWD/profile-command"; exit 1 ;;
  *) exit 2 ;;
esac
''')
            run_captured(['bash', 'Scripts/player-coverage.sh', 'duo'], cwd=root,
                         env={**os.environ, 'PATH': f'{binaries}:{os.environ["PATH"]}',
                              'TRINKET_COVERAGE_NO_BUILD': '1', 'TRINKET_UI_PLAN': 'Profiles',
                              'TRINKET_COVERAGE_AUDIT_POLICY': 'representative'}, expected=1)
            self.assertTrue((root / 'profile-command').read_text().strip().endswith('--audit-policy representative'))
            self.assertEqual((root / 'calls').read_text().strip(),
                             'ui --no-build DuoRotationUITests/testDuoRotationPreservesBattleAndCardPlay plan=Profiles duo=1')
