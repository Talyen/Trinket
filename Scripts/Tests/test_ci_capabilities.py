"""Available environments may reduce coverage; product failures may not disappear."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script
from internal.ci_capabilities import available_profiles, available_ui_selectors, unavailable_failure

RUNNER = load_script('capability_test_runner', 'ci-test-capability.py')
PROFILE = load_script('available_ui_profile_test', 'ci-ui-profile.py')


class CICapabilityTests(unittest.TestCase):
    def test_xcode_linked_diagnostics_distinguish_runtime_loss_from_a_real_crash(self):
        missing = dict(kind='simulator-infrastructure',
                       message='Unable to boot device because we cannot determine the runtime bundle.')
        for message, runtime_missing, unavailable in [('Test crashed with signal term.', True, True),
                                                       ('Test crashed with signal term.', False, False),
                                                       ('Test crashed with signal abrt.', True, False),
                                                       ('XCTAssertTrue failed - reward lost', True, False)]:
            with self.subTest(message=message, missing=runtime_missing), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                log = root / 'raw.log'
                log.write_text(message)
                report = root / 'diagnostics.json'
                report.write_text(json.dumps(dict(exit_code=65, classification='test-failure', log=str(log),
                    issues=[dict(kind='test-failure', message=message), *([missing] if runtime_missing else [])])))
                (root / 'smoke-invocation.json').write_text(json.dumps(dict(status='failed', exit_code=65,
                                                                           diagnostics_json=str(report))))
                self.assertEqual(unavailable_failure(root, {}) is not None, unavailable)

    def test_preparation_exports_an_installed_alternative_without_provisioning(self):
        runtime = dict(identifier='ios-27', version='27.0', buildversion='24A123', platform='iOS', isAvailable=True,
                       supportedDeviceTypes=[dict(identifier='phone')])
        inventory = [json.dumps(dict(runtimes=[runtime])),
                     json.dumps(dict(devicetypes=[dict(identifier='phone', name='iPhone 18 Pro')])),
                     json.dumps(dict(devices={}))]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            environment = dict(GITHUB_ACTIONS='true', GITHUB_ENV=str(root / 'environment'),
                               DERIVED_DATA_PATH=str(root), XCODE_VERSION='27.1')
            with patch.object(PROFILE, 'prepare_components'), \
                    patch.object(PROFILE.PROFILES, 'simctl', side_effect=inventory), \
                    patch.object(PROFILE.PROFILES, 'warm_runtime_cache') as warm, \
                    patch.object(PROFILE.PROFILES, 'prepare_runtime', side_effect=AssertionError('runtime download attempted')):
                self.assertEqual(PROFILE.prepare(environment), runtime)
                warm.assert_called_once_with(runtime)
            exported = (root / 'environment').read_text()
            self.assertIn('TRINKET_SIM_DEVICE_TYPE=phone\n', exported)
            self.assertIn('TRINKET_SIM_OS_BUILD=24A123\n', exported)
            self.assertIn('TRINKET_CI_SIMULATOR_AVAILABLE=true\n', exported)
            self.assertNotIn('23C54', exported)

    def test_nested_product_failure_vetoes_a_later_infrastructure_gap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            nested = root / 'scenario/TestResults'
            nested.mkdir(parents=True)
            for destination, classification, session in [(root, 'simulator-infrastructure', 'outer'),
                                                          (nested, 'test-failure', 'nested')]:
                (destination / 'failure-invocation.json').write_text(json.dumps(dict(
                    status='failed', classification=classification, session_id=session)))
            self.assertIsNone(unavailable_failure(root, {}))

    def test_capability_filter_keeps_purchases_and_defers_only_unqualified_denial(self):
        denial = 'FullGamePurchaseUITests/testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase'
        purchase = 'FullGamePurchaseUITests/testCampaignAndOptionsPurchaseUnlockRecruitedWarlock'
        selectors = ['SmokeBattleTests', 'FullGamePurchaseUITests', 'FullGamePurchaseSmokeTests']
        available, gaps = available_ui_selectors(selectors, {'build': '24B8117'}, lambda _: [denial, purchase])
        self.assertEqual(available, ['SmokeBattleTests', purchase, 'FullGamePurchaseSmokeTests'])
        self.assertEqual(gaps, [denial])
        self.assertEqual(available_ui_selectors(selectors, {'build': '23C54'}, lambda _: []), (selectors, []))

    def test_selection_uses_compatible_installed_devices_and_retains_the_coverage_floor(self):
        types = [dict(identifier=name, name=name) for name in ('iPhone 17 Pro', 'iPhone 18 Pro', 'iPhone Duo', 'iPad A16')]
        runtimes = [dict(identifier=str(value), platform='iOS', version=str(value), isAvailable=True,
                         buildversion='build', supportedDeviceTypes=[dict(identifier=name) for name in supported])
                    for value, supported in [(18, ['iPhone 17 Pro']), (26, ['iPhone 17 Pro', 'iPad A16']),
                                             (27, ['iPhone 18 Pro', 'iPhone Duo', 'iPad A16'])]]
        devices = {'26': [dict(udid='healthy', deviceTypeIdentifier='iPhone 17 Pro', state='Booted')]}
        choices = available_profiles(runtimes, types, devices, sdk_version='27.1')
        self.assertEqual(choices[0]['udid'], 'healthy')
        self.assertEqual({item['version'] for item in choices}, {'26', '27'})
        self.assertNotIn('iPhone Duo', {item['device'] for item in choices})
        self.assertEqual(available_profiles(runtimes, types, {}, family='iPad', major=26)[0]['version'], '26')
        self.assertEqual(available_profiles(runtimes, types, {}, family='Duo')[0]['device'], 'iPhone Duo')
        self.assertEqual(available_profiles(runtimes, types, {}, excluded=('26', '27')), [])

    def test_only_proven_runner_failure_becomes_an_explicit_gap(self):
        cases = [('print("completed")', 0, 'passed'),
                 ('print("Error: Simulator boot timed out after 240s"); raise SystemExit(7)', 0, 'unavailable'),
                 ('print("Error: Simulator boot timed out after 240s\\nAssertionError: wrong save"); raise SystemExit(7)', 7, 'failed'),
                 ('print("Flow.swift:10: error: XCTAssertTrue failed - reward missing"); raise SystemExit(7)', 7, 'failed'),
                 ('print("unknown failure"); raise SystemExit(7)', 7, 'failed')]
        for source, expected, outcome in cases:
            with self.subTest(source=source), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                environment = {key: value for key, value in os.environ.items()
                               if key not in ('TRINKET_CI_DEADLINE_EPOCH', 'TRINKET_DIAGNOSTICS_SESSION_ID')}
                environment.update(DERIVED_DATA_PATH=str(root), RESULTS_DIR=str(root / 'results'),
                                   GITHUB_OUTPUT=str(root / 'outputs'), GITHUB_STEP_SUMMARY=str(root / 'summary'))
                self.assertEqual(RUNNER.run([sys.executable, '-c', source], 'fixture', environment), expected)
                receipts = [json.loads(path.read_text()) for path in (root / 'CICoverage').glob('*.json')]
                self.assertEqual([item['status'] for item in receipts], [outcome])
                self.assertIn(f'executed={str(outcome == "passed").lower()}', (root / 'outputs').read_text())


if __name__ == '__main__':
    unittest.main()
