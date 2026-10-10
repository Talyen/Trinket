"""Protect exact-product diagnostics, native execution proof, and owned deadlines."""
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/ci-diagnostic-ui.py', 'Scripts/ci-run-budget.py', 'Scripts/native-test-results.py',
    'Scripts/test-ci-packages.sh', 'Scripts/test-package-host.sh', 'Scripts/ci-diagnostics.py', 'Scripts/test-timing.py',
    'Scripts/lib/xcode-watchdog.sh', '.github/actions/package-cache/action.yml',
    '.github/actions/build-cache-key/action.yml', '.github/workflows/gate.yml', '.github/workflows/diagnostic-ui.yml', '.github/workflows/tests.yml',
)

import json
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from script_test_support import ROOT, load_script

NATIVE = load_script('native_proof_test', 'native-test-results.py')
BUDGET = load_script('ci_budget_test', 'ci-run-budget.py')
DIAGNOSTIC = load_script('ui_diagnostic_test', 'ci-diagnostic-ui.py')
AGGREGATE = load_script('native_aggregate_test', 'ci-diagnostics.py')
TIMING = load_script('expanded_timing_test', 'test-timing.py')


class CIImprovementsTests(unittest.TestCase):
    def test_exact_diagnostic_products_accept_failed_smoke_but_reject_foreign_or_stale_builds(self):
        run = dict(id=10, run_attempt=2, head_sha='a' * 40, head_branch='main', status='completed',
                   conclusion='failure', path='.github/workflows/ci.yml', head_repository={'full_name': 'owner/repo'})
        jobs = [dict(name='tests / Build and smoke UI', conclusion='failure', head_sha='a' * 40, run_attempt=2,
                     steps=[dict(name='Restore warm cache and build', conclusion='success')])]
        artifacts = [dict(id=1, name='build-derived-data-10-2', expired=False)]
        self.assertEqual(DIAGNOSTIC.source_proof(run, jobs, artifacts, 'owner/repo', 'main')['sha'], 'a' * 40)
        self.assertEqual(run['conclusion'], 'failure')
        earlier = [{**jobs[0], 'run_attempt': 1}]
        self.assertEqual(DIAGNOSTIC.source_proof(run, earlier, [{**artifacts[0], 'name': 'build-derived-data-10-1'}],
                                              'owner/repo', 'main')['artifact'], 'build-derived-data-10-1')
        for changes in ({'status': 'in_progress'}, {'head_sha': 'wrong'}, {'head_branch': 'other'},
                        {'head_repository': {'full_name': 'fork/repo'}}, {'path': 'unrelated.yml'}):
            with self.assertRaises(ValueError):
                DIAGNOSTIC.source_proof({**run, **changes}, jobs, artifacts, 'owner/repo', 'main')
        for changed in ([], [{**artifacts[0], 'expired': True}], [{**artifacts[0], 'name': 'build-derived-data-10-1'}]):
            with self.assertRaises(ValueError):
                DIAGNOSTIC.source_proof(run, jobs, changed, 'owner/repo', 'main')
        with self.assertRaises(ValueError):
            DIAGNOSTIC.source_proof(run, [], artifacts, 'owner/repo', 'main')

    def test_diagnostic_selectors_are_existing_source_cases_not_shell_commands(self):
        previous = Path.cwd()
        os.chdir(ROOT)
        try:
            with patch.object(DIAGNOSTIC.subprocess, 'check_output', return_value='SmokeShopTests'):
                self.assertEqual(DIAGNOSTIC.selections('smoke', 'SmokeShopTests'),
                                 ['SmokeShopTests/testMerchantPurchasePaysAndReturnsToPlay'])
                for value in ('SmokeShopTests/testMissing', 'SmokeShopTests; echo unsafe', '',
                              'FullGamePurchaseSmokeTests'):
                    with self.assertRaises(ValueError):
                        DIAGNOSTIC.selections('smoke', value)
        finally:
            os.chdir(previous)

    def test_incompatible_diagnostic_products_never_execute_tests_or_build(self):
        failure = subprocess.CalledProcessError(2, ['restore-products'])
        with patch.object(sys, 'argv', ['diagnostic', 'run', 'smoke']), \
             patch.dict(os.environ, {'DIAGNOSTIC_TESTS': 'SmokeShopTests'}), \
             patch.object(DIAGNOSTIC, 'selections', return_value=['SmokeShopTests/testCase']), \
             patch.object(DIAGNOSTIC.subprocess, 'run', side_effect=failure) as restore, \
             patch.object(DIAGNOSTIC.subprocess, 'call') as tests:
            with self.assertRaises(subprocess.CalledProcessError):
                DIAGNOSTIC.main()
            self.assertEqual(restore.call_args.args[0][-1], 'false')
            tests.assert_not_called()

    def native_fixture(self, root):
        identifier = 'TrinketCoreTests.ValuesTests/`value survives`()/ValuesTests.swift:1:1'
        def event(kind):
            return {'version': 0, 'kind': 'event', 'payload': {'kind': kind, 'testID': identifier}}
        rows = [{'version': 0, 'kind': 'test', 'payload': {'kind': 'function', 'id': identifier, 'isParameterized': True}},
                event('runStarted'), event('testStarted'), event('testCaseStarted'),
                event('testCaseEnded'), event('testEnded'), event('runEnded')]
        events, catalog = root / 'events.jsonl', root / 'catalog'
        catalog.write_text('TrinketCoreTests.ValuesTests/`value survives`()\n')
        events.write_text('\n'.join(json.dumps(row) for row in rows))
        return events, catalog, rows

    def test_native_proof_rejects_skips_partial_parameters_missing_completion_and_discovery_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            events, catalog, rows = self.native_fixture(Path(directory))
            proof = NATIVE.execution('TrinketCore', events, catalog)
            self.assertTrue(NATIVE.valid(proof))
            events.write_text('')
            with self.assertRaises(ValueError):
                NATIVE.execution('TrinketCore', events, catalog)
            events.write_text('\n'.join(json.dumps(row) for row in rows))
            output = Path(directory) / 'native-TrinketCore-diagnostics.json'
            arguments = ['native', 'record', 'TrinketCore', str(events), str(catalog), str(events), str(output), '--exit-code', '1']
            with patch.object(sys, 'argv', arguments), patch.object(NATIVE.subprocess, 'check_output', return_value='a' * 40):
                with self.assertRaises(SystemExit):
                    NATIVE.main()
            self.assertEqual(json.loads(output.read_text())['status'], 'failed')
            for missing in ('runEnded', 'testEnded', 'testCaseEnded'):
                altered = [row for row in rows if row['payload']['kind'] != missing]
                events.write_text('\n'.join(json.dumps(row) for row in altered))
                with self.assertRaises(ValueError):
                    NATIVE.execution('TrinketCore', events, catalog)
            for kind in ('testSkipped', 'issueRecorded'):
                events.write_text('\n'.join(json.dumps(row) for row in rows + [
                    {'version': 0, 'kind': 'event', 'payload': {'kind': kind}}]))
                with self.assertRaises(ValueError):
                    NATIVE.execution('TrinketCore', events, catalog)
            events.write_text('\n'.join(json.dumps(row) for row in rows))
            catalog.write_text('TrinketCoreTests.ValuesTests/`a different value`()\n')
            with self.assertRaises(ValueError):
                NATIVE.execution('TrinketCore', events, catalog)
            self.assertFalse(NATIVE.valid({**proof, 'passed': True}))
            self.assertFalse(NATIVE.valid({**proof, 'executed_tests': []}))
            manifest = dict(action='native-test', status='passed', exit_code=0,
                            completion_source='process-exit', test_execution_proven=True, native_test=proof)
            self.assertFalse(AGGREGATE.normalise_report(None, None, manifest=manifest)['failed'])
            self.assertTrue(AGGREGATE.normalise_report(None, None, manifest={**manifest, 'native_test': {}})['failed'])

    def test_ios_duplicate_argument_names_count_each_execution_and_preserve_leaf_failures(self):
        node = {'children': [{'nodeType': 'Arguments', 'name': 'Ability(storage: AbilityStorage)',
                              'result': 'Passed', 'children': [
                                  {'nodeType': 'Repetition', 'result': 'Passed'},
                                  {'nodeType': 'Repetition', 'result': 'Failed'},
                              ]}, {'nodeType': 'Arguments', 'result': 'Passed'}]}
        self.assertEqual(TIMING.argument_results(node), ['Passed', 'Failed', 'Passed'])

    def test_native_ios_parity_requires_matching_ids_not_merely_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            events, catalog, _ = self.native_fixture(Path(directory))
            proof = NATIVE.execution('TrinketCore', events, catalog)
            native = dict(native_test=proof, commit='sha', status='passed', exit_code=0, issues=[])
            rows = [dict(mode='package:TrinketCore', commit='sha', summary=dict(result='Passed', passed=1, failed=0, skipped=0),
                         tests=[dict(id=proof['executed_tests'][0], result='Passed', arguments=['Passed'])])]
            self.assertEqual(NATIVE.compare(native, rows, 'sha')['matched_tests'], 1)
            for altered in ([{**rows[0], 'commit': 'older-sha'}],
                            [{**rows[0], 'tests': [dict(id='Other/test()', result='Passed', arguments=['Passed'])]}],
                            [{**rows[0], 'tests': [dict(id=proof['executed_tests'][0], result='Passed', arguments=[])]}],
                            [{**rows[0], 'summary': {**rows[0]['summary'], 'skipped': 1}}]):
                with self.assertRaises(ValueError):
                    NATIVE.compare(native, altered, 'sha')
            with self.assertRaises(ValueError):
                NATIVE.compare(native, rows, 'other-sha')

    def test_deadline_exhaustion_preserves_failure_and_never_starts_work(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'started'
            env = {**os.environ, 'RESULTS_DIR': directory, 'TRINKET_CI_DEADLINE_EPOCH': str(time.time() - 1)}
            self.assertEqual(BUDGET.run([sys.executable, '-c', f'open({str(marker)!r}, "w").close()'], env), 124)
            self.assertFalse(marker.exists())
            manifest = json.loads((Path(directory) / 'verification-budget-invocation.json').read_text())
            self.assertEqual(manifest['status'], 'failed')
            self.assertTrue(manifest['session_id'])

    def test_running_deadline_terminates_only_its_owned_group(self):
        with tempfile.TemporaryDirectory() as directory:
            foreign = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
            try:
                env = {**os.environ, 'RESULTS_DIR': directory, 'TRINKET_CI_DEADLINE_EPOCH': str(time.time() + 0.2)}
                self.assertEqual(BUDGET.run([sys.executable, '-c',
                                            'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)'], env), 124)
                self.assertIsNone(foreign.poll())
            finally:
                foreign.terminate()
                foreign.wait()

    def test_declared_job_timeouts_leave_a_diagnostic_reserve_before_checkout(self):
        for filename in ('tests.yml', 'diagnostic-ui.yml', 'gate.yml'):
            workflow = (ROOT / '.github/workflows' / filename).read_text()
            for block in re.split(r'^  [\w-]+:\n', workflow, flags=re.M):
                if 'TRINKET_CI_DEADLINE_EPOCH=' not in block:
                    continue
                minutes = int(re.search(r'timeout-minutes: (\d+)', block)[1])
                declared, reserve = map(int, re.search(r'\+ (\d+) \* 60 - (\d+)', block).groups())
                self.assertEqual(minutes, declared)
                self.assertGreaterEqual(reserve, 120)
                self.assertLess(block.index('TRINKET_CI_DEADLINE_EPOCH='), block.index('actions/checkout@'))

    def test_push_native_routing_keeps_manual_ios_comparators(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Scripts').mkdir()
            for name in ('test-ci-packages.sh', 'build-inputs.env'):
                shutil.copy(ROOT / 'Scripts' / name, root / 'Scripts' / name)
            for name, mode in (('test-package-host.sh', 'native'), ('test-package.sh', 'ios')):
                path = root / 'Scripts' / name
                path.write_text('#!/bin/bash\nprintf "' + mode + ':%s\\n" "$*"\n')
                path.chmod(0o755)
            packages = ['BattleEngine', 'TrinketCore', 'TrinketPersistence', 'TrinketAppState']
            for event, expected in [('push', ['native:BattleEngine TrinketCore', 'ios:TrinketPersistence TrinketAppState']),
                                    ('workflow_dispatch', ['ios:' + ' '.join(packages)])]:
                result = subprocess.run(['bash', 'Scripts/test-ci-packages.sh', *packages], cwd=root,
                                        env={**os.environ, 'GITHUB_EVENT_NAME': event}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), expected)

    def test_native_cache_omits_simulator_products_and_selected_identity_keeps_compatible_keys(self):
        action = (ROOT / '.github/actions/package-cache/action.yml').read_text()
        script = action.split('      run: |\n', 1)[1].split('    - uses:', 1)[0]
        script = '\n'.join(line[8:] for line in script.splitlines())
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            for native in ('true', 'false'):
                output.write_text('')
                subprocess.run(['bash', '-ec', script], check=True, capture_output=True,
                               env={**os.environ, 'NATIVE_ONLY': native, 'SHARD': 'Engine',
                                    'BUILD_KEY': 'key', 'BUILD_PREFIX': 'prefix', 'GITHUB_OUTPUT': str(output)})
                text = output.read_text()
                self.assertEqual('.DerivedData/packages' in text, native == 'false')
                self.assertIn('.DerivedData/host', text)
                self.assertEqual('package-native-v1' in text, native == 'true')
        key_action = (ROOT / '.github/actions/build-cache-key/action.yml').read_text()
        command = re.search(r'^        toolchain=.*$', key_action, re.M)[0].strip()
        result = subprocess.check_output(['bash', '-ec', command + '\nprintf "%s" "$toolchain"'], text=True,
                                         env={**os.environ, 'XCODE_VERSION': '27.1', 'XCODE_BUILD': '27A9269'})
        self.assertEqual(result, hashlib.sha256(b'Xcode 27.1\nBuild version 27A9269\n').hexdigest())


if __name__ == '__main__':
    unittest.main()
