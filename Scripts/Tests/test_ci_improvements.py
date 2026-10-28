"""Protect exact-product diagnostics, native execution proof, and owned deadlines."""
from __future__ import annotations

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

from script_test_support import ROOT, load_script, run_captured, write_executable

NATIVE = load_script('native_proof_test', 'native-test-results.py')
BUDGET = load_script('ci_budget_test', 'ci-run-budget.py')
DIAGNOSTIC = load_script('ui_diagnostic_test', 'ci-diagnostic-ui.py')
AGGREGATE = load_script('native_aggregate_test', 'ci-diagnostics.py')
TIMING = load_script('expanded_timing_test', 'test-timing.py')


class CIImprovementsTests(unittest.TestCase):
    def test_retained_diagnostic_driver_runs_without_the_source_checkout_dependencies(self):
        workflow = (ROOT / '.github/workflows/diagnostic-ui.yml').read_text()
        retained = workflow.split('name: Retain diagnostic driver independently of the source revision\n', 1)[1]
        commands = retained.split('run: |\n', 1)[1].split('\n      - uses:', 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, 'RUNNER_TEMP': str(root), 'RESULTS_DIR': str(root / 'results')}
            env.pop('TRINKET_CI_DEADLINE_EPOCH', None)
            env.pop('PYTHONPATH', None)
            run_captured(['bash', '-eu', '-c', commands], cwd=ROOT, env=env, expected=0)
            driver = root / 'ui-diagnostic-driver' / 'ci-run-budget.py'
            command = [sys.executable, '-c', "import sys; print('Simulator boot timed out after 240s'); sys.exit(7)"]
            run_captured([sys.executable, str(driver), '--', *command], cwd=root, env=env, expected=7)
            receipt = json.loads(next((root / 'results').glob('*-invocation.json')).read_text())
            self.assertEqual(receipt['classification'], 'simulator-infrastructure')
            self.assertEqual(receipt['command'], command)

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
        original_products = [{**artifacts[0], 'name': 'build-derived-data-10-1'}]
        history = [*jobs, *earlier]
        self.assertEqual(DIAGNOSTIC.source_proof(run, history, original_products,
                                              'owner/repo', 'main')['artifact'], 'build-derived-data-10-1')
        self.assertEqual(DIAGNOSTIC.source_proof(run, history, [*original_products, *artifacts],
                                              'owner/repo', 'main')['artifact'], 'build-derived-data-10-2')
        for invalid in ([*jobs, {**earlier[0], 'head_sha': 'b' * 40}],
                        [*jobs, {**earlier[0], 'steps': []}], [*history, *earlier]):
            with self.assertRaises(ValueError):
                DIAGNOSTIC.source_proof(run, invalid, original_products, 'owner/repo', 'main')
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
            with patch.object(DIAGNOSTIC.subprocess, 'check_output', return_value='RepeatedPlayUITests') as registry:
                target = 'RepeatedPlayUITests/testTwentyAudioEnabledContractsKeepOneUsableCareer'
                self.assertEqual(DIAGNOSTIC.selections('soak', target), [target])
                self.assertEqual(registry.call_args.args[0][-1], 'Soak')
            with patch.object(sys, 'argv', ['diagnostic', 'run', 'soak']), \
                 patch.dict(os.environ, {'DIAGNOSTIC_TESTS': target}), \
                 patch.object(DIAGNOSTIC, 'selections', return_value=[target]), \
                 patch.object(DIAGNOSTIC.subprocess, 'run'), \
                 patch.object(DIAGNOSTIC.subprocess, 'call', return_value=65) as execute:
                with self.assertRaises(SystemExit) as status:
                    DIAGNOSTIC.main()
                self.assertEqual(status.exception.code, 65)
                self.assertEqual(execute.call_args.args[0], ['./Scripts/test.sh', 'ui', '--no-build', target])
                self.assertEqual(execute.call_args.kwargs['env']['TRINKET_UI_PLAN'], 'Soak')
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
            report = AGGREGATE.normalise_report(None, None, manifest=manifest)
            self.assertFalse(report['failed'])
            aggregate_path = Path(directory) / 'aggregate.json'
            with patch.object(AGGREGATE, 'load_reports', return_value=([report], [], True, 0, '', 1)):
                AGGREGATE.main([directory, str(aggregate_path)], environ={})
            aggregate = json.loads(aggregate_path.read_text())
            self.assertEqual(aggregate['category'], 'passed')
            self.assertEqual(aggregate['missing_result_invocations'], 0)
            self.assertEqual(aggregate['incomplete_result_invocations'], 0)
            self.assertNotIn('watchdog log proof', aggregate['detail'])
            self.assertTrue(AGGREGATE.normalise_report(None, None, manifest={**manifest, 'native_test': {}})['failed'])

    def test_native_proof_requires_completed_cases_and_rejects_cancellation(self):
        with tempfile.TemporaryDirectory() as directory:
            events, catalog, rows = self.native_fixture(Path(directory))
            def write(records):
                events.write_text('\n'.join(json.dumps(record) for record in records))

            for kind in ('testCancelled', 'testCaseCancelled'):
                with self.subTest(kind=kind):
                    write(rows + [{'version': 0, 'kind': 'event', 'payload': {'kind': kind}}])
                    with self.assertRaisesRegex(ValueError, kind):
                        NATIVE.execution('TrinketCore', events, catalog)

            nonparameterized = [{**row, 'payload': {**row['payload'], 'isParameterized': False}}
                                if row['kind'] == 'test' else row for row in rows]
            write(nonparameterized)
            self.assertTrue(NATIVE.valid(NATIVE.execution('TrinketCore', events, catalog)))
            missing = [row for row in nonparameterized
                       if row['payload']['kind'] not in ('testCaseStarted', 'testCaseEnded')]
            started = next(row for row in nonparameterized if row['payload']['kind'] == 'testCaseStarted')
            ended = next(row for row in nonparameterized if row['payload']['kind'] == 'testCaseEnded')
            for altered in (missing, nonparameterized + [started, ended]):
                with self.subTest(records=len(altered)):
                    write(altered)
                    with self.assertRaises(ValueError):
                        NATIVE.execution('TrinketCore', events, catalog)

            unknown = [{**row, 'payload': {**row['payload'], 'testID': 'OtherTests.Hidden/test()/File.swift:1:1'}}
                       for row in (started, ended)]
            write(rows + unknown)
            with self.assertRaises(ValueError):
                NATIVE.execution('TrinketCore', events, catalog)

    def test_ios_duplicate_argument_names_count_each_execution_and_preserve_leaf_failures(self):
        node = {'children': [{'nodeType': 'Arguments', 'name': 'Ability(storage: AbilityStorage)',
                              'result': 'Passed', 'children': [
                                  {'nodeType': 'Repetition', 'result': 'Passed'},
                                  {'nodeType': 'Repetition', 'result': 'Failed'},
                              ]}, {'nodeType': 'Arguments', 'result': 'Passed'}]}
        self.assertEqual(TIMING.argument_results(node), ['Passed', 'Failed', 'Passed'])

    def test_native_failure_reports_keep_assertions_and_compiler_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            events, log = root / 'events.jsonl', root / 'native.log'
            identifier = 'BattleEngineTests.Rewards/`reward survives`()/Rewards.swift:8:1'
            failure = {'version': 0, 'kind': 'event', 'payload': {
                'kind': 'issueRecorded', 'testID': identifier,
                'issue': {'isKnown': False, 'sourceLocation': {'fileID': 'Tests/Rewards.swift', 'line': 10}},
                'messages': [{'text': 'Expectation failed: reward == 10'}, {'text': 'reward → 0'}]}}
            events.write_text(json.dumps(failure) + '\n' + '{interrupted')
            log.write_text('Error: Simulator boot timed out after 240s\n')
            issues = NATIVE.failure_issues(events, log, 1)
            assertion = next(item for item in issues if item['kind'] == 'test-failure')
            self.assertEqual(assertion['test'], identifier.rsplit('/', 1)[0])
            self.assertEqual(assertion['line'], 10)
            self.assertIn('reward → 0', assertion['details'])
            output = root / 'native-BattleEngine-diagnostics.json'
            NATIVE.write_receipt(output, dict(label='native-BattleEngine', action='native-test',
                status='failed', exit_code=1, classification='test-failure', issues=issues))
            summary = root / 'summary.md'
            AGGREGATE.main([directory, str(root / 'ci-diagnostics.json')], {'GITHUB_STEP_SUMMARY': str(summary)})
            self.assertIn('Rewards/', summary.read_text())
            self.assertIn('Tests/Rewards.swift:10', summary.read_text())
            events.write_text('')
            log.write_text("Sources/Defense.swift:132:40: \x1b[1;31merror: \x1b[1;39mvalue has no member 'kind'\x1b[0m\n")
            compiler = NATIVE.failure_issues(events, log, 1)[0]
            self.assertEqual(compiler['kind'], 'build-failure')
            self.assertEqual(compiler['line'], 132)
            self.assertIn("no member 'kind'", compiler['message'])

    def test_preparation_failures_record_phase_command_and_environment_without_fake_test_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory)
            env = {**os.environ, 'RESULTS_DIR': directory, 'TRINKET_DIAGNOSTICS_SESSION_ID': 'preflight',
                   'XCODE_BUILD': '27A9275'}
            env.pop('TRINKET_CI_DEADLINE_EPOCH', None)
            command = [sys.executable, '-c', "import sys; print('Error: Simulator boot timed out after 240s'); sys.exit(1)"]
            self.assertEqual(BUDGET.run(command, env), 1)
            report = json.loads(next(results.glob('*-diagnostics.json')).read_text())
            self.assertEqual(report['classification'], 'simulator-infrastructure')
            self.assertEqual(report['phase'], 'command-preparation')
            self.assertEqual(report['command'], command)
            self.assertEqual(report['environment']['XCODE_BUILD'], '27A9275')
            self.assertGreater(report['duration_seconds'], 0)
            self.assertNotIn('test_execution_proven', report)
            AGGREGATE.main([directory, str(results / 'ci-diagnostics.json')], env)
            aggregate = json.loads((results / 'ci-diagnostics.json').read_text())
            self.assertEqual(aggregate['category'], 'simulator-infrastructure')
            self.assertEqual(aggregate['missing_result_invocations'], 0)
            BUDGET.preparation_report(command, results, env, 1, 2,
                                      "Sources/State.swift:4:2: error: failed to launch macro plugin\n"
                                      "Error: Simulator boot timed out after 240s\n", 'command-preparation')
            AGGREGATE.main([directory, str(results / 'ci-diagnostics.json')], env)
            self.assertEqual(json.loads((results / 'ci-diagnostics.json').read_text())['category'], 'build-failure')
            BUDGET.preparation_report(command, results, env, 1, 120,
                                      "xcrun --sdk iphonesimulator --show-sdk-version timed out after 120 seconds", 'command-preparation')
            self.assertTrue(any(json.loads(path.read_text())['classification'] == 'tooling'
                                for path in results.glob('preparation-*-diagnostics.json')))
            BUDGET.preparation_report(command, results, env, 1, 120,
                                      "Expectation failed: committedReward == 10\n"
                                      "xcrun --show-sdk-version timed out after 120 seconds", 'command-preparation')
            AGGREGATE.main([directory, str(results / 'ci-diagnostics.json')], env)
            self.assertEqual(json.loads((results / 'ci-diagnostics.json').read_text())['category'], 'test-failure')

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

    def test_transferred_parity_rejects_foreign_attempt_toolchain_and_incomplete_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            events, catalog, _ = self.native_fixture(Path(directory))
            proof = NATIVE.execution('TrinketCore', events, catalog)
            identity = dict(commit='a' * 40, GITHUB_REPOSITORY='owner/repo', GITHUB_RUN_ID='10',
                            GITHUB_RUN_ATTEMPT='2', XCODE_VERSION='27.1', XCODE_BUILD='27A9275')
            native = dict(native_test=proof, commit=identity['commit'], execution_identity=identity,
                          status='passed', exit_code=0, issues=[])
            row = dict(mode='package:TrinketCore', commit=identity['commit'], execution_identity=identity,
                       summary=dict(result='Passed', passed=1, failed=0, skipped=0),
                       tests=[dict(id=proof['executed_tests'][0], result='Passed', arguments=['Passed'])])
            transfer = NATIVE.ios_transfer('TrinketCore', [row], identity)
            self.assertEqual(NATIVE.compare_transfer(native, transfer, identity)['matched_tests'], 1)
            for key, value in [('commit', 'b' * 40), ('GITHUB_REPOSITORY', 'fork/repo'), ('GITHUB_RUN_ID', '11'),
                               ('GITHUB_RUN_ATTEMPT', '1'), ('XCODE_VERSION', '27.2'), ('XCODE_BUILD', '27B5028f')]:
                with self.subTest(key=key):
                    wrong = {**identity, key: value}
                    with self.assertRaises(ValueError):
                        NATIVE.compare_transfer(native, {**transfer, 'execution_identity': wrong}, identity)
                    with self.assertRaises(ValueError):
                        NATIVE.compare_transfer({**native, 'execution_identity': wrong}, transfer, identity)
                    with self.assertRaises(ValueError):
                        NATIVE.ios_transfer('TrinketCore', [{**row, 'execution_identity': wrong}], identity)
            for altered in ([], [row, row], [{**row, 'tests': []}],
                            [{**row, 'summary': {**row['summary'], 'skipped': 1}}],
                            [{**row, 'tests': [{**row['tests'][0], 'arguments': ['Not Run']}]}]):
                with self.assertRaises(ValueError):
                    NATIVE.ios_transfer('TrinketCore', altered, identity)
            with self.assertRaises(ValueError):
                NATIVE.compare_transfer(native, {**transfer, 'package': 'BattleEngine'}, identity)
            with self.assertRaises(ValueError):
                NATIVE.ios_transfer('TrinketCore', [row], {})

    def test_inventory_preparation_is_tooling_and_preserves_mixed_assertions(self):
        with tempfile.TemporaryDirectory() as directory:
            results = Path(directory)
            environment = {'TRINKET_DIAGNOSTICS_SESSION_ID': 'unit-State-10-2'}
            messages = [
                ('Simulator guest inventory attempt 1/2 timed out after 10s\n'
                 'Simulator guest inventory attempt 2/2 timed out after 30s\n'
                 'Simulator guest process inspection failed: ps timed out after 30 seconds', 'simulator-process-inventory'),
                ("Output cleanup refused: Command ['git', 'worktree', 'list'] timed out after 30 seconds", 'output-inventory'),
            ]
            for message, phase in messages:
                BUDGET.preparation_report(['test'], results, environment, 1, 40, message, 'package-test')
                reports = [json.loads(path.read_text()) for path in results.glob('*-diagnostics.json')]
                self.assertTrue(any(row['phase'] == phase and row['classification'] == 'tooling' for row in reports))
            AGGREGATE.main([directory, str(results / 'ci-diagnostics.json')], environment)
            aggregate = json.loads((results / 'ci-diagnostics.json').read_text())
            self.assertEqual(aggregate['category'], 'tooling')
            self.assertEqual({row['phase'] for row in aggregate['invocations']}, {phase for _, phase in messages})
            BUDGET.preparation_report(['test'], results, environment, 1, 40,
                                      messages[0][0] + '\nExpectation failed: savedReward == 10', 'package-test')
            AGGREGATE.main([directory, str(results / 'ci-diagnostics.json')], environment)
            self.assertEqual(json.loads((results / 'ci-diagnostics.json').read_text())['category'], 'test-failure')
            BUDGET.preparation_report(['test'], results, environment, 1, 40,
                                      messages[0][0] + '\nTest process crashed: signal SIGABRT', 'package-test')
            self.assertTrue(any(any(issue['kind'] == 'test-failure' and 'SIGABRT' in issue['message']
                                    for issue in json.loads(path.read_text())['issues'])
                                for path in results.glob('preparation-*-diagnostics.json')))

    def test_unit_and_parity_jobs_keep_sessions_and_separate_execution_deadlines(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        unit = workflow.split('  unit:\n', 1)[1].split('  native-parity:\n', 1)[0]
        parity = workflow.split('  native-parity:\n', 1)[1].split('  exhaustive-ui:\n', 1)[0]
        self.assertIn('TRINKET_DIAGNOSTICS_SESSION_ID: unit-', unit)
        self.assertNotIn('test-package-host.sh --compare-ios', unit)
        self.assertIn('export-ios', unit)
        self.assertIn("if: always() && steps.ios-proof.outcome == 'success'", unit)
        self.assertIn('TRINKET_DIAGNOSTICS_SESSION_ID: parity-', parity)
        self.assertIn('timeout-minutes: 25', parity)
        self.assertIn('+ 25 * 60 - 180', parity)
        self.assertIn("if: always() && !cancelled() && github.event_name != 'push' && !inputs.native-logic && needs.unit.result != 'skipped'", parity)
        self.assertIn('ios-parity-${{ matrix.source-shard }}-${{ github.run_id }}-${{ github.run_attempt }}', parity)
        self.assertIn('unit, native-parity]', workflow.split('  ci-ok:\n', 1)[1])
        self.assertIn("github.event_name != 'push' && !inputs.native-logic && needs.unit.result != 'skipped'", workflow.split('  ci-ok:\n', 1)[1])

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

    def test_aggregate_cannot_hide_a_failed_logic_stage_behind_passing_simulator_jobs(self):
        block = (ROOT / '.github/workflows/tests.yml').read_text().split('  ci-ok:\n', 1)[1].split('  exhaustive-ok:\n', 1)[0]
        names = [name.strip() for name in re.search(r'needs: \[(.*?)\]', block)[1].split(',')]
        jobs = {name: {'result': 'failure' if name == 'logic' else 'success'} for name in names}
        command = block.split('        run: |\n', 1)[1].split('\n  #', 1)[0]
        result = run_captured(['bash', '-ec', command], cwd=ROOT,
                              env={**os.environ, 'REQUIRE_PARITY': 'false', 'JOB_RESULTS': json.dumps(jobs)})
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_declared_job_timeouts_leave_a_diagnostic_reserve_before_checkout(self):
        for filename in ('tests.yml', 'diagnostic-ui.yml', 'gate.yml'):
            workflow = (ROOT / '.github/workflows' / filename).read_text()
            for block in re.split(r'^  [\w-]+:\n', workflow, flags=re.M):
                if 'TRINKET_CI_DEADLINE_EPOCH=' not in block:
                    continue
                minutes = re.search(r'timeout-minutes: (.+)', block)[1]
                declared, reserve = re.search(r'\+ (.+) \* 60 - (\d+)', block).groups()
                self.assertEqual(minutes, declared)
                self.assertRegex(minutes, r'^(?:\d+|\$\{\{.+\}\})$')
                self.assertGreaterEqual(int(reserve), 120)
                self.assertLess(block.index('TRINKET_CI_DEADLINE_EPOCH='), block.index('actions/checkout@'))

    def test_push_native_routing_keeps_manual_ios_comparators(self):
        # Exercise dispatcher defaults independently of the runner's selected backend.
        routing_env = {key: value for key, value in os.environ.items()
                       if key not in {'TRINKET_CI_NATIVE_PACKAGES', 'TRINKET_CI_NATIVE_LOGIC',
                                      'NATIVE_STATUS', 'IOS_STATUS'}}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'Scripts').mkdir()
            for name in ('test-ci-packages.sh', 'build-inputs.env'):
                shutil.copy(ROOT / 'Scripts' / name, root / 'Scripts' / name)
            for name, mode in (('test-package-host.sh', 'native'), ('test-package.sh', 'ios')):
                variable = 'NATIVE_STATUS' if mode == 'native' else 'IOS_STATUS'
                write_executable(root / 'Scripts' / name, '#!/bin/bash\nprintf "' + mode
                                 + ':%s\\n" "$*"\nexit "${' + variable + ':-0}"\n')
            packages = ['BattleEngine', 'TrinketCore', 'TrinketPersistence', 'TrinketAppState']
            contracts = 'ios:--only-suite FullGameStoreTests TrinketAppState'
            state = 'ios:--skip-suite FullGameStoreTests TrinketAppState'
            all_ios = [contracts, 'ios:BattleEngine TrinketCore TrinketPersistence', state]
            mixed = ['native:BattleEngine TrinketCore', contracts, 'ios:TrinketPersistence', state]
            for event, expected in [('push', mixed),
                                    ('workflow_dispatch', all_ios)]:
                result = run_captured(['bash', 'Scripts/test-ci-packages.sh', *packages], cwd=root, env={**routing_env, 'GITHUB_EVENT_NAME': event}, expected=0)
                self.assertEqual(result.stdout.splitlines(), expected)
            result = run_captured(['bash', 'Scripts/test-ci-packages.sh', *packages], cwd=root,
                                  env={**routing_env, 'GITHUB_EVENT_NAME': 'push',
                                       'TRINKET_CI_NATIVE_PACKAGES': ''}, expected=0)
            self.assertEqual(result.stdout.splitlines(), all_ios)
            result = run_captured(['bash', 'Scripts/test-ci-packages.sh', *packages], cwd=root,
                                  env={**routing_env, 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                                       'TRINKET_CI_NATIVE_LOGIC': 'true'}, expected=0)
            self.assertEqual(result.stdout.splitlines(), mixed)
            for qualified, expected in [('BattleEngine TrinketCore TrinketContent', ['native:TrinketContent', 'ios:TrinketDesignSystem']),
                                        ('BattleEngine TrinketCore', ['ios:TrinketContent TrinketDesignSystem'])]:
                result = run_captured(['bash', 'Scripts/test-ci-packages.sh', 'TrinketContent', 'TrinketDesignSystem'],
                                      cwd=root, env={**routing_env, 'GITHUB_EVENT_NAME': 'push',
                                                     'TRINKET_CI_NATIVE_PACKAGES': qualified}, expected=0)
                self.assertEqual(result.stdout.splitlines(), expected)
            # A failed Core run must still exercise saves and app transitions,
            # and a later success or failure must not erase the original exit.
            for native, ios, expected in ((17, 0, 17), (0, 23, 23), (17, 23, 17)):
                with self.subTest(native=native, ios=ios):
                    result = run_captured(['bash', 'Scripts/test-ci-packages.sh', *packages], cwd=root,
                                          env={**routing_env, 'GITHUB_EVENT_NAME': 'push',
                                               'NATIVE_STATUS': str(native), 'IOS_STATUS': str(ios)}, expected=expected)
                    self.assertEqual(result.stdout.splitlines(),
                                     mixed)

    def test_native_cache_omits_simulator_products_and_selected_identity_keeps_compatible_keys(self):
        action = (ROOT / '.github/actions/package-cache/action.yml').read_text()
        script = action.split('      run: |\n', 1)[1].split('    - uses:', 1)[0]
        script = '\n'.join(line[8:] for line in script.splitlines())
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            keys = []
            for native in ('true', 'false'):
                output.write_text('')
                subprocess.run(['bash', '-ec', script], check=True, capture_output=True,
                               cwd=ROOT,
                               env={**os.environ, 'NATIVE_ONLY': native, 'SHARD': 'Engine', 'PACKAGES': 'BattleEngine',
                                    'BUILD_KEY': 'key', 'BUILD_PREFIX': 'prefix', 'GITHUB_OUTPUT': str(output)})
                text = output.read_text()
                self.assertEqual('.DerivedData/packages' in text, native == 'false')
                self.assertIn('.DerivedData/host/BattleEngine\n', text)
                self.assertNotIn('.DerivedData/host\n', text)
                self.assertNotIn('.DerivedData/packages\n', text)
                self.assertEqual('package-native-v2' in text, native == 'true')
            # Content qualification selects one package, while the normal shard
            # also builds DesignSystem. Immutable caches must not collide.
            for packages in ('TrinketContent', 'TrinketContent TrinketDesignSystem',
                             'TrinketDesignSystem TrinketContent'):
                output.write_text('')
                subprocess.run(['bash', '-ec', script], check=True, capture_output=True, cwd=ROOT,
                               env={**os.environ, 'NATIVE_ONLY': 'false', 'SHARD': 'Content', 'PACKAGES': packages,
                                    'BUILD_KEY': 'key', 'BUILD_PREFIX': 'prefix', 'GITHUB_OUTPUT': str(output)})
                keys.append(output.read_text().splitlines()[:2])
            self.assertNotEqual(keys[0], keys[1])
            self.assertEqual(keys[1], keys[2])
        key_action = (ROOT / '.github/actions/build-cache-key/action.yml').read_text()
        command = re.search(r'^        toolchain=.*$', key_action, re.M)[0].strip()
        result = subprocess.check_output(['bash', '-ec', command + '\nprintf "%s" "$toolchain"'], text=True,
                                         env={**os.environ, 'XCODE_VERSION': '27.1', 'XCODE_BUILD': '27A9269'})
        self.assertEqual(result, hashlib.sha256(b'Xcode 27.1\nBuild version 27A9269\n').hexdigest())


if __name__ == '__main__':
    unittest.main()
