"""Prevent reuse or targeted retries from turning incomplete verification green."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import sys

from script_test_support import load_script, write_json

REUSE = load_script('ci_reuse_test', 'ci-reuse.py')
RETRY = load_script('ci_retry_test', 'ci_ui_retry.py')
AGGREGATE = load_script('ci_aggregate_test', 'ci-diagnostics.py')
from internal import cli


class CIEffortTests(unittest.TestCase):
    def test_worktree_inventory_retries_only_timeout_and_never_caches_missing_ownership(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.git').mkdir()
            listing = b'worktree ' + os.fsencode(root) + b'\0\0'
            for recovers in (True, False):
                cli.worktree_roots.cache_clear()
                timeout = subprocess.TimeoutExpired(['git', 'worktree', 'list'], 10)
                with patch.object(cli.subprocess, 'check_output', side_effect=[timeout, listing if recovers else timeout]) as query:
                    if recovers:
                        self.assertEqual(cli.worktree_roots(root), (root.resolve(),))
                    else:
                        with self.assertRaises(subprocess.TimeoutExpired):
                            cli.worktree_roots(root)
                        self.assertEqual(cli.worktree_roots.cache_info().currsize, 0)
                    self.assertEqual([call.kwargs['timeout'] for call in query.call_args_list], [10, 30])
            cli.worktree_roots.cache_clear()

    def proof_fixture(self):
        run = dict(id=10, head_sha='abc', head_branch='main', event='push', status='completed', conclusion='success')
        names = ['tests / CI OK', 'tests / gate / Generate and style', 'tests / Build and smoke UI']
        jobs = [dict(name=name, conclusion='success') for name in names]
        jobs[-1].update(run_attempt=1, head_sha='abc', steps=[dict(name='Restore warm cache and build', conclusion='success')])
        jobs += [dict(name=f'tests / Unit tests ({shard})', conclusion='success',
                      steps=[dict(name=f'Test packages ({" ".join(packages)})', conclusion='success')])
                 for shard, packages in REUSE.SHARDS.items()]
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
        for steps in (None, [], [dict(name='Test packages (TrinketContent)', conclusion='success')],
                      [dict(name='Test packages (TrinketContent TrinketDesignSystem)', conclusion='skipped')]):
            altered = copy.deepcopy(jobs)
            next(job for job in altered if job['name'] == 'tests / Unit tests (Content)')['steps'] = steps
            self.assertIsNone(REUSE.proof(run, altered, artifacts, 'abc', 'main'))
        for expired in (True, 0, None):
            self.assertIsNone(REUSE.proof(run, jobs, [{**artifacts[0], 'expired': expired}], 'abc', 'main'))
        self.assertEqual(REUSE.proof(run, jobs, artifacts, 'abc', 'main')['assets'], 'false')
        jobs.append(dict(name='tests / Prepared asset integrity', conclusion='success'))
        self.assertEqual(REUSE.proof(run, jobs, artifacts, 'abc', 'main')['assets'], 'true')

    def test_reuse_reads_successful_prior_attempts_but_latest_failure_wins(self):
        run, jobs, artifacts = self.proof_fixture()
        jobs = [{**job, 'id': index + 1} for index, job in enumerate(jobs)]
        responses = [[{'workflow_runs': [{**run, 'id': 9, 'head_branch': 'other'}, run]}],
                     [{'jobs': jobs}], [{'artifacts': artifacts}]]
        with patch.object(REUSE, 'api', side_effect=responses):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['run-id'], '10')
        jobs += [{**jobs[-1], 'id': 100, 'conclusion': 'failure'}]
        with patch.object(REUSE, 'api', side_effect=[[{'workflow_runs': [run]}], [{'jobs': jobs}], [{'artifacts': artifacts}]]):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['standard'], 'false')

    def test_standard_reuse_binds_products_to_the_successful_producing_attempt(self):
        run, jobs, artifacts = self.proof_fixture()
        newer = dict(name='build-derived-data-10-2', expired=False)
        self.assertEqual(REUSE.proof(run, jobs, artifacts + [newer], 'abc', 'main')['build-artifact'], artifacts[0]['name'])
        self.assertIsNone(REUSE.proof(run, jobs, [newer], 'abc', 'main'))
        self.assertIsNone(REUSE.proof(run, jobs, artifacts * 2, 'abc', 'main'))
        build = next(job for job in jobs if job['name'] == 'tests / Build and smoke UI')
        for changes in ({'head_sha': 'wrong'}, {'head_sha': None}, {'run_attempt': 2},
                        {'steps': None}, {'steps': []},
                        {'steps': [dict(name='Restore warm cache and build', conclusion='skipped')]}):
            altered = [job if job is not build else {**build, **changes} for job in jobs]
            self.assertIsNone(REUSE.proof(run, altered, artifacts, 'abc', 'main'))

    def test_unreadable_run_does_not_hide_a_later_valid_proof(self):
        run, jobs, artifacts = self.proof_fixture()
        jobs = [{**job, 'id': index + 1} for index, job in enumerate(jobs)]
        broken = {**run, 'id': 11}
        responses = [[{'workflow_runs': [broken, run]}], [{'jobs': [None]}],
                     [{'jobs': jobs}], [{'artifacts': artifacts}]]
        with patch.object(REUSE, 'api', side_effect=responses):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['run-id'], '10')

    def test_partial_rerun_can_reuse_the_original_verified_producer(self):
        run, jobs, artifacts = self.proof_fixture()
        jobs = [{**job, 'id': index + 1} for index, job in enumerate(jobs)]
        original = next(job for job in jobs if job['name'] == 'tests / Build and smoke UI')
        cloned = {**original, 'id': 100, 'run_attempt': 2}
        history = [*jobs, cloned]
        responses = [[{'workflow_runs': [run]}], [{'jobs': history}], [{'artifacts': artifacts}]]
        for products_only in (False, True):
            with self.subTest(products_only=products_only), patch.object(REUSE, 'api', side_effect=responses):
                proof = REUSE.find_proof('owner/repo', 'abc', 'main', '20', products_only)
                self.assertEqual(proof['build-artifact'], 'build-derived-data-10-1')
        bad_history = [job if job is not original else {**job, 'head_sha': 'old'} for job in history]
        with patch.object(REUSE, 'api', side_effect=[[{'workflow_runs': [run]}], [{'jobs': bad_history}], [{'artifacts': artifacts}]]):
            self.assertEqual(REUSE.find_proof('owner/repo', 'abc', 'main', '20')['standard'], 'false')
        for changes in ({'head_sha': 'old'}, {'steps': []}):
            latest = [job if job['name'] != original['name'] else {**cloned, **changes} for job in jobs]
            self.assertIsNone(REUSE.proof(run, latest, artifacts, 'abc', 'main', history=history))
        latest = [job if job['name'] != original['name'] else {**cloned, 'head_sha': 'old'} for job in jobs]
        self.assertIsNone(REUSE.product_proof(run, latest, artifacts, 'abc', 'main', history=history))

    def test_product_transfer_does_not_require_or_certify_unrelated_checks(self):
        run, jobs, artifacts = self.proof_fixture()
        build = dict(name='tests / Build and smoke UI', conclusion='success', run_attempt=1, head_sha='abc',
                     steps=[dict(name='Restore warm cache and build', conclusion='success')])
        running = {**run, 'status': 'in_progress', 'conclusion': None}
        proof = REUSE.product_proof(running, [build], artifacts, 'abc', 'main')
        self.assertEqual(proof['products'], 'true')
        self.assertEqual(proof['standard'], 'false')
        self.assertIsNotNone(REUSE.product_proof(running, [{**build, 'conclusion': 'failure'}], artifacts, 'abc', 'main'))
        self.assertIsNone(REUSE.proof(run, [build], artifacts, 'abc', 'main'))
        manual = {**running, 'event': 'workflow_dispatch', 'display_title': 'Trinket CI (verified)'}
        self.assertIsNotNone(REUSE.product_proof(manual, [build], artifacts, 'abc', 'main'))
        for changed in ({'head_sha': 'old'}, {'head_branch': 'other'}, {'event': 'schedule'},
                        {'event': 'workflow_dispatch', 'display_title': 'Trinket CI (latest)'}):
            self.assertIsNone(REUSE.product_proof({**running, **changed}, [build], artifacts, 'abc', 'main'))
        for changed in ({'steps': []}, {'steps': None}, {'steps': [dict(name='Restore warm cache and build', conclusion='failure')]},
                        {'run_attempt': 2}, {'run_attempt': None}, {'head_sha': 'other'}):
            self.assertIsNone(REUSE.product_proof(running, [{**build, **changed}], artifacts, 'abc', 'main'))
        self.assertIsNone(REUSE.product_proof(running, [build], [{**artifacts[0], 'expired': True}], 'abc', 'main'))
        self.assertIsNone(REUSE.product_proof(running, [build], artifacts * 2, 'abc', 'main'))

    def test_explicit_checkout_uses_source_revision_instead_of_workflow_revision(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, GITHUB_REPOSITORY='owner/repo', GITHUB_SHA='workflow-sha',
                            GITHUB_REF_NAME='main', GITHUB_RUN_ID='20', GITHUB_OUTPUT=str(Path(directory) / 'output')), \
                    patch.object(sys, 'argv', ['ci-reuse.py', '--products-only']), \
                    patch.object(REUSE.subprocess, 'check_output', return_value='source-sha\n'), \
                    patch.object(REUSE, 'find_proof', return_value=dict(standard='false', products='false')) as find:
                REUSE.main()
            find.assert_called_once_with('owner/repo', 'source-sha', 'main', '20', True)

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
            for malformed in ({**evidence, 'tests': [None]}, {**evidence, 'summary': []},
                              {**evidence, 'expected_tests': [None]}):
                self.assertEqual(RETRY.failed_cases(original, report, malformed, ['BattleTests']), [])
            self.assertEqual(RETRY.failed_cases(original, report, evidence, []), [])
            self.assertEqual(RETRY.failed_cases(original, report, evidence, ['BattleTests']), [])

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
            write_json(retry_path, retry)
            original['infrastructure_recovery'] = dict(retry_manifest=str(retry_path), targets=['BattleTests', 'OtherTests'],
                original_evidence=evidence, retry_evidence=dict(summary=dict(passed=1, failed=0, skipped=0),
                    tests=[dict(id='BattleTests/testLaunch()', result='Passed')]))
            self.assertTrue(RETRY.recovery_valid(original, report))
            write_json(retry_path, {**retry, 'result_bundle': original['result_bundle']})
            self.assertFalse(RETRY.recovery_valid(original, report))
            write_json(retry_path, retry)
            self.assertEqual(original['exit_code'], 65)
            retry_summary = original['infrastructure_recovery']['retry_evidence']['summary']
            retry_summary['skipped'] = 1
            self.assertFalse(RETRY.recovery_valid(original, report))
            retry_summary['skipped'] = 0
            normalized = AGGREGATE.normalise_report(None, report, manifest=original)
            self.assertFalse(normalized['failed'])
            self.assertTrue(normalized['infrastructure_recovered'])
            for changes in ({'session_id': 'unrelated'}, {'status': 'failed'}, {'exit_code': 1},
                            {'exit_code': False}, {'exit_code': 0.0}):
                write_json(retry_path, {**retry, **changes})
                self.assertFalse(RETRY.recovery_valid(original, report))
            write_json(retry_path, retry)
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
                    write_json(report_path, report)
                    original['diagnostics_json'] = str(report_path)
                    write_json(results / 'original-invocation.json', original)
                    (results / 'unrelated-invocation.json').write_text('broken')
                    return 65
                self.assertEqual(env['TRINKET_REPREP_UI_SIMULATOR'], '1')
                bundle = results / 'retry.xcresult'
                bundle.mkdir()
                (bundle / 'Info.plist').touch()
                retry = dict(status='passed', exit_code=0, session_id=session, label='ui',
                             action='test-without-building', result_bundle_complete=True, result_bundle=str(bundle))
                write_json(results / 'retry-invocation.json', retry)
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
            (results / 'unrelated-invocation.json').unlink()
            maintenance = load_script('ci_recovery_cleanup_test', 'diagnostic_maintenance.py')
            write_json(results / 'ci-diagnostics.json', dict(category='passed', invocations=[
                dict(infrastructure_recovered=True)]))
            (results / 'raw').mkdir()
            (results / 'raw' / 'original.log').write_text('Original launch failure')
            (results / 'raw' / 'retry.log').write_text('Targeted retry passed')
            staged = root / 'artifact'
            output = root / 'github-output'
            with patch.dict(os.environ, GITHUB_OUTPUT=str(output)):
                maintenance.stage(results, staged)
            self.assertTrue((staged / 'original.xcresult' / 'Info.plist').is_file())
            self.assertTrue((staged / 'retry.xcresult' / 'Info.plist').is_file())
            self.assertEqual(len(list((staged / 'raw').glob('*.log'))), 2)
            self.assertIn('retain-forensics=true', output.read_text())
            maintenance.cleanup(results.resolve(), False)
            self.assertFalse(list(results.glob('*-invocation.json')))
            self.assertFalse(list(results.glob('*.xcresult')))



if __name__ == '__main__':
    unittest.main()
