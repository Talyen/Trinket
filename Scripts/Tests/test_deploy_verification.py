"""Release retries must retain only proven phases for unchanged inputs."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
from unittest.mock import patch

from script_test_support import load_script

DEPLOY = load_script('deploy_verification_test', 'deploy-verification.py')


class DeployVerificationTests(unittest.TestCase):
    def test_ui_overlaps_hosted_verification_and_missing_proof_runs_all_remaining_checks(self):
        for hosted in (None, {'run-id': '10'}):
            with self.subTest(hosted=hosted), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'verification.json'
                commands = []
                def capture(*command):
                    if command[:2] == ('git', 'rev-parse'):
                        return 'abc'
                    if command[0] == 'git':
                        return ''
                    if command[0] == 'bash':
                        return 'OnePackage\nTwoPackage'
                    return 'SecondTests FirstTests'
                with patch.dict(DEPLOY.os.environ, {'TRINKET_DEPLOY_VERIFICATION_STATE': str(path)}), \
                        patch.object(sys, 'argv', ['deploy-verification.py']), \
                        patch.object(DEPLOY, 'profile', return_value={'runtime': '26.2'}), \
                        patch.object(DEPLOY.BUILD, 'identity', return_value={'commit': 'abc'}), \
                        patch.object(DEPLOY, 'capture', side_effect=capture), \
                        patch.object(DEPLOY, 'hosted_proof', return_value=hosted), \
                        patch.object(DEPLOY.subprocess, 'run', side_effect=lambda command, **_: commands.append(command)):
                    DEPLOY.main()
                self.assertEqual(commands[:3], [
                    ['./Scripts/build-for-testing.sh', '--reuse', '--app-only'],
                    ['./Scripts/test.sh', 'ui', '--no-build', 'FirstTests'],
                    ['./Scripts/test.sh', 'ui', '--no-build', 'SecondTests']])
                if hosted:
                    self.assertEqual(len(commands), 3)
                else:
                    self.assertEqual(commands[3:], [
                        ['./Scripts/ci-gate.sh'], ['./Scripts/build-for-testing.sh', '--reuse'],
                        ['./Scripts/test-package.sh', '--no-build', 'OnePackage'],
                        ['./Scripts/test-package.sh', '--no-build', 'TwoPackage']])
                self.assertEqual(set(json.loads(path.read_text())['completed']),
                                 {'ui:FirstTests', 'ui:SecondTests', 'gate', 'unit:OnePackage', 'unit:TwoPackage'})

    def test_failed_phase_is_retried_without_repeating_success_and_changed_inputs_invalidate(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'verification.json'
            identity = dict(build=dict(commit='abc', xcode='27', sdk='27', host='arm64'),
                            profile=dict(runtime='26.2'), root='checkout')
            calls = []
            def execute(command, check):
                calls.append(command)
                if command == ['fail']:
                    raise subprocess.CalledProcessError(1, command)
            def capture(*command):
                return 'abc' if command[:2] == ('git', 'rev-parse') else ''
            with patch.object(DEPLOY, 'capture', side_effect=capture):
                run = DEPLOY.Verification(path, identity, True, execute)
                run.phase('unit', ['pass'])
                with self.assertRaises(subprocess.CalledProcessError):
                    run.phase('ui', ['fail'])
                self.assertEqual(set(json.loads(path.read_text())['completed']), {'unit'})
                resumed = DEPLOY.Verification(path, identity, True, execute)
                resumed.phase('unit', ['pass'])
                resumed.phase('ui', ['fixed'])
                self.assertEqual(calls, [['pass'], ['fail'], ['fixed']])
                for changed in ('build', 'profile', 'root'):
                    altered = copy.deepcopy(identity)
                    altered[changed] = 'different'
                    self.assertFalse(DEPLOY.Verification(path, altered, True, execute).completed)
                self.assertFalse(DEPLOY.Verification(path, identity, False, execute).completed)
                with patch.object(DEPLOY, 'capture', return_value=' M source.swift'):
                    with self.assertRaisesRegex(ValueError, 'Source changed'):
                        resumed.phase('another', ['pass'])
                self.assertNotIn('another', json.loads(path.read_text())['completed'])

    def test_incomplete_profile_fails_before_querying_or_building(self):
        with patch.dict(DEPLOY.os.environ, {'TRINKET_SIM_OS_VERSION': '26.2'}, clear=True), \
                patch.object(DEPLOY.PROFILES, 'simctl') as simctl:
            with self.assertRaisesRegex(ValueError, 'requires TRINKET_SIM_DEVICE_TYPE'):
                DEPLOY.profile()
            simctl.assert_not_called()

    def test_default_profile_is_qualified_and_explicit_unavailable_profile_never_falls_back(self):
        runtimes = dict(runtimes=[dict(identifier='ios26', version='26.2', isAvailable=True, platform='iOS')])
        devices = dict(devicetypes=[dict(identifier='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro')])
        with patch.dict(DEPLOY.os.environ, {}, clear=True), \
                patch.object(DEPLOY.PROFILES, 'simctl', side_effect=[json.dumps(runtimes), json.dumps(devices)]):
            self.assertEqual(DEPLOY.profile()['version'], '26.2')
            self.assertEqual(DEPLOY.os.environ['TRINKET_SIM_OS_VERSION'], '26.2')
        with patch.dict(DEPLOY.os.environ, dict(TRINKET_SIM_DEVICE_TYPE=devices['devicetypes'][0]['identifier'],
                                             TRINKET_SIM_OS_VERSION='18.0'), clear=True), \
                patch.object(DEPLOY.PROFILES, 'simctl', side_effect=[json.dumps(runtimes), json.dumps(devices)]):
            with self.assertRaisesRegex(ValueError, 'unavailable iOS 18.0'):
                DEPLOY.profile()


if __name__ == '__main__':
    unittest.main()
