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
    def content_fixture(self, root):
        for path, text in {
            'Scripts/config/ui-tests.tsv': 'Smoke|SHOP|ShopTests\nFullUI||AudioTests\n',
            'TrinketUITests/Smoke/ShopTests.swift': 'final class ShopTests: Base {\n    func testBuy() {}\n}\n',
            'TrinketUITests/Battle/AudioTests.swift': 'final class AudioTests: Base {\n    func testMusic() {}\n}\n',
            'TrinketUITests/Support/Base.swift': 'class Base: XCTestCase {}\n',
            'Trinket/App.swift': 'let app = 1\n',
            'Packages/Engine/Tests/EngineTests.swift': 'let test = 1\n',
        }.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
        subprocess.run(['git', 'init', '-q', str(root)], check=True)

    def commit_inputs(self, root, **changes):
        for path, text in changes.items():
            (root / path).write_text(text)
        subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                        '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false',
                        'commit', '-qm', 'fixture', '--allow-empty'], check=True)
        commit = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        identity = dict(build=dict(commit=commit, xcode='27', sdk='27', host='arm64'),
                        profile=dict(runtime='26.2'), root=str(root))
        return identity, DEPLOY.Inputs(root, identity)

    def test_local_ui_cache_survives_unrelated_test_commits_but_not_dependencies_or_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'checkout'
            root.mkdir()
            self.content_fixture(root)
            identity, inputs = self.commit_inputs(root)
            cache = DEPLOY.PhaseCache(Path(directory) / 'cache', inputs)
            for phase in ('ui:AudioTests/testMusic', 'ui:ShopTests'):
                cache.passed(phase, dict(commit=identity['build']['commit'], evidence='local', seconds=1), {})
            identity2, changed = self.commit_inputs(root, **{
                'TrinketUITests/Smoke/ShopTests.swift': 'final class ShopTests: Base {\n    func testBuy() { fixed() }\n}\n'})
            self.assertNotEqual(identity['build']['commit'], identity2['build']['commit'])
            reused = DEPLOY.PhaseCache(cache.root, changed)
            self.assertIsNotNone(reused.proof('ui:AudioTests/testMusic'))
            self.assertIsNone(reused.proof('ui:ShopTests'))
            self.assertIsNone(reused.proof('ci'))
            self.assertIsNone(reused.proof('ui:UnregisteredTests'))
            with patch.dict(DEPLOY.os.environ, {'TRINKET_MAX_AGENT_SIMS': '2', 'TRINKET_AGENT_SLOT': '2'}):
                self.assertEqual(changed.key('ui:AudioTests/testMusic'), DEPLOY.Inputs(root, identity2).key('ui:AudioTests/testMusic'))
            with patch.dict(DEPLOY.os.environ, {'TRINKET_UI_LOCALE': 'fr'}):
                self.assertNotEqual(changed.key('ui:AudioTests/testMusic'), DEPLOY.Inputs(root, identity2).key('ui:AudioTests/testMusic'))
            self.assertEqual(changed.changed_cases(['TrinketUITests/Smoke/ShopTests.swift']), ['ShopTests'])
            self.assertEqual(changed.changed_cases(['TrinketUITests/README.md']), [])
            self.assertEqual(changed.changed_cases(['TrinketUITests/README.md', 'TrinketUITests/Smoke/ShopTests.swift']), ['ShopTests'])
            _, package_test = self.commit_inputs(root, **{'Packages/Engine/Tests/EngineTests.swift': 'let test = 2'})
            self.assertEqual(changed.key('ui:AudioTests/testMusic'), package_test.key('ui:AudioTests/testMusic'))
            for field in ('build', 'profile'):
                altered = copy.deepcopy(identity2)
                altered[field]['changed'] = 'new'
                self.assertNotEqual(changed.key('ui:AudioTests/testMusic'), DEPLOY.Inputs(root, altered).key('ui:AudioTests/testMusic'))
            for path in ('TrinketUITests/Support/Base.swift', 'Trinket/App.swift'):
                _, altered = self.commit_inputs(root, **{path: (root / path).read_text() + '// changed\n'})
                self.assertIsNone(DEPLOY.PhaseCache(cache.root, altered).proof('ui:AudioTests/testMusic'))

    def test_shared_extensions_and_referenced_test_classes_invalidate_dependents(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.content_fixture(root)
            _, initial = self.commit_inputs(root, **{'TrinketUITests/Battle/AudioTests.swift':
                'final class AudioTests: Base {\n    func testMusic() {}\n}\nextension Base { func shared() {} }\n'})
            _, changed = self.commit_inputs(root, **{'TrinketUITests/Battle/AudioTests.swift':
                'final class AudioTests: Base {\n    func testMusic() {}\n}\nextension Base { func shared() { fixed() } }\n'})
            self.assertNotEqual(initial.key('ui:ShopTests'), changed.key('ui:ShopTests'))
            self.assertEqual(changed.changed_cases(['TrinketUITests/Battle/AudioTests.swift']), ['AudioTests', 'ShopTests'])
            _, referenced = self.commit_inputs(root, **{
                'TrinketUITests/Smoke/ShopTests.swift': 'final class ShopTests: Base {\n    func testBuy() { AudioTests.helper() }\n}\n',
                'TrinketUITests/Battle/AudioTests.swift': 'final class AudioTests: Base {\n    func testMusic() {}\n    static func helper() {}\n}\n'})
            _, edited = self.commit_inputs(root, **{'TrinketUITests/Battle/AudioTests.swift':
                'final class AudioTests: Base {\n    func testMusic() {}\n    static func helper() { fixed() }\n}\n'})
            self.assertNotEqual(referenced.key('ui:ShopTests'), edited.key('ui:ShopTests'))

    def test_failed_ui_is_prioritized_and_cannot_reuse_previous_success_or_malformed_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'checkout'
            root.mkdir()
            self.content_fixture(root)
            identity, inputs = self.commit_inputs(root)
            cache = DEPLOY.PhaseCache(Path(directory) / 'cache', inputs)
            phase = 'ui:ShopTests'
            cache.passed(phase, dict(commit=identity['build']['commit'], evidence='local', seconds=1), {})
            cache.passed('ui:ShopTests/testBuy', dict(commit=identity['build']['commit'], evidence='local', seconds=1), {})
            cache.failed('ui:ShopTests/testBuy')
            self.assertIsNone(cache.proof('ui:ShopTests/testBuy'))
            self.assertIsNone(cache.proof(phase))

            self.assertEqual(cache.failed_cases(), ['ShopTests'])
            commands = []
            state = Path(directory) / 'run.json'
            verification = DEPLOY.Verification(state, identity, True, execute=lambda command, **_: commands.append(command), cache=cache)
            args = type('Args', (), dict(ci_only=False, focused_only=True, no_build=True))()
            with patch.object(DEPLOY, 'capture', side_effect=lambda *args: identity['build']['commit'] if args[:2] == ('git', 'rev-parse') else ''), \
                    patch.object(DEPLOY, 'changed_since_release', return_value=['Trinket/App.swift']), \
                    patch.dict(DEPLOY.CRITICAL_CASES, {'audio': 'AudioTests/testMusic', 'purchase': 'ShopTests/testBuy'}, clear=True):
                DEPLOY.verify_hosted_beta(args, verification, identity)
            self.assertEqual(commands[0], ['./Scripts/test.sh', 'ui', '--no-build', 'ShopTests'])
            self.assertFalse(cache.failed_cases())
            self.assertIsNotNone(cache.proof(phase))
            self.assertIsNone(DEPLOY.PhaseCache(cache.root, inputs).proof('ci'))
            proof = cache.path(phase, f'-{inputs.key(phase)}')
            value = json.loads(proof.read_text())
            value['result'] = True
            proof.write_text(json.dumps(value))
            self.assertIsNone(cache.proof(phase))
            proof.write_text('broken JSON')
            self.assertIsNone(cache.proof(phase))

    def test_only_changed_class_reruns_while_unchanged_critical_ui_uses_content_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'checkout'
            root.mkdir()
            self.content_fixture(root)
            identity, inputs = self.commit_inputs(root)
            cache = DEPLOY.PhaseCache(Path(directory) / 'cache', inputs)
            cache.passed('ui:AudioTests/testMusic', dict(commit=identity['build']['commit'], evidence='local', seconds=100), {})
            identity, changed = self.commit_inputs(root, **{'TrinketUITests/Smoke/ShopTests.swift':
                'final class ShopTests: Base {\n    func testBuy() { fixed() }\n}\n'})
            cache.inputs = changed
            calls = []
            verification = DEPLOY.Verification(Path(directory) / 'new-run.json', identity, True,
                execute=lambda command, **_: calls.append(command), cache=cache)
            args = type('Args', (), dict(ci_only=False, focused_only=True, no_build=False))()
            with patch.dict(DEPLOY.os.environ, {'TRINKET_DEPLOY_FEEDBACK_BASE_COMMIT': 'previous'}), \
                    patch.object(DEPLOY, 'capture', side_effect=lambda *args: identity['build']['commit'] if args[:2] == ('git', 'rev-parse') else ''), \
                    patch.object(DEPLOY, 'changed_since_release', return_value=['TrinketUITests/Smoke/ShopTests.swift']), \
                    patch.object(DEPLOY.subprocess, 'run', side_effect=lambda command, **_: calls.append(command)), \
                    patch.dict(DEPLOY.CRITICAL_CASES, {'audio': 'AudioTests/testMusic', 'purchase': 'ShopTests/testBuy'}, clear=True):
                DEPLOY.verify_hosted_beta(args, verification, identity)
            self.assertEqual(calls, [['./Scripts/build-for-testing.sh', '--reuse', '--app-only'],
                                     ['./Scripts/test.sh', 'ui', '--no-build', 'ShopTests']])
            self.assertIn('local_cache', verification.completed['ui:AudioTests/testMusic']['evidence'])

    def test_hosted_failure_selectors_are_read_only_from_failed_ui_jobs(self):
        jobs = [dict(id=1, name='tests / Build and smoke UI', conclusion='failure'),
                dict(id=2, name='tests / Unit tests (State)', conclusion='failure')]
        log = '''ordinary selected PassingTests/testSomething
1. test-failure: TrinketUITests (ShopTests/testBuy())
error: -[TrinketUITests.AudioTests testMusic] : Failed
'''
        with patch.object(DEPLOY, 'capture', return_value=log) as capture:
            self.assertEqual(DEPLOY.failed_ui_cases('owner/repo', jobs), ['AudioTests/testMusic', 'ShopTests/testBuy'])
            capture.assert_called_once_with('gh', 'api', 'repos/owner/repo/actions/jobs/1/logs')
    def test_beta_consumes_hosted_evidence_without_local_fallback(self):
        for hosted_smoke in (False, True):
            with self.subTest(hosted_smoke=hosted_smoke), tempfile.TemporaryDirectory() as directory:
                identity = dict(build=dict(commit='abc'), profile=dict(version='26.2'))
                calls = []
                verification = DEPLOY.Verification(Path(directory) / 'verification.json', identity, True,
                    execute=lambda command, **_: calls.append(command))
                args = type('Args', (), dict(ci_only=False, focused_only=False, no_build=False))()
                with patch.object(DEPLOY, 'wait_for_beta_ci', return_value=dict(smoke=hosted_smoke, run_id=42)), \
                        patch.object(DEPLOY, 'wait_for_release_ci', return_value=dict(run_id=43)), \
                        patch.object(DEPLOY, 'release_receipt', return_value=dict(identity=identity)), \
                        patch.object(DEPLOY, 'capture', side_effect=lambda *c: 'abc' if c[:2] == ('git', 'rev-parse') else ''):
                    if hosted_smoke:
                        DEPLOY.verify_beta(args, verification, identity)
                        self.assertEqual(set(verification.completed), {'hosted-focused', 'ci', 'smoke'})
                    else:
                        with self.assertRaisesRegex(ValueError, 'local fallback is disabled'):
                            DEPLOY.verify_beta(args, verification, identity)
                self.assertEqual(calls, [])

    def test_beta_preflight_does_not_inspect_or_boot_local_simulators(self):
        with patch.object(sys, 'argv', ['deploy-verification.py', '--mode', 'beta', '--preflight']), \
                patch.object(DEPLOY, 'profile', side_effect=AssertionError('local simulator queried')), \
                patch.object(DEPLOY.BUILD, 'identity', side_effect=AssertionError('native build queried')):
            DEPLOY.main()

    def test_hosted_receipt_requires_actual_profile_toolchain_and_complete_journeys(self):
        identity = dict(build=dict(commit='abc', xcode='27', sdk='iphonesimulator', sdk_version='27.1',
                                   sdk_build='abc', host_architecture='arm64'), profile=dict(version='26.2'))
        saved = dict(schema=1, identity=copy.deepcopy(identity),
                     completed={f'ui:{case}': dict(evidence='local') for case in DEPLOY.CRITICAL_CASES.values()})
        DEPLOY.validate_release_receipt(saved, identity)
        for field in ('commit', 'xcode', 'sdk_version', 'sdk_build', 'host_architecture'):
            changed = copy.deepcopy(saved)
            changed['identity']['build'][field] = 'different'
            with self.assertRaises(ValueError):
                DEPLOY.validate_release_receipt(changed, identity)
        changed = copy.deepcopy(saved)
        changed['identity']['profile']['version'] = '27.1'
        with self.assertRaisesRegex(ValueError, 'profile'):
            DEPLOY.validate_release_receipt(changed, identity)
        saved['completed'].pop(next(iter(saved['completed'])))
        with self.assertRaisesRegex(ValueError, 'missing critical'):
            DEPLOY.validate_release_receipt(saved, identity)

    def test_release_proof_requires_exact_commit_branch_and_successful_qualified_step(self):
        run = dict(id=10, head_sha='abc', head_branch='main', event='workflow_dispatch',
                   status='completed', conclusion='success')
        job = dict(name='Qualified release journeys', conclusion='success',
                   steps=[dict(name='Verify all critical journeys on iOS 26.2', conclusion='success')])
        def status(runs, jobs):
            with patch.object(DEPLOY.REUSE, 'api', side_effect=[[dict(workflow_runs=runs)], [dict(jobs=jobs)]]):
                return DEPLOY.hosted_release_status('owner/repo', 'abc', 'main')
        self.assertEqual(status([run], [job])['conclusion'], 'success')
        for changes in ({'head_sha': 'old'}, {'head_branch': 'other'}, {'event': 'push'}):
            self.assertEqual(status([{**run, **changes}], [job])['status'], 'missing')
        for jobs in ([], [{**job, 'conclusion': 'skipped'}], [{**job, 'steps': []}]):
            with self.assertRaisesRegex(ValueError, 'qualified journey evidence'):
                status([run], jobs)
        self.assertEqual(status([{**run, 'conclusion': 'failure'}], [])['conclusion'], 'failure')

    def test_beta_selection_compares_shipping_changes_and_unknown_product_ownership_fails_broad(self):
        self.assertEqual(DEPLOY.focused_cases([]), [])
        self.assertEqual(DEPLOY.focused_cases(['Scripts/internal/testflight.rb', 'Docs/Platform/Release.md']), [])
        self.assertEqual(DEPLOY.focused_cases(['Packages/TrinketPersistence/Sources/Cloud/CloudSaveMerge.swift']),
                         [DEPLOY.CRITICAL_CASES['save']])
        self.assertEqual(DEPLOY.focused_cases(['StoreKit/Trinket.storekit']), [DEPLOY.CRITICAL_CASES['purchase']])
        self.assertEqual(DEPLOY.focused_cases(['Packages/BattleEngine/Sources/Combat.swift']), [DEPLOY.CRITICAL_CASES['battle']])
        for paths in (None, ['Trinket/App/ContentView.swift'], ['project.yml'], ['NewProductInput/input.json']):
            self.assertEqual(DEPLOY.focused_cases(paths), sorted(DEPLOY.CRITICAL_CASES.values()))
        # Selectors must exist as concrete non-inherited methods in their owner.
        retry = load_script('beta_selector_check', 'ci_ui_retry.py')
        self.assertEqual(set(retry.expected_cases(list(DEPLOY.CRITICAL_CASES.values()))), set(DEPLOY.CRITICAL_CASES.values()))

    def test_beta_ci_requires_latest_exact_commit_gate_and_actual_smoke_step(self):
        run = dict(id=10, head_sha='abc', head_branch='main', event='push', status='completed', conclusion='success')
        jobs = [dict(id=1, name='tests / CI OK', conclusion='success'),
                dict(id=2, name='tests / Build and smoke UI', conclusion='success',
                     steps=[dict(name='Run smoke on the build runner', conclusion='success')])]
        def status(runs, selected=jobs):
            with patch.object(DEPLOY.REUSE, 'api', side_effect=[[dict(workflow_runs=runs)], [dict(jobs=selected)]]):
                return DEPLOY.beta_ci_status('owner/repo', 'abc', 'main')
        self.assertTrue(status([run])['smoke'])
        self.assertFalse(status([run], jobs[:1])['smoke'])
        for changes in ({'head_sha': 'old'}, {'head_branch': 'other'}, {'event': 'schedule'},
                        {'event': 'workflow_dispatch', 'display_title': 'Trinket CI (latest)'}):
            self.assertEqual(status([{**run, **changes}])['status'], 'missing')
        for conclusion in ('skipped', 'failure', 'cancelled'):
            self.assertEqual(status([{**run, 'conclusion': conclusion}])['conclusion'], conclusion)
        with self.assertRaisesRegex(ValueError, 'no successful CI OK'):
            status([run], jobs[1:])
        self.assertEqual(status([run, {**run, 'id': 11, 'conclusion': 'failure'}])['conclusion'], 'failure')

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
