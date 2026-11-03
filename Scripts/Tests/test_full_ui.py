"""FullUI runtime routing retains every class and fails on unqualified StoreKit execution."""
from __future__ import annotations

import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script

MODULE = load_script('test_full_ui_routing', 'ci-exhaustive-ui.py')


class FullUIRoutingTests(unittest.TestCase):
    def setUp(self):
        self.targets = ['BattleFlowUITests', MODULE.PURCHASE_CLASS, 'LocalizationUITests']
        self.environment = {'GITHUB_ACTIONS': 'true', 'DEVELOPER_DIR': '/verified-xcode', 'TRINKET_SIM_OS_MAJOR': '27'}
        qualified = MODULE.QUALIFIED_PROFILE
        self.runtime = dict(identifier=qualified['runtime'], version=qualified['version'], buildversion=qualified['build'])

    def test_every_requested_class_executes_once_on_its_runtime(self):
        with patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                patch.object(MODULE.PROFILES, 'prepare_runtime', return_value=self.runtime) as prepare, \
                patch.object(MODULE.subprocess, 'call', return_value=0) as execute:
            self.assertEqual(MODULE.run(self.targets, self.environment), 0)
        calls = execute.call_args_list
        self.assertEqual([target for call in calls for target in call.args[0][5:]],
                         ['BattleFlowUITests', 'LocalizationUITests', MODULE.PURCHASE_CLASS])
        self.assertEqual(calls[0].kwargs['env'], self.environment)
        self.assertEqual(calls[1].kwargs['env']['TRINKET_SIM_OS_VERSION'], '26.2')
        self.assertEqual(calls[1].kwargs['env']['TRINKET_SIM_OS_MAJOR'], '26')
        self.assertEqual(calls[1].kwargs['env']['TRINKET_SIM_DEVICE_TYPE'], MODULE.QUALIFIED_PROFILE['device'])
        self.assertEqual(calls[1].kwargs['env']['DEVELOPER_DIR'], '/verified-xcode')
        self.assertEqual(calls[1].kwargs['env']['TRINKET_ISOLATE'], '1')
        self.assertEqual(calls[1].kwargs['env']['DERIVED_DATA_PATH'], str((ROOT / '.DerivedData').resolve()))
        self.assertEqual(calls[1].kwargs['env']['RESULTS_DIR'], str((ROOT / '.DerivedData/TestResults').resolve()))
        prepare.assert_called_once_with(MODULE.QUALIFIED_PROFILE['device'], 26, '26.2')
        self.assertEqual(self.environment['TRINKET_SIM_OS_MAJOR'], '27')

    def test_independent_purchase_evidence_runs_after_other_ui_failure_and_either_failure_survives(self):
        for outcomes in ([65, 0], [0, 65], [65, 65]):
            with self.subTest(outcomes=outcomes), \
                    patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                    patch.object(MODULE.PROFILES, 'prepare_runtime', return_value=self.runtime), \
                    patch.object(MODULE.subprocess, 'call', side_effect=outcomes) as execute:
                self.assertEqual(MODULE.run(self.targets, self.environment), 65)
                self.assertEqual(execute.call_count, 2)

    def test_wrong_or_missing_runtime_fails_without_substituting_storekit_execution(self):
        for runtime in (dict(self.runtime, buildversion='different'), dict(self.runtime, identifier='different')):
            with self.subTest(runtime=runtime), \
                    patch.object(MODULE.subprocess, 'check_output', return_value=MODULE.PURCHASE_CLASS), \
                    patch.object(MODULE.PROFILES, 'prepare_runtime', return_value=runtime), \
                    patch.object(MODULE.subprocess, 'call') as execute:
                self.assertEqual(MODULE.run([MODULE.PURCHASE_CLASS], self.environment), 1)
                execute.assert_not_called()
        with patch.object(MODULE.subprocess, 'check_output', return_value=MODULE.PURCHASE_CLASS), \
                patch.object(MODULE.PROFILES, 'prepare_runtime', side_effect=ValueError('unavailable runtime')), \
                patch.object(MODULE.subprocess, 'call') as execute:
            self.assertEqual(MODULE.run([MODULE.PURCHASE_CLASS], self.environment), 1)
            execute.assert_not_called()

    def test_invalid_or_empty_selection_and_local_execution_fail_before_tests(self):
        with patch.object(MODULE.subprocess, 'check_output', return_value=' '.join(self.targets)), \
                patch.object(MODULE.subprocess, 'call') as execute:
            for targets in ([], ['UnknownUITests'], [MODULE.PURCHASE_CLASS, MODULE.PURCHASE_CLASS]):
                with self.subTest(targets=targets), self.assertRaises(ValueError):
                    MODULE.run(targets, self.environment)
            with self.assertRaises(ValueError):
                MODULE.run(self.targets, {'GITHUB_ACTIONS': 'false'})
            execute.assert_not_called()

    def test_non_purchase_selection_keeps_the_current_runtime(self):
        with patch.object(MODULE.subprocess, 'check_output', return_value='BattleFlowUITests'), \
                patch.object(MODULE.PROFILES, 'prepare_runtime') as prepare, \
                patch.object(MODULE.subprocess, 'call', return_value=0) as execute:
            self.assertEqual(MODULE.run(['BattleFlowUITests'], self.environment), 0)
            prepare.assert_not_called()
            execute.assert_called_once()

    def test_both_exhaustive_workflow_paths_use_the_router_with_the_complete_registry(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        for selection in ('steps.ui-matrices.outputs.full-targets', 'steps.ui-targets.outputs.targets'):
            self.assertIn('command: python3 Scripts/ci-exhaustive-ui.py ${{ ' + selection + ' }}', workflow)
