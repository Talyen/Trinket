#!/usr/bin/env python3
"""Resume release verification by exact source/toolchain/profile, failing at the first failed phase."""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
import subprocess
import time
import tempfile
import uuid

from internal.cli import ROOT, load_sibling, primary_worktree_root, write_json_atomic
from internal.deploy_cache import Inputs, PhaseCache
from internal.ui_registration import registrations

BUILD = load_sibling('deploy_build_metadata', 'build-metadata.py')
REUSE = load_sibling('deploy_ci_reuse', 'ci-reuse.py')
PROFILES = load_sibling('deploy_profiles', 'coverage_profiles.py')
UI_RESULTS = load_sibling('deploy_ui_results', 'ci_ui_retry.py')

QUALIFIED_PROFILE = dict(device='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro',
                         runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-2', version='26.2', build='23C54')

CRITICAL_CASES = {
    'audio': 'AudioLifecycleUITests/testRealBackendsPlayAfterBattleAndForegroundRouting',
    'purchase': 'FullGamePurchaseUITests/testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase',
    'save': 'BattleLifecycleUITests/testCommittedRewardSurvivesTerminationWithoutReseeding',
    'battle': 'BattleLifecycleUITests/testBackgroundedProductionBattleAcceptsRapidCardsDragAndExit',
    'navigation': 'PlayModeNavigationUITests/testLabyrinthBossContinueOpensAUsableNextFloor',
}


def focused_cases(paths):
    if paths is None:
        return sorted(CRITICAL_CASES.values())
    risks = set()
    for path in paths:
        if path.endswith('.md') or path.startswith(('Docs/', 'Scripts/', '.github/', '.githooks/')):
            continue
        lowered = path.lower()
        if any(word in lowered for word in ('audio', 'music', 'sound', 'sfx')):
            risks.add('audio')
        elif any(word in lowered for word in ('purchase', 'fullgame', 'storekit', 'contentaccess')):
            risks.add('purchase')
        elif '/TrinketPersistence/' in path or any(word in lowered for word in ('reward', 'save', 'cloud')):
            risks.add('save')
        elif '/BattleEngine/' in path or '/TrinketBattleFeature/' in path or '/TrinketContent/' in path:
            risks.add('battle')
        elif path.startswith(('ContentManifest/', 'ArtManifest/')):
            risks.add('battle')
        elif path.startswith('Trinket/Features/Play/'):
            risks.update(('battle', 'navigation'))
        elif path.startswith(('Trinket/', 'Packages/', 'TrinketUITests/', 'StoreKit/')) or path.endswith('.xctestplan') or path == 'project.yml':
            # Shared/unknown product ownership gets every critical journey.
            risks.update(CRITICAL_CASES)
        elif path not in ('Gemfile', 'Gemfile.lock') and not path.startswith('.'):
            risks.update(CRITICAL_CASES)
    return sorted(CRITICAL_CASES[risk] for risk in risks)


def changed_since_release(base):
    if not base:
        return None
    capture('git', 'rev-parse', '--verify', f'{base}^{{commit}}')
    return capture('git', 'diff', '--no-renames', '--name-only', base, 'HEAD').splitlines()


def beta_ci_status(repository, commit, branch):
    pages = REUSE.api(f'repos/{repository}/actions/workflows/ci.yml/runs?head_sha={commit}&per_page=20')
    runs = [run for page in pages for run in page.get('workflow_runs', [])
            if run.get('head_sha') == commit and run.get('head_branch') == branch
            and (run.get('event') == 'push' or (run.get('event') == 'workflow_dispatch'
                 and run.get('display_title') == 'Trinket CI (verified)'))]
    if not runs:
        return dict(status='missing', smoke=False)
    run = max(runs, key=lambda item: int(item['id']))
    result = dict(status=run['status'], conclusion=run.get('conclusion'), run_id=run['id'], smoke=False)
    if run['status'] != 'completed':
        return result
    pages = REUSE.api(f'repos/{repository}/actions/runs/{run["id"]}/jobs?filter=all&per_page=100')
    latest = {job['name']: job for job in sorted(
        (job for page in pages for job in page.get('jobs', [])), key=lambda job: int(job['id']))}
    if run.get('conclusion') != 'success':
        result['failed_cases'] = failed_ui_cases(repository, latest.values())
        return result
    if latest.get('tests / CI OK', {}).get('conclusion') != 'success':
        raise ValueError('Green workflow has no successful CI OK gate; refusing release proof.')
    build = latest.get('tests / Build and smoke UI', {})
    result['smoke'] = build.get('conclusion') == 'success' and any(
        step.get('name') == 'Run smoke on the build runner' and step.get('conclusion') == 'success'
        for step in build.get('steps', []))
    return result


def failed_ui_cases(repository, jobs):
    cases = set()
    for job in jobs:
        if job.get('conclusion') != 'failure' or job.get('name') not in ('tests / Build and smoke UI', 'tests / Smoke UI'):
            continue
        try:
            log = capture('gh', 'api', f'repos/{repository}/actions/jobs/{int(job["id"])}/logs')
            for line in log.splitlines():
                if 'test-failure:' in line:
                    cases.update('/'.join(match) for match in re.findall(r'(\w+)/(test\w+)', line))
                elif 'error:' in line:
                    cases.update('/'.join(match) for match in re.findall(r'-\[TrinketUITests\.(\w+) (test\w+)\]', line))
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(f'Failed UI selector log unavailable: {error}', flush=True)
    return sorted(cases)


def wait_for_beta_ci(commit, cache=None):
    remote = capture('git', 'remote', 'get-url', 'origin')
    match = re.fullmatch(r'(?:https://github.com/|git@github.com:)([^/]+/[^/]+?)(?:\.git)?', remote)
    if not match:
        raise ValueError('Beta deployment requires a GitHub origin and green exact-commit CI.')
    branch = capture('git', 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD').removeprefix('origin/')
    deadline = time.monotonic() + int(os.environ.get('TRINKET_CI_WAIT_SECONDS', '1800'))
    while True:
        status = beta_ci_status(match[1], commit, branch)
        if status['status'] == 'completed':
            if status.get('conclusion') != 'success':
                if cache:
                    for selector in status.get('failed_cases', []):
                        cache.failed(f'ui:{selector}')
                raise ValueError(f'Exact-commit CI {status.get("run_id")} failed: {status.get("conclusion")}')
            print(f'Green CI: https://github.com/{match[1]}/actions/runs/{status["run_id"]}', flush=True)
            return status
        if time.monotonic() >= deadline:
            raise ValueError('Exact-commit CI is not green yet; resume this retained deployment after CI completes.')
        print(f'Waiting for exact-commit CI ({status["status"]}); signed artifacts remain retained.', flush=True)
        time.sleep(30)


def verify_hosted_beta(args, verification, identity):
    if not args.ci_only:
        targets = focused_cases(changed_since_release(os.environ.get('TRINKET_DEPLOY_BASE_COMMIT')))
        print(f'Beta focused journeys since last available build: {len(targets)}', flush=True)
        early = []
        if verification.cache:
            early = verification.cache.failed_cases()
            base = os.environ.get('TRINKET_DEPLOY_FEEDBACK_BASE_COMMIT')
            changed = changed_since_release(base) if base else None
            early += verification.cache.inputs.changed_cases(changed)
        early += sorted(verification.cache.inputs.smoke) if verification.cache else required_smoke_classes()
        # A selected full class already executes its required critical methods.
        classes = {name for name in early if '/' not in name}
        targets = list(dict.fromkeys(early + [name for name in targets if name.split('/')[0] not in classes]))
        targets = [name for name in targets if '/' not in name or name.split('/')[0] not in classes]
        print(f'Early changed/failed/Smoke UI selectors: {len(early)}', flush=True)
        for name in targets:
            verification.reuse(f'ui:{name}')
        pending = [name for name in targets if f'ui:{name}' not in verification.completed]
        if pending and not args.no_build:
            os.environ.pop('SKIP_GENERATE', None)
            subprocess.run(['./Scripts/build-for-testing.sh', '--reuse', '--app-only'], check=True)
        os.environ['SKIP_GENERATE'] = '1'
        smoke = verification.cache.inputs.smoke if verification.cache else required_smoke_classes()
        # Keep plan selection (and StoreKit configuration) intact while paying
        # simulator/XCTest startup once per plan, rather than once per selector.
        for mode in ('smoke', 'ui'):
            selected = [name for name in targets if (name.split('/')[0] in smoke) == (mode == 'smoke')]
            verification.ui_batch(mode, selected)
    if not args.focused_only:
        status = wait_for_beta_ci(identity['build']['commit'], verification.cache)
        verification.phase('ci', [], {'github': status})
        if status['smoke']:
            verification.phase('smoke', [], {'github': status})
        else:
            if not args.no_build:
                os.environ.pop('SKIP_GENERATE', None)
                subprocess.run(['./Scripts/build-for-testing.sh', '--reuse', '--app-only'], check=True)
            os.environ['SKIP_GENERATE'] = '1'
            verification.phase('smoke', ['./Scripts/test.sh', 'smoke', '--no-build'])


def hosted_release_status(repository, commit, branch):
    pages = REUSE.api(f'repos/{repository}/actions/workflows/release-verification.yml/runs?head_sha={commit}&per_page=20')
    runs = [run for page in pages for run in page.get('workflow_runs', [])
            if run.get('head_sha') == commit and run.get('head_branch') == branch
            and run.get('event') == 'workflow_dispatch']
    if not runs:
        return dict(status='missing')
    run = max(runs, key=lambda item: int(item['id']))
    result = dict(status=run['status'], conclusion=run.get('conclusion'), run_id=run['id'], attempt=run.get('run_attempt', 1))
    if run['status'] == 'completed' and run.get('conclusion') == 'success':
        pages = REUSE.api(f'repos/{repository}/actions/runs/{run["id"]}/jobs?filter=latest&per_page=100')
        jobs = [job for page in pages for job in page.get('jobs', [])]
        qualified = [job for job in jobs if job.get('name') == 'Qualified release journeys']
        if len(qualified) != 1 or qualified[0].get('conclusion') != 'success' or not any(
                step.get('name') == 'Verify all critical journeys on iOS 26.2'
                and step.get('conclusion') == 'success' for step in qualified[0].get('steps', [])):
            raise ValueError('Hosted release run lacks successful qualified journey evidence.')
    return result


def wait_for_release_ci(commit):
    remote = capture('git', 'remote', 'get-url', 'origin')
    match = re.fullmatch(r'(?:https://github.com/|git@github.com:)([^/]+/[^/]+?)(?:\.git)?', remote)
    if not match:
        raise ValueError('Release verification requires a GitHub origin.')
    repository = match[1]
    branch = capture('git', 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD').removeprefix('origin/')
    deadline = time.monotonic() + int(os.environ.get('TRINKET_CI_WAIT_SECONDS', '3600'))
    dispatched = False
    while True:
        status = hosted_release_status(repository, commit, branch)
        if status['status'] == 'missing' and not dispatched:
            tip = REUSE.api(f'repos/{repository}/git/ref/heads/{branch}')[0]['object']['sha']
            if tip != commit:
                raise ValueError('Push the release commit to the default branch before hosted verification; branch tip differs.')
            capture('gh', 'workflow', 'run', 'release-verification.yml', '--repo', repository, '--ref', branch, '-f', f'commit={commit}')
            dispatched = True
        elif status['status'] == 'completed':
            if status.get('conclusion') != 'success':
                raise ValueError(f'Hosted release verification {status["run_id"]} failed: {status.get("conclusion")}')
            print(f'Qualified hosted journeys: https://github.com/{repository}/actions/runs/{status["run_id"]}', flush=True)
            return status
        if time.monotonic() >= deadline:
            raise ValueError('Hosted release verification is pending; resume this retained deployment after it completes.')
        print(f'Waiting for hosted release journeys ({status["status"]}); no local simulator is required.', flush=True)
        time.sleep(30)


def required_smoke_classes():
    return sorted(row['name'] for row in registrations(ROOT) if row['suite'] == 'Smoke')


def validate_release_receipt(saved, identity):
    if not isinstance(saved, dict) or not isinstance(saved.get('identity'), dict):
        raise ValueError('Hosted release proof is malformed.')
    actual = saved['identity']
    if not isinstance(actual.get('build'), dict):
        raise ValueError('Hosted release proof lacks build identity.')
    required = ('commit', 'xcode', 'sdk', 'sdk_version', 'sdk_build', 'host_architecture')
    if saved.get('schema') != 1 or any(actual.get('build', {}).get(key) != identity['build'].get(key) for key in required):
        raise ValueError('Hosted release proof has a different commit, toolchain, SDK, or architecture.')
    if actual.get('profile') != identity['profile']:
        raise ValueError('Hosted release proof has a different simulator profile.')
    completed = saved.get('completed', {})
    if not isinstance(completed, dict) or any(f'ui:{name}' not in completed for name in required_smoke_classes()):
        raise ValueError('Hosted release proof is missing qualified Smoke coverage.')
    if any(
            f'ui:{case}' not in completed and f'ui:{case.split("/")[0]}' not in completed
            for case in CRITICAL_CASES.values()):
        raise ValueError('Hosted release proof is missing critical journeys.')


def release_receipt(status, identity):
    remote = capture('git', 'remote', 'get-url', 'origin')
    repository = re.fullmatch(r'(?:https://github.com/|git@github.com:)([^/]+/[^/]+?)(?:\.git)?', remote)[1]
    with tempfile.TemporaryDirectory(prefix='trinket-release-proof-') as directory:
        capture('gh', 'run', 'download', str(status['run_id']), '--repo', repository,
                '--name', f'release-proof-{status["run_id"]}-{status["attempt"]}', '--dir', directory)
        saved = json.loads((Path(directory) / 'deploy-verification.json').read_text())
    validate_release_receipt(saved, identity)
    return saved


def verify_beta(args, verification, identity):
    # Release clients only consume hosted proof. No automatic local fallback.
    if not args.ci_only:
        status = wait_for_release_ci(identity['build']['commit'])
        proof = release_receipt(status, identity)
        verification.phase('hosted-focused', [], {'github': status, 'identity': proof['identity'], 'qualified_smoke': True})
    if not args.focused_only:
        status = wait_for_beta_ci(identity['build']['commit'])
        qualified = verification.completed.get('hosted-focused', {}).get('evidence', {}).get('qualified_smoke') is True
        if not status['smoke'] and not qualified:
            raise ValueError('Exact-commit CI and qualified proof lack Smoke coverage; local fallback is disabled.')
        verification.phase('ci', [], {'github': status})
        verification.phase('smoke', [], {'github': status, 'qualified_hosted_smoke': qualified})


def capture(*command):
    return subprocess.check_output(command, text=True, timeout=60).strip()


def profile():
    # StoreKit denial/retry is qualified on 26.2; never silently use a newer OS.
    explicit = any(os.environ.get(key) for key in
                   ('TRINKET_SIM_DEVICE_TYPE', 'TRINKET_SIM_OS_VERSION', 'TRINKET_SIM_OS_MAJOR'))
    if not explicit:
        os.environ.update(TRINKET_SIM_DEVICE_TYPE='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro',
                          TRINKET_SIM_OS_VERSION='26.2')
    type_id = os.environ.get('TRINKET_SIM_DEVICE_TYPE')
    version = os.environ.get('TRINKET_SIM_OS_VERSION')
    major = os.environ.get('TRINKET_SIM_OS_MAJOR') or (version or '').split('.')[0]
    if not type_id or not major or not major.isdigit():
        raise ValueError('Explicit release profile requires TRINKET_SIM_DEVICE_TYPE and TRINKET_SIM_OS_VERSION or TRINKET_SIM_OS_MAJOR.')
    runtime = PROFILES.select_profile(
        json.loads(PROFILES.simctl('list', 'runtimes', 'available', '-j'))['runtimes'],
        json.loads(PROFILES.simctl('list', 'devicetypes', '-j'))['devicetypes'], type_id, int(major), version)
    runtime_build = runtime.get('buildversion')
    if not isinstance(runtime_build, str) or not runtime_build.strip():
        raise ValueError(f'Simulator runtime build is unavailable for iOS {runtime["version"]}.')
    os.environ.update(TRINKET_SIM_DEVICE_TYPE=type_id, TRINKET_SIM_OS_VERSION=runtime['version'])
    print(f'Release simulator preflight: {type_id}, iOS {runtime["version"]} ({runtime_build})', flush=True)
    return dict(device=type_id, runtime=runtime['identifier'], version=runtime['version'], build=runtime_build)


def verify_ui_runtime(manifest_path, expected_build):
    if manifest_path is None:
        raise ValueError('UI runtime execution receipt is missing.')
    manifest = UI_RESULTS.read(manifest_path)
    if manifest.get('result_bundle_complete') is not True or manifest.get('action') != 'test-without-building':
        raise ValueError('UI runtime requires a complete result bundle.')
    summary = json.loads(capture('xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                                 '--path', manifest['result_bundle'], '--compact'))
    configurations = summary.get('devicesAndConfigurations')
    if not isinstance(configurations, list) or not configurations:
        raise ValueError('UI runtime device evidence is missing.')
    devices = [item.get('device') if isinstance(item, dict) else None for item in configurations]
    if any(not isinstance(device, dict) or device.get('osBuildNumber') != expected_build for device in devices):
        raise ValueError(f'UI runtime build does not match qualified build {expected_build}: {devices}')
    return [{key: device.get(key) for key in ('modelName', 'osVersion', 'osBuildNumber', 'platform')}
            for device in devices]


class Verification:
    def __init__(self, state, identity, reusable, execute=None, cache=None):
        self.state, self.identity, self.reusable = state, identity, reusable
        self.cache = cache if reusable else None
        self.execute = execute or subprocess.run
        self.completed = {}
        if reusable and state.is_file():
            saved = json.loads(state.read_text())
            if saved.get('identity') == identity and saved.get('schema') == 1:
                self.completed = saved.get('completed', {})

    def save(self):
        if self.reusable:
            self.state.parent.mkdir(parents=True, exist_ok=True)
            write_json_atomic(self.state, dict(schema=1, identity=self.identity, completed=self.completed))

    def reuse(self, name):
        if name not in self.completed and self.cache:
            proof = self.cache.proof(name)
            if proof:
                self.completed[name] = dict(seconds=0, evidence=dict(local_cache=proof['commit'],
                                                                  input_key=self.cache.inputs.key(name)))
                self.save()
                print(f'Reusing passed UI inputs: {name} (source {proof["commit"]})', flush=True)

    def ui_batch(self, mode, selectors):
        for selector in selectors:
            self.reuse(f'ui:{selector}')
        pending = [selector for selector in selectors if f'ui:{selector}' not in self.completed]
        if not pending:
            return
        root = self.cache.inputs.root if self.cache else ROOT
        expected = {selector: UI_RESULTS.expected_cases([selector], root / 'TrinketUITests') for selector in pending}
        if any(not cases for cases in expected.values()):
            raise ValueError('Cannot establish complete UI coverage for the requested batch.')
        cases = sorted({case for selected in expected.values() for case in selected})
        session = 'release-ui-' + uuid.uuid4().hex
        results = Path(os.environ.get('RESULTS_DIR', '.DerivedData/TestResults')).resolve()
        before = set(results.glob('*-invocation.json'))
        failures = {selector: self.cache.read(self.cache.path(f'ui:{selector}', '-failed'))
                    for selector in pending} if self.cache else {}
        command = ['./Scripts/test.sh', mode, '--no-build', *pending]
        started = time.monotonic()
        error = None
        passed = set()
        try:
            # test.sh verifies every expected method executed exactly once and
            # passed, including rejecting absent and skipped purchase cases.
            self.execute(command, check=True, env={**os.environ,
                'TRINKET_DIAGNOSTICS_SESSION_ID': session, 'TRINKET_CLEANUP_TEST_ARTIFACTS': '0',
                'TRINKET_DEPLOY_EXPECTED_CASES': json.dumps(cases)})
            passed = set(pending)
        except (OSError, subprocess.SubprocessError) as failure:
            error = failure
            # A failed batch may still prove complete, passed selectors. Only
            # its fresh, complete result bundle can checkpoint those successes.
            manifest_path = UI_RESULTS.new_manifest(results, before, session, mode)
            try:
                manifest = UI_RESULTS.read(manifest_path) if manifest_path else {}
                if manifest.get('result_bundle_complete') is True and manifest.get('action') == 'test-without-building':
                    evidence = UI_RESULTS.parse_xcresult(Path(manifest['result_bundle']), manifest)
                    actual = UI_RESULTS.test_results(evidence)
                    if actual is not None and set(actual) == set(cases):
                        passed = {selector for selector, selected in expected.items()
                                  if all(actual[case] == 'Passed' for case in selected)}
            except (OSError, ValueError, KeyError, TypeError, SystemExit):
                pass
        runtime_devices = None
        if passed and self.identity['profile'].get('build'):
            manifest_path = UI_RESULTS.new_manifest(results, before, session, mode)
            runtime_devices = verify_ui_runtime(manifest_path, self.identity['profile']['build'])
        elapsed = round(time.monotonic() - started, 2)
        for selector in pending:
            name = f'ui:{selector}'
            if selector in passed:
                evidence = {'batch': session, 'mode': mode, 'batch_seconds': elapsed}
                if runtime_devices is not None:
                    evidence['runtime_devices'] = runtime_devices
                self.phase(name, [], evidence)
                if self.cache:
                    self.cache.passed(name, {**self.completed[name], 'evidence': 'local',
                                            'commit': self.identity['build']['commit']},
                                      failures[selector])
            elif self.cache:
                self.cache.failed(name)
        print(f'{mode} batch: {len(passed)}/{len(pending)} selectors passed ({elapsed}s)', flush=True)
        if error is not None:
            raise error

    def phase(self, name, command, evidence=None):
        self.reuse(name)
        if name in self.completed:
            print(f'Reusing verified phase: {name}', flush=True)
            return
        print(f'=== {name} ===', flush=True)
        started = time.monotonic()
        failure = self.cache.read(self.cache.path(name, '-failed')) if self.cache else None
        if evidence is None:
            try:
                options = dict(check=True)
                if self.cache and name.startswith('ui:'):
                    expected = UI_RESULTS.expected_cases([name.removeprefix('ui:')], self.cache.inputs.root / 'TrinketUITests')
                    if not expected:
                        raise ValueError(f'Cannot establish complete UI case coverage for {name}')
                    options['env'] = {**os.environ, 'TRINKET_DEPLOY_EXPECTED_CASES': json.dumps(expected)}
                self.execute(command, **options)
            except (OSError, subprocess.SubprocessError):
                if self.cache:
                    self.cache.failed(name)
                raise
        # Changed source cannot certify any phase, including a successful process.
        if self.reusable and capture('git', 'status', '--porcelain', '--untracked-files=all'):
            raise ValueError('Source changed during verification; completed phase was not retained.')
        if self.reusable and capture('git', 'rev-parse', 'HEAD') != self.identity['build']['commit']:
            raise ValueError('Source commit changed during verification.')
        self.completed[name] = dict(seconds=round(time.monotonic() - started, 2), evidence=evidence or 'local')
        if self.cache and evidence is None:
            self.cache.passed(name, dict(**self.completed[name], commit=self.identity['build']['commit']), failure)
        self.save()
        print(f'{name}: passed ({self.completed[name]["seconds"]}s)', flush=True)


def hosted_proof(commit):
    try:
        remote = capture('git', 'remote', 'get-url', 'origin')
        # Only the configured GitHub origin is queried; gh uses existing auth.
        match = re.fullmatch(r'(?:https://github.com/|git@github.com:)([^/]+/[^/]+?)(?:\.git)?', remote)
        if not match:
            return None
        branch = capture('git', 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD').removeprefix('origin/')
        proof = REUSE.find_proof(match[1], commit, branch, '')
        if proof['standard'] == 'true':
            return dict(repository=match[1], **proof)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'Hosted proof unavailable; running local phases: {error}', flush=True)
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('beta', 'hosted-beta', 'ui', 'smoke'), default='ui')
    parser.add_argument('--no-build', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--preflight', action='store_true')
    phases = parser.add_mutually_exclusive_group()
    phases.add_argument('--focused-only', action='store_true')
    phases.add_argument('--ci-only', action='store_true')
    args = parser.parse_args()
    if args.no_build and args.compile_only:
        parser.error('--compile-only cannot be combined with --no-build')
    if (args.focused_only or args.ci_only) and args.mode not in ('beta', 'hosted-beta'):
        parser.error('Phase selection requires --mode beta')
    if args.mode == 'hosted-beta' and os.environ.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('hosted-beta is restricted to GitHub Actions; beta consumes hosted evidence locally.')
    selected = dict(QUALIFIED_PROFILE) if args.mode == 'beta' else profile()
    if args.mode == 'hosted-beta' and selected != QUALIFIED_PROFILE:
        raise ValueError(f'Hosted beta requires the qualified simulator profile {QUALIFIED_PROFILE}; found {selected}.')
    # The beta client does not query or install local simulator runtimes.
    if args.preflight:
        return
    identity = dict(build=BUILD.identity(), profile=selected, root=str(ROOT))
    clean = not capture('git', 'status', '--porcelain', '--untracked-files=all')
    state = Path(os.environ.get('TRINKET_DEPLOY_VERIFICATION_STATE', ROOT / '.DerivedData/deploy-verification.json'))
    verification = Verification(state, identity, clean)
    if args.mode in ('beta', 'hosted-beta') and not args.compile_only:
        if not clean:
            raise ValueError('Beta verification requires a clean committed checkout.')
        cache = Path(os.environ.get('TRINKET_DEPLOY_CACHE_ROOT',
                     primary_worktree_root(ROOT) / '.DerivedData/testflight/verification-cache'))
        verification.cache = PhaseCache(cache, Inputs(ROOT, identity))
        if args.mode == 'hosted-beta':
            verify_hosted_beta(args, verification, identity)
        else:
            verify_beta(args, verification, identity)
        return
    if args.compile_only:
        verification.phase('gate', ['./Scripts/ci-gate.sh'])
        subprocess.run(['./Scripts/build-for-testing.sh', '--reuse'], check=True)
        return
    # Start local UI while hosted gate/unit/smoke jobs run. Query proof afterwards
    # so an in-progress push does not trigger duplicate local package execution.
    os.environ.pop('SKIP_GENERATE', None)
    if not args.no_build:
        subprocess.run(['./Scripts/build-for-testing.sh', '--reuse', '--app-only'], check=True)
    os.environ['SKIP_GENERATE'] = '1'
    if args.mode == 'ui':
        classes = capture('python3', 'Scripts/check-testplan-sync.py', '--classes', 'FullUI').split()
        if not classes:
            raise ValueError('FullUI registry selected no test classes.')
        for name in sorted(classes):
            verification.phase(f'ui:{name}', ['./Scripts/test.sh', 'ui', '--no-build', name])
    else:
        verification.phase('smoke', ['./Scripts/test.sh', 'smoke', '--no-build'])
    proof = hosted_proof(identity['build']['commit']) if clean else None
    evidence = {'github': proof} if proof else None
    verification.phase('gate', ['./Scripts/ci-gate.sh'], evidence)
    os.environ['SKIP_GENERATE'] = '1'
    if not proof and not args.no_build:
        subprocess.run(['./Scripts/build-for-testing.sh', '--reuse'], check=True)
    packages = capture('bash', '-c',
        'source Scripts/build-inputs.env; printf "%s\\n" "${TRINKET_TEST_PACKAGES[@]}"').splitlines()
    for package in packages:
        verification.phase(f'unit:{package}', ['./Scripts/test-package.sh', '--no-build', package], evidence)
    print('All deploy verification phases passed.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Deploy verification stopped: {error}')
