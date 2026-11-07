"""FullUI uses installed runtimes while retaining supported requested cases."""
from __future__ import annotations

import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script

MODULE = load_script('test_full_ui_routing', 'ci-exhaustive-ui.py')


class FullUIRoutingTests(unittest.TestCase):
    def setUp(self):
        self.targets = ['BattleFlowUITests', 'FullGamePurchaseUITests', 'LocalizationUITests']
        self.environment = {'GITHUB_ACTIONS': 'true', 'DEVELOPER_DIR': '/verified-xcode',
                            **MODULE.PROFILE.profile_environment()}

    def test_all_requested_classes_execute_once_together_and_preserve_failure(self):
        for status in (0, 65):
            with self.subTest(status=status), \
                    patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                    patch.object(MODULE.subprocess, 'call', return_value=status) as execute:
                self.assertEqual(MODULE.run(self.targets, self.environment), status)
                execute.assert_called_once()
                call = execute.call_args
                self.assertEqual(call.args[0][5:], self.targets)
                environment = call.kwargs['env']
                for key, value in MODULE.PROFILE.profile_environment().items():
                    self.assertEqual(environment[key], value)
                self.assertEqual(environment['TRINKET_ISOLATE'], '1')
                self.assertEqual(environment['DERIVED_DATA_PATH'], str((ROOT / '.DerivedData').resolve()))
                self.assertEqual(environment['RESULTS_DIR'], str((ROOT / '.DerivedData/TestResults').resolve()))

    def test_unprepared_runtime_and_invalid_selection_fail_before_execution(self):
        with patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                patch.object(MODULE.subprocess, 'call') as execute:
            for targets in ([], ['UnknownUITests'], ['FullGamePurchaseUITests'] * 2):
                with self.subTest(targets=targets), self.assertRaises(ValueError):
                    MODULE.run(targets, self.environment)
            for changes in ({'GITHUB_ACTIONS': 'false'}, {'TRINKET_SIM_DEVICE_TYPE': ''},
                            {'TRINKET_SIM_OS_VERSION': '25.4'}, {'TRINKET_SIM_OS_VERSION': ''},
                            {'TRINKET_SIM_OS_BUILD': ''}):
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    MODULE.run(self.targets, {**self.environment, **changes})
            execute.assert_not_called()

    def test_installed_alternative_routes_supported_cases_and_records_denial_gap(self):
        environment = {**self.environment, 'TRINKET_SIM_OS_MAJOR': '27',
                       'TRINKET_SIM_OS_VERSION': '27.1', 'TRINKET_SIM_OS_BUILD': '24A123',
                       'TEST_RUNNER_TRINKET_EXPECTED_OS_BUILD': '24A123'}
        supported = 'FullGamePurchaseUITests/testPurchase'
        deferred = 'FullGamePurchaseUITests/testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase'
        with patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                patch.object(MODULE.UI_RESULTS, 'expected_cases', return_value=[supported, deferred]), \
                patch.object(MODULE, 'record_coverage') as record, \
                patch.object(MODULE.subprocess, 'call', return_value=65) as execute:
            self.assertEqual(MODULE.run(self.targets, environment), 65)
        self.assertEqual(execute.call_args.args[0][5:],
                         ['BattleFlowUITests', supported, 'LocalizationUITests'])
        self.assertEqual(execute.call_args.kwargs['env']['TRINKET_SIM_OS_BUILD'], '24A123')
        self.assertEqual(record.call_args.args[:2], ('StoreKit denial simulation', 'unavailable'))
        self.assertEqual(record.call_args.kwargs['details']['deferred_selectors'], [deferred])

    def test_exhaustive_job_uses_complete_registry_and_can_rebuild_compatible_products(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        exhaustive = workflow.split('  exhaustive-ui:\n', 1)[1].split('  diff-review:\n', 1)[0]
        self.assertIn('Scripts/check-testplan-sync.py --classes FullUI', exhaustive)
        self.assertIn('command: python3 Scripts/ci-exhaustive-ui.py ${{ steps.ui-targets.outputs.targets }}', exhaustive)
        self.assertIn("rebuild-command: './Scripts/build-for-testing.sh --reuse --app-only'", exhaustive)
        self.assertIn('uses: ./.github/actions/setup-functional-ui', exhaustive)
