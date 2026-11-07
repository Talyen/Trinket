#!/usr/bin/env python3
"""Explicit simulator selection and restored native text settings for coverage."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
import plistlib
import platform
import re
import shutil
from pathlib import Path
import subprocess
import sys

PROFILES = {
    'compact': ('com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation', 26),
    'tablet26': ('com.apple.CoreSimulator.SimDeviceType.iPad-A16', 26),
    'tablet': ('com.apple.CoreSimulator.SimDeviceType.iPad-A16', 27),
    'duo': ('com.apple.CoreSimulator.SimDeviceType.iPhone-Duo', 27),
}
MINIMUM_RUNTIME_VERSIONS = {'com.apple.CoreSimulator.SimDeviceType.iPhone-Duo': (27, 1)}
# Match the release-qualified runtime; the semantic 26.2 download resolves to 23C52.
DEFAULT_DOWNLOAD_BUILDS = {26: '23C54'}
TEXT_SIZES = ('large', 'accessibility-extra-extra-extra-large')


def select_profile(runtimes, device_types, type_id, major, version=None, *, build=None):
    """Select the newest compatible runtime, honoring any exact version and build."""
    def components(value):
        parts = tuple(int(part) for part in value.split('.'))
        return parts + (0,) * (3 - len(parts))

    if not any(item.get('identifier') == type_id for item in device_types):
        raise ValueError(f'unavailable device type: {type_id}')
    candidates = [item for item in runtimes if item.get('isAvailable') is True
                  and item.get('platform') == 'iOS'
                  and str(item.get('version', '')).split('.')[0] == str(major)
                  and tuple(int(part) for part in item['version'].split('.'))
                  >= MINIMUM_RUNTIME_VERSIONS.get(type_id, (major, 0))]
    if version is not None:
        if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', version) or int(version.split('.')[0]) != major:
            raise ValueError(f'invalid or conflicting exact iOS version: {version}')
        candidates = [item for item in candidates if components(item['version']) == components(version)]
    if build is not None:
        if not re.fullmatch(r'\d+[A-Z]\d+[a-z]?', build):
            raise ValueError(f'invalid exact iOS build: {build}')
        candidates = [item for item in candidates if item.get('buildversion') == build]
    if not candidates:
        minimum = MINIMUM_RUNTIME_VERSIONS.get(type_id)
        requested = version or ('.'.join(map(str, minimum)) + '+' if minimum else str(major))
        detail = f' build {build}' if build else ''
        raise ValueError(f'unavailable iOS {requested}{detail} runtime')
    compatible = [item for item in candidates if not item.get('supportedDeviceTypes')
                  or any(device.get('identifier') == type_id for device in item['supportedDeviceTypes'])]
    if not compatible:
        newest = max(candidates, key=lambda item: components(item['version']))
        raise ValueError(f'{type_id} is incompatible with {newest["identifier"]}')
    return max(compatible, key=lambda item: (components(item['version']), item.get('buildversion', '')))


def simctl(*arguments):
    command = ['xcrun', 'simctl', *arguments]
    try:
        return subprocess.check_output(command, text=True, timeout=30).strip()
    except subprocess.TimeoutExpired:
        if arguments[:1] == ('list',):
            query = 'Simulator inventory'
        elif arguments[:1] == ('getenv',):
            query = 'Simulator launch-service query'
        elif arguments[:1] == ('ui',) and arguments[2:] == ('content_size',):
            query = 'Simulator text-size query'
        else:
            raise
        print(f'{query} timed out after 30s; retrying once.', file=sys.stderr)
        return subprocess.check_output(command, text=True, timeout=30).strip()


class SimulatorPrerequisiteTimeout(RuntimeError):
    """A simulator command exhausted its deadline before any XCTest ran."""


def prerequisite(phase, command, *args, **kwargs):
    try:
        return command(*args, **kwargs)
    except subprocess.TimeoutExpired as error:
        raise SimulatorPrerequisiteTimeout(f'{phase}: {error}') from error


def verify_launch_service(udid):
    home = prerequisite('launch-service', simctl, 'getenv', udid, 'HOME')
    if not home.startswith('/'):
        raise ValueError(f'simulator launch service returned an invalid HOME for {udid}')


@contextmanager
def native_text_size(udid, run=simctl):
    previous = prerequisite('text-size-readiness', run, 'ui', udid, 'content_size')
    if previous not in (*TEXT_SIZES, 'extra-small', 'small', 'medium', 'extra-large', 'extra-extra-large',
                        'extra-extra-extra-large', 'accessibility-medium', 'accessibility-large',
                        'accessibility-extra-large', 'accessibility-extra-extra-large'):
        raise ValueError(f'native content size unavailable: {previous}')

    current = previous

    def apply(requested):
        nonlocal current
        if current == requested:
            return
        current = None  # A command that times out may have applied the setting.
        try:
            run('ui', udid, 'content_size', requested)
            observed = run('ui', udid, 'content_size')
        except subprocess.SubprocessError as error:
            raise ValueError(f'native text-size transition to {requested}: {error}') from error
        if observed != requested:
            raise ValueError(f'native text-size transition to {requested} reported {observed}')
        current = observed

    try:
        yield apply
    finally:
        prior_error = sys.exc_info()[0]
        try:
            apply(previous)
        except (ValueError, subprocess.SubprocessError) as error:
            print(f'Native text-size restoration failed: {error}', file=sys.stderr)
            if prior_error is None:
                raise


def resolve(name):
    type_id = os.environ['TRINKET_SIM_DEVICE_TYPE']
    version = os.environ.get('TRINKET_SIM_OS_VERSION')
    major = int(os.environ.get('TRINKET_SIM_OS_MAJOR') or (version or '').split('.')[0])
    runtime = select_profile(json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes'],
                             json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes'], type_id, major, version,
                             build=os.environ.get('TRINKET_SIM_OS_BUILD'))
    devices = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    existing = next((item['udid'] for item in devices.get(runtime['identifier'], [])
                     if item.get('name') == name and item.get('deviceTypeIdentifier') == type_id), '')
    print('\t'.join((type_id, runtime['identifier'], existing)))


def prepare_profile(name):
    return prepare_runtime(*PROFILES[name])


def warm_runtime_cache(runtime, *, stdout=None):
    print(f"Preparing simulator dyld cache: iOS {runtime['version']} ({runtime.get('buildversion', '?')}).",
          file=stdout, flush=True)
    subprocess.run(['xcrun', 'simctl', 'runtime', 'dyld_shared_cache', 'update', runtime['identifier']],
                   check=True, timeout=300, stdout=stdout)


def prepare_runtime(type_id, major, version=None, *, build=None, download_timeout=1800):
    types = json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes']
    runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    try:
        return select_profile(runtimes, types, type_id, major, version, build=build)
    except ValueError as error:
        if not str(error).startswith('unavailable iOS '):
            raise
    minimum = MINIMUM_RUNTIME_VERSIONS.get(type_id, (major, 0))
    download_build = build or (DEFAULT_DOWNLOAD_BUILDS.get(major) if version is None else None)
    requested = download_build or version or '.'.join(map(str, minimum))
    variant = 'arm64' if platform.machine() == 'arm64' else 'universal'
    subprocess.run(['xcodebuild', '-downloadPlatform', 'iOS', '-buildVersion', requested,
                    '-architectureVariant', variant], check=True, timeout=download_timeout)
    runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    return select_profile(runtimes, types, type_id, major, version, build=download_build)


def record_identity(udid, output):
    developer = Path(os.environ.get('DEVELOPER_DIR') or subprocess.check_output(['xcode-select', '-p'], text=True).strip())
    version_path = developer.parent / 'version.plist'
    devices = json.loads(simctl('list', 'devices', udid, '-j'))['devices']
    selected = [(runtime, item) for runtime, items in devices.items() for item in items if item.get('udid') == udid]
    if len(selected) != 1:
        raise ValueError('requested simulator identity is missing or ambiguous')
    runtime, device = selected[0]
    identity = dict(device=device, runtime=runtime, xcode=plistlib.loads(version_path.read_bytes()),
                    commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                    dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()))
    (output / 'identity.json').write_text(json.dumps(identity, indent=2))


def run_profiles(udid, output, audit_policy='all'):
    if audit_policy not in ('all', 'representative'):
        raise ValueError(f'unsupported native audit policy: {audit_policy}')
    output.mkdir(parents=True, exist_ok=False)
    results = []
    with native_text_size(udid) as apply_size:
        for name, size, reduced in [('default', TEXT_SIZES[0], False), ('largest', TEXT_SIZES[1], False),
                                     ('largest-reduced', TEXT_SIZES[1], True)]:
            environment = dict(os.environ, TRINKET_UI_PLAN='Profiles', TRINKET_UI_SUCCESS_SCREENSHOTS='1',
                               TEST_RUNNER_TRINKET_PROFILE_NAME=f'{output.name}/{name}',
                               TEST_RUNNER_TRINKET_PROFILE_AUDIT_POLICY=audit_policy,
                               TEST_RUNNER_TRINKET_PROFILE_LARGE_TEXT=str(int(size != 'large')),
                               TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION=str(int(reduced)))
            apply_size(size)
            log_path = output / f'{name}.log'
            print(f'Running native settings profile: {name}', flush=True)
            with log_path.open('w') as log:
                result = subprocess.run(['./Scripts/test.sh', 'ui', '--no-build', 'CriticalAccessibilityUITests'],
                                        env=environment, stdout=log, stderr=subprocess.STDOUT)
            print(log_path.read_text(), end='', flush=True)
            print(f'Native settings profile {name}: {"passed" if result.returncode == 0 else "failed"}', flush=True)
            if result.returncode and os.environ.get('GITHUB_ACTIONS') == 'true':
                print(f'::error::Native settings profile {name} failed; see its diagnostics above.', flush=True)
            results.append(dict(profile=name, log=f'{name}.log', resultsDirectory=os.environ.get('RESULTS_DIR'),
                                textSize=size, reduceMotion=reduced, nativeAuditsRequested=audit_policy == 'all' or name == 'largest',
                                reduceMotionSource='native Settings control with class restoration',
                                status='passed' if result.returncode == 0 else 'failed', exitCode=result.returncode))
            (output / 'profiles.json').write_text(json.dumps(results, indent=2))
    # A failed readiness probe must not trigger an inventory request that can obscure it.
    record_identity(udid, output)
    return 0 if all(item['exitCode'] == 0 for item in results) else 1


def stage_results(results, output):
    # Use the same fail-closed artifact classification as the main CI lanes.
    subprocess.run(['./Scripts/ci-diagnostics.sh', str(results)], check=True)
    subprocess.run(['./Scripts/ci-diagnostics.sh', '--stage-artifacts', str(results), str(output)], check=True)
    category = json.loads((results / 'ci-diagnostics.json').read_text()).get('category')
    if category != 'passed':
        return  # Full failure bundles already retain audit screenshots.
    for bundle in results.glob('*.xcresult'):
        screenshots = output / f'{bundle.stem}-screenshots'
        try:
            subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle),
                            '--output-path', str(screenshots), '--filter', '*.png'], check=True, timeout=60)
            if not any(screenshots.glob('*.png')):
                raise ValueError('no profile screenshots exported')
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            # Missing screenshot evidence falls back to its original bundle.
            print(f'Screenshot export unavailable; retaining {bundle.name}: {error}', file=sys.stderr)
            shutil.copytree(bundle, output / bundle.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('definition', 'prepare', 'resolve', 'ready', 'run', 'stage'))
    parser.add_argument('--name')
    parser.add_argument('--audit-policy', choices=('all', 'representative'), default='all')
    parser.add_argument('--udid')
    parser.add_argument('--results', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'stage':
            if not args.results or not args.output:
                parser.error('stage requires --results and --output')
            stage_results(args.results, args.output)
            return 0
        if args.operation == 'definition':
            type_id, major = PROFILES[args.name]
            print(f'{type_id}\t{major}')
            return 0
        if args.operation == 'prepare':
            runtime = prerequisite('runtime-selection', prepare_profile, args.name)
            if os.environ.get('GITHUB_ACTIONS') == 'true':
                prerequisite('dyld-cache', warm_runtime_cache, runtime)
            return 0
        if args.operation == 'resolve':
            resolve(args.name)
            return 0
        if not args.udid:
            parser.error(f'{args.operation} requires --udid')
        if args.operation == 'ready':
            verify_launch_service(args.udid)
            return 0
        if not args.output:
            parser.error('run requires --output')
        return run_profiles(args.udid, args.output, args.audit_policy)
    except SimulatorPrerequisiteTimeout as error:
        print(f'Player coverage simulator prerequisite timed out: {error}', file=sys.stderr)
        return 2
    except (ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'Coverage prerequisite/cleanup failure: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
