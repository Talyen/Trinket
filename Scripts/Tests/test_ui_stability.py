"""Functional runtime, bounded diagnostics, and retained deep-journey protection."""
from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from script_test_support import ROOT, load_script, run_captured

PROFILE = load_script('stable_ui_profile', 'ci-ui-profile.py')
DIAGNOSTIC = load_script('stable_ui_diagnostic', 'ci-diagnostic-ui.py')
EXPORT = load_script('stable_ui_export', 'export-localization-screenshots.py')
FILTER = load_script('stable_ui_paths', 'ci-path-filter.py')
RETRY = load_script('stable_ui_cases', 'ci_ui_retry.py')


class UIStabilityTests(unittest.TestCase):
    def test_qualified_runtime_is_validated_before_exporting_environment(self):
        profile = PROFILE.QUALIFIED_PROFILE
        runtime = dict(identifier=profile['runtime'], buildversion=profile['build'])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'github-env'
            environment = dict(GITHUB_ACTIONS='true', GITHUB_ENV=str(path))
            with patch.object(PROFILE.PROFILES, 'prepare_runtime', return_value=runtime) as prepare:
                PROFILE.prepare(environment)
            prepare.assert_called_once_with(profile['device'], 26, '26.2', build='23C54', download_timeout=600)
            exported = dict(line.split('=', 1) for line in path.read_text().splitlines())
            PROFILE.require_environment(exported)
            self.assertEqual(exported['TEST_RUNNER_TRINKET_EXPECTED_OS_BUILD'], '23C54')
            for wrong in (dict(runtime, buildversion='23C52'), dict(runtime, identifier='different')):
                path.write_text('unchanged\n')
                with patch.object(PROFILE.PROFILES, 'prepare_runtime', return_value=wrong), self.assertRaises(ValueError):
                    PROFILE.prepare(environment)
                self.assertEqual(path.read_text(), 'unchanged\n')
            with patch.object(PROFILE.PROFILES, 'prepare_runtime') as prepare, self.assertRaises(ValueError):
                PROFILE.prepare(dict(GITHUB_ACTIONS='false', GITHUB_ENV=str(path)))
            prepare.assert_not_called()

    def test_functional_methods_are_bounded_without_truncating_profiles_or_soak(self):
        script = '''source "$1/Scripts/lib/test-helpers.sh"
MODE="$2"; ui_plan="$3"; GITHUB_ACTIONS="$4"; TRINKET_DEPLOY_EXPECTED_CASES="$5"
XCODEBUILD_ARGS=()
trinket_add_ui_method_timeouts
printf '%s\\n' "${XCODEBUILD_ARGS[@]}"
'''
        flags = ['-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '300',
                 '-maximum-test-execution-time-allowance', '300']
        for mode, plan, ci, release, expected in [('smoke', '', 'true', '', flags),
                ('ui', 'FullUI', 'true', '', flags), ('ui', 'Profiles', 'true', '', []),
                ('ui', 'Soak', 'true', '', []), ('ui', 'FullUI', 'false', '', []),
                ('performance', '', 'true', '', []), ('ui', 'Profiles', 'true', 'case', flags)]:
            with self.subTest(mode=mode, plan=plan, ci=ci):
                result = run_captured(['bash', '-c', script, '_', str(ROOT), mode, plan, ci, release], expected=0)
                self.assertEqual(result.stdout.split(), expected)

    def test_exact_diagnostics_cap_each_selected_case_and_keep_shorter_parent_deadlines(self):
        cases = ['Class/testOne', 'Class/testTwo']
        for mode, selected, inherited, expected in [('ui', cases[:1], '1800', '300'),
                ('smoke', cases, '1800', '600'), ('ui', cases, '120', '120'),
                ('soak', cases[:1], '2400', '2400')]:
            with self.subTest(mode=mode, selected=selected, inherited=inherited):
                environment = DIAGNOSTIC.execution_environment(mode, selected,
                    {'TRINKET_XCODE_WALL_TIMEOUT_SECONDS': inherited})
                self.assertEqual(environment['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'], expected)

    def test_unfinished_localization_bundle_is_skipped_and_complete_bundle_still_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / 'results'
            incomplete = results / 'interrupted.xcresult'
            complete = results / 'completed.xcresult'
            incomplete.mkdir(parents=True)
            complete.mkdir()
            (complete / 'Info.plist').write_text('complete')
            summary = json.dumps({'testNodes': [{'name': 'LocalizationUITests', 'nodeIdentifier': 'locale-suite'}]})
            with patch.object(sys, 'argv', ['export', str(results), str(root / 'screens')]), \
                    patch.object(EXPORT.subprocess, 'run', return_value=SimpleNamespace(stdout=summary)) as run, \
                    redirect_stdout(io.StringIO()):
                EXPORT.main()
            self.assertEqual(run.call_count, 2)
            self.assertIn(str(complete), run.call_args_list[0].args[0])
            self.assertIn('locale-suite', run.call_args_list[1].args[0])
            self.assertFalse(any(str(incomplete) in call.args[0] for call in run.call_args_list))

    def test_runtime_policy_changes_request_smoke_and_deep_purchase_journey_is_retained(self):
        for path in ('Scripts/ci-ui-profile.py', '.github/actions/setup-functional-ui/action.yml'):
            self.assertTrue(FILTER.needs_smoke([path]), path)
        self.assertEqual(RETRY.expected_cases(['FullGamePurchaseSmokeTests']),
                         ['FullGamePurchaseSmokeTests/testOptionsPurchaseUnlocksFullGame'])
        self.assertIn('FullGamePurchaseUITests/testCampaignAndOptionsPurchaseUnlockRecruitedWarlock',
                      RETRY.expected_cases(['FullGamePurchaseUITests']))
