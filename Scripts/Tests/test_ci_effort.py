"""Prevent reuse or targeted retries from turning incomplete verification green."""
SCRIPT_INPUTS = (
    'Scripts/ci-reuse.py', 'Scripts/ci_ui_retry.py', 'Scripts/ci-diagnostics.py',
    'Scripts/test.sh', 'Scripts/diagnostic_maintenance.py',
    'Scripts/internal/cli.py',
)

import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from script_test_support import load_script

REUSE = load_script('ci_reuse_test', 'ci-reuse.py')
RETRY = load_script('ci_retry_test', 'ci_ui_retry.py')
AGGREGATE = load_script('ci_aggregate_test', 'ci-diagnostics.py')


class CIEffortTests(unittest.TestCase):
    def proof_fixture(self):
        run = dict(id=10, head_sha='abc', head_branch='main', event='push', status='completed', conclusion='success')
        names = ['tests / CI OK', 'tests / gate / Generate and style', 'tests / Build and smoke UI']
        names += [f'tests / Unit tests ({shard})' for shard in ('Engine', 'State', 'Content', 'Battle')]
        jobs = [dict(name=name, conclusion='success') for name in names]
        return run, jobs, [dict(name='build-derived-data-10-1', expired=False)]

    def test_reuse_requires_exact_commit_complete_checks_and_available_products(self):
        run, jobs, artifacts = self.proof_fixture()
        self.assertEqual(REUSE.proof(run, jobs, artifacts, 'abc', 'main')['standard'], 'true')
        for changes in ({'head_sha': 'old'}, {'head_branch': 'other'}, {'status': 'in_progress'}, {'conclusion': 'failure'}):
            self.assertIsNone(REUSE.proof({**run, **changes}, jobs, artifacts, 'abc', 'main'))
        for conclusion in ('skipped', 'failure', 'cancelled'):
            altered = copy.deepcopy(jobs)
            altered[-1]['conclusion'] = conclusion
            self.assertIsNone(REUSE.proof(run, altered, artifacts, 'abc', 'main'))
        self.assertIsNone(REUSE.proof(run, jobs, [{**artifacts[0], 'expired': True}], 'abc', 'main'))
        self.assertEqual(REUSE.proof(run, jobs, artifacts, 'abc', 'main')['assets'], 'false')

    def test_reuse_reads_successful_prior_attempts_but_latest_failure_wins(self):
        run, jobs, artifacts = self.proof_fixture()
        jobs = [{**job, 'id': index + 1} for index, job in enumerate(jobs)]
        responses = [[{'workflow_runs': [run]}], [{'jobs': jobs}], [{'artifacts': artifacts}]]
        with patch.object(REUSE, 'api', side_effect=responses):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['run-id'], '10')
        jobs += [{**jobs[-1], 'id': 100, 'conclusion': 'failure'}]
        with patch.object(REUSE, 'api', side_effect=[[{'workflow_runs': [run]}], [{'jobs': jobs}], [{'artifacts': artifacts}]]):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['standard'], 'false')

    def retry_fixture(self, root):
        bundle = root / 'original.xcresult'
        bundle.mkdir()
        (bundle / 'Info.plist').touch()
        original = dict(status='failed', exit_code=65, action='test-without-building',
                        session_id='session', result_bundle_complete=True, result_bundle=str(bundle))
        report = dict(classification='simulator-infrastructure', issues=[dict(kind='simulator-infrastructure', test='BattleTests/testLaunch()')])
        evidence = dict(expected_tests=['BattleTests/testLaunch', 'OtherTests/testInteraction'],
                        summary=dict(passed=1, failed=1, skipped=0), tests=[
            dict(id='BattleTests/testLaunch()', result='Failed'), dict(id='OtherTests/testInteraction()', result='Passed'),
        ])
        return original, report, evidence

    def test_targeted_retry_never_accepts_mixed_or_missing_execution_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            original, report, evidence = self.retry_fixture(Path(directory))
            self.assertEqual(RETRY.failed_cases(original, report, evidence, ['BattleTests', 'OtherTests']), ['BattleTests/testLaunch'])
            for kind in ('test-failure', 'unknown', 'build-failure'):
                mixed = copy.deepcopy(report)
                mixed['issues'].append(dict(kind=kind, test='OtherTests/testInteraction'))
                self.assertEqual(RETRY.failed_cases(original, mixed, evidence, ['BattleTests']), [])
            self.assertEqual(RETRY.failed_cases(original, report, evidence, ['AbsentTests']), [])
            self.assertEqual(RETRY.failed_cases({**original, 'result_bundle_complete': False}, report, evidence, ['BattleTests']), [])
            omitted = copy.deepcopy(evidence)
            omitted['expected_tests'].append('BattleTests/testNeverExecuted')
            self.assertEqual(RETRY.failed_cases(original, report, omitted, ['BattleTests']), [])
            incomplete = copy.deepcopy(evidence)
            incomplete['tests'][1]['result'] = 'Not Run'
            self.assertEqual(RETRY.failed_cases(original, report, incomplete, ['BattleTests']), [])

    def test_recovery_requires_matching_successful_retry_and_keeps_original_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original, report, evidence = self.retry_fixture(root)
            retry_bundle = root / 'retry.xcresult'
            retry_bundle.mkdir()
            (retry_bundle / 'Info.plist').touch()
            retry = dict(status='passed', exit_code=0, session_id='session', action='test-without-building',
                         result_bundle_complete=True, result_bundle=str(retry_bundle))
            retry_path = root / 'retry-invocation.json'
            retry_path.write_text(json.dumps(retry))
            original['infrastructure_recovery'] = dict(retry_manifest=str(retry_path), targets=['BattleTests', 'OtherTests'],
                original_evidence=evidence, retry_evidence=dict(summary=dict(passed=1, failed=0, skipped=0),
                    tests=[dict(id='BattleTests/testLaunch()', result='Passed')]))
            self.assertTrue(RETRY.recovery_valid(original, report))
            self.assertEqual(original['exit_code'], 65)
            retry_summary = original['infrastructure_recovery']['retry_evidence']['summary']
            retry_summary['skipped'] = 1
            self.assertFalse(RETRY.recovery_valid(original, report))
            retry_summary['skipped'] = 0
            normalized = AGGREGATE.normalise_report(None, report, manifest=original)
            self.assertFalse(normalized['failed'])
            self.assertTrue(normalized['infrastructure_recovered'])
            for changes in ({'session_id': 'unrelated'}, {'status': 'failed'}, {'exit_code': 1}):
                retry_path.write_text(json.dumps({**retry, **changes}))
                self.assertFalse(RETRY.recovery_valid(original, report))
            retry_path.write_text(json.dumps(retry))
            original['infrastructure_recovery']['retry_evidence']['tests'][0]['id'] = 'OtherTests/testInteraction()'
            self.assertFalse(RETRY.recovery_valid(original, report))

    def test_wrapper_retries_only_failed_case_and_aggregate_recognizes_coverage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / 'TestResults'
            results.mkdir()
            original, report, evidence = self.retry_fixture(results)
            calls = []
            def execute(command, env=None):
                calls.append(command)
                session = env['TRINKET_DIAGNOSTICS_SESSION_ID']
                if len(calls) == 1:
                    original.update(session_id=session, label='ui')
                    report_path = results / 'original-diagnostics.json'
                    report_path.write_text(json.dumps(report))
                    original['diagnostics_json'] = str(report_path)
                    (results / 'original-invocation.json').write_text(json.dumps(original))
                    return 65
                self.assertEqual(env['TRINKET_REPREP_UI_SIMULATOR'], '1')
                bundle = results / 'retry.xcresult'
                bundle.mkdir()
                (bundle / 'Info.plist').touch()
                retry = dict(status='passed', exit_code=0, session_id=session, label='ui',
                             action='test-without-building', result_bundle_complete=True, result_bundle=str(bundle))
                (results / 'retry-invocation.json').write_text(json.dumps(retry))
                return 0
            retried = dict(summary=dict(passed=1, failed=0, skipped=0), tests=[dict(id='BattleTests/testLaunch()', result='Passed')])
            with patch.dict(os.environ, RESULTS_DIR=str(results)), patch.object(RETRY.subprocess, 'call', side_effect=execute), \
                    patch.object(RETRY, 'parse_xcresult', side_effect=[evidence, retried]), \
                    patch.object(RETRY, 'expected_cases', return_value=evidence['expected_tests']):
                self.assertEqual(RETRY.run(['./Scripts/test.sh', 'ui', '--no-build', 'BattleTests', 'OtherTests']), 0)
            self.assertEqual(calls[1], ['./Scripts/test.sh', 'ui', '--no-build', 'BattleTests/testLaunch'])
            final = json.loads((results / 'original-invocation.json').read_text())
            self.assertEqual(final['status'], 'failed')
            self.assertTrue(RETRY.recovery_valid(final, report))
            maintenance = load_script('ci_recovery_cleanup_test', 'diagnostic_maintenance.py')
            maintenance.cleanup(results.resolve(), False)
            self.assertFalse(list(results.glob('*-invocation.json')))
            self.assertFalse(list(results.glob('*.xcresult')))



if __name__ == '__main__':
    unittest.main()
