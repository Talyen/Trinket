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

from internal.cli import ROOT, load_sibling, write_json_atomic

BUILD = load_sibling('deploy_build_metadata', 'build-metadata.py')
REUSE = load_sibling('deploy_ci_reuse', 'ci-reuse.py')
PROFILES = load_sibling('deploy_profiles', 'coverage_profiles.py')

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
    if run['status'] != 'completed' or run.get('conclusion') != 'success':
        return result
    pages = REUSE.api(f'repos/{repository}/actions/runs/{run["id"]}/jobs?filter=all&per_page=100')
    latest = {job['name']: job for job in sorted(
        (job for page in pages for job in page.get('jobs', [])), key=lambda job: int(job['id']))}
    if latest.get('tests / CI OK', {}).get('conclusion') != 'success':
        raise ValueError('Green workflow has no successful CI OK gate; refusing release proof.')
    build = latest.get('tests / Build and smoke UI', {})
    result['smoke'] = build.get('conclusion') == 'success' and any(
        step.get('name') == 'Run smoke on the build runner' and step.get('conclusion') == 'success'
        for step in build.get('steps', []))
    return result


def wait_for_beta_ci(commit):
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
                raise ValueError(f'Exact-commit CI {status.get("run_id")} failed: {status.get("conclusion")}')
            print(f'Green CI: https://github.com/{match[1]}/actions/runs/{status["run_id"]}', flush=True)
            return status
        if time.monotonic() >= deadline:
            raise ValueError('Exact-commit CI is not green yet; resume this retained deployment after CI completes.')
        print(f'Waiting for exact-commit CI ({status["status"]}); signed artifacts remain retained.', flush=True)
        time.sleep(30)


def verify_beta(args, verification, identity):
    if not args.ci_only:
        targets = focused_cases(changed_since_release(os.environ.get('TRINKET_DEPLOY_BASE_COMMIT')))
        pending = [name for name in targets if f'ui:{name}' not in verification.completed]
        print(f'Beta focused journeys since last available build: {len(targets)}', flush=True)
        if pending and not args.no_build:
            os.environ.pop('SKIP_GENERATE', None)
            subprocess.run(['./Scripts/build-for-testing.sh', '--reuse', '--app-only'], check=True)
        os.environ['SKIP_GENERATE'] = '1'
        for name in targets:
            verification.phase(f'ui:{name}', ['./Scripts/test.sh', 'ui', '--no-build', name])
    if not args.focused_only:
        status = wait_for_beta_ci(identity['build']['commit'])
        verification.phase('ci', [], {'github': status})
        if status['smoke']:
            verification.phase('smoke', [], {'github': status})
        else:
            if not args.no_build:
                os.environ.pop('SKIP_GENERATE', None)
                subprocess.run(['./Scripts/build-for-testing.sh', '--reuse', '--app-only'], check=True)
            os.environ['SKIP_GENERATE'] = '1'
            verification.phase('smoke', ['./Scripts/test.sh', 'smoke', '--no-build'])


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
    os.environ.update(TRINKET_SIM_DEVICE_TYPE=type_id, TRINKET_SIM_OS_VERSION=runtime['version'])
    print(f'Release simulator preflight: {type_id}, iOS {runtime["version"]}', flush=True)
    return dict(device=type_id, runtime=runtime['identifier'], version=runtime['version'])


class Verification:
    def __init__(self, state, identity, reusable, execute=None):
        self.state, self.identity, self.reusable = state, identity, reusable
        self.execute = execute or subprocess.run
        self.completed = {}
        if reusable and state.is_file():
            saved = json.loads(state.read_text())
            if saved.get('identity') == identity and saved.get('schema') == 1:
                self.completed = saved.get('completed', {})

    def phase(self, name, command, evidence=None):
        if name in self.completed:
            print(f'Reusing verified phase: {name}', flush=True)
            return
        print(f'=== {name} ===', flush=True)
        started = time.monotonic()
        if evidence is None:
            self.execute(command, check=True)
        # Changed source cannot certify any phase, including a successful process.
        if self.reusable and capture('git', 'status', '--porcelain', '--untracked-files=all'):
            raise ValueError('Source changed during verification; completed phase was not retained.')
        if self.reusable and capture('git', 'rev-parse', 'HEAD') != self.identity['build']['commit']:
            raise ValueError('Source commit changed during verification.')
        self.completed[name] = dict(seconds=round(time.monotonic() - started, 2), evidence=evidence or 'local')
        if self.reusable:
            self.state.parent.mkdir(parents=True, exist_ok=True)
            write_json_atomic(self.state, dict(schema=1, identity=self.identity, completed=self.completed))
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
    parser.add_argument('--mode', choices=('beta', 'ui', 'smoke'), default='ui')
    parser.add_argument('--no-build', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--preflight', action='store_true')
    phases = parser.add_mutually_exclusive_group()
    phases.add_argument('--focused-only', action='store_true')
    phases.add_argument('--ci-only', action='store_true')
    args = parser.parse_args()
    if args.no_build and args.compile_only:
        parser.error('--compile-only cannot be combined with --no-build')
    if (args.focused_only or args.ci_only) and args.mode != 'beta':
        parser.error('Phase selection requires --mode beta')
    selected = profile()  # Before generation, compilation, or a simulator lease.
    if args.preflight:
        return
    identity = dict(build=BUILD.identity(), profile=selected, root=str(ROOT))
    clean = not capture('git', 'status', '--porcelain', '--untracked-files=all')
    state = Path(os.environ.get('TRINKET_DEPLOY_VERIFICATION_STATE', ROOT / '.DerivedData/deploy-verification.json'))
    verification = Verification(state, identity, clean)
    if args.mode == 'beta' and not args.compile_only:
        if not clean:
            raise ValueError('Beta verification requires a clean committed checkout.')
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
