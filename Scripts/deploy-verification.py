#!/usr/bin/env python3
"""Resume release verification by exact source/toolchain/profile, failing at the first failed phase."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import time

from internal.cli import ROOT, load_sibling, write_json_atomic

BUILD = load_sibling('deploy_build_metadata', 'build-metadata.py')
REUSE = load_sibling('deploy_ci_reuse', 'ci-reuse.py')
PROFILES = load_sibling('deploy_profiles', 'coverage_profiles.py')


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
        import re
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
    parser.add_argument('--mode', choices=('ui', 'smoke'), default='ui')
    parser.add_argument('--no-build', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    if args.no_build and args.compile_only:
        parser.error('--compile-only cannot be combined with --no-build')
    selected = profile()  # Before generation, compilation, or a simulator lease.
    if args.preflight:
        return
    identity = dict(build=BUILD.identity(), profile=selected, root=str(ROOT))
    clean = not capture('git', 'status', '--porcelain', '--untracked-files=all')
    state = Path(os.environ.get('TRINKET_DEPLOY_VERIFICATION_STATE', ROOT / '.DerivedData/deploy-verification.json'))
    verification = Verification(state, identity, clean)
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
