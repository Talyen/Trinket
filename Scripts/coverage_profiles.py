#!/usr/bin/env python3
"""Explicit simulator selection and restored native text settings for coverage."""
from __future__ import annotations

import argparse
from contextlib import contextmanager, ExitStack
import json
import os
import plistlib
import platform
import re
import shutil
from pathlib import Path
import subprocess
import sys

from internal.ci_simulator_services import prepare_components, start_device_ui
from internal.ci_capabilities import CapabilityUnavailable, UNAVAILABLE_MARKER, available_profiles, record_coverage

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


def coverage_matrix(scope):
    entries = [dict(profile=name, check='reward-return') for name in ('compact', 'tablet')]
    if scope in ('profiles', 'all'):
        entries += [dict(profile=name, check='profiles') for name in ('compact', 'tablet')]
    elif scope == 'rotation':
        entries = [dict(profile='duo', check='rotation')]
    elif scope != 'reward-return':
        raise ValueError(f'unsupported profile matrix scope: {scope}')
    return dict(include=entries)


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
    if not existing and os.environ.get('GITHUB_ACTIONS') == 'true':
        reusable = [item for item in devices.get(runtime['identifier'], [])
                    if item.get('deviceTypeIdentifier') == type_id and item.get('isAvailable', True)]
        reusable.sort(key=lambda item: (item.get('state') != 'Booted', item.get('udid', '')))
        if reusable:
            existing = reusable[0]['udid']
            subprocess.run(['xcrun', 'simctl', 'rename', existing, name], check=True, timeout=30, stdout=sys.stderr)
    print('\t'.join((type_id, runtime['identifier'], existing)))


def prepare_profile(name):
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        return prepare_runtime(*PROFILES[name])
    prepare_components(dict(os.environ))
    type_id, major = PROFILES[name]
    runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    types = json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes']
    devices = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    family = 'Duo' if name == 'duo' else 'iPad' if 'iPad' in type_id else 'iPhone'
    choices = available_profiles(runtimes, types, devices, family=family, preferred_device=type_id,
                                 major=major, sdk_version=os.environ.get('XCODE_VERSION', ''))
    if not choices:
        raise CapabilityUnavailable(f'No compatible installed {family} runtime at iOS 26 or later.')
    selected = choices[0]
    runtime = next(item for item in runtimes if item['identifier'] == selected['runtime']
                   and item.get('buildversion', '') == selected['build'])
    if selected['device'] != type_id or int(selected['version'].split('.')[0]) != major:
        record_coverage(f'requested-profile:{name}', 'unavailable',
                        f'Requested {type_id} / iOS {major}; using an installed compatible alternative.', details=selected)
    if path := os.environ.get('GITHUB_ENV'):
        with Path(path).open('a') as output:
            for key, value in dict(TRINKET_SIM_DEVICE_TYPE=selected['device'],
                                   TRINKET_SIM_OS_MAJOR=selected['version'].split('.')[0],
                                   TRINKET_SIM_OS_VERSION=selected['version'], TRINKET_SIM_OS_BUILD=selected['build'],
                                   TRINKET_CI_ADAPTIVE='1', TRINKET_CI_SIMULATOR_AVAILABLE='true').items():
                output.write(f'{key}={value}\n')
    record_coverage(f'profile-selection:{name}', 'available', details=selected)
    return runtime


def warm_runtime_cache(runtime, *, stdout=None):
    print(f"Preparing simulator dyld cache: iOS {runtime['version']} ({runtime.get('buildversion', '?')}).",
          file=stdout, flush=True)
    subprocess.run(['xcrun', 'simctl', 'runtime', 'dyld_shared_cache', 'update', runtime['identifier']],
                   check=True, timeout=300, stdout=stdout)
    start_device_ui()


def prepare_runtime(type_id, major, version=None, *, build=None, download_timeout=1800):
    prepare_components(dict(os.environ))
    types = json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes']
    runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    try:
        return select_profile(runtimes, types, type_id, major, version, build=build)
    except ValueError as error:
        if not str(error).startswith('unavailable iOS '):
            raise
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        raise CapabilityUnavailable(f'No compatible installed runtime for {type_id} / iOS {version or major}; CI does not download runtimes.')
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


def execute_profile(output, name, environment, command):
    log_path = output / f'{name}.log'
    print(f'Running settings profile: {name}', flush=True)
    with log_path.open('w') as log:
        result = subprocess.run(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
    print(log_path.read_text(), end='', flush=True)
    print(f'Settings profile {name}: {"passed" if result.returncode == 0 else "failed"}', flush=True)
    if result.returncode and os.environ.get('GITHUB_ACTIONS') == 'true':
        print(f'::error::Settings profile {name} failed; see its diagnostics above.', flush=True)
    return dict(profile=name, log=f'{name}.log', resultsDirectory=environment.get('RESULTS_DIR'),
                status='passed' if result.returncode == 0 else 'failed', exitCode=result.returncode)


def run_available_baseline(output, error):
    record_coverage('native-settings', 'unavailable',
                    f'Native text-size controls are unavailable: {error}. Running Smoke in the available environment; '
                    'largest text, Reduce Motion and native accessibility audits remain uncovered.')
    environment = dict(os.environ, TRINKET_UI_PLAN='Smoke', TRINKET_UI_SUCCESS_SCREENSHOTS='1')
    # A fallback must not inherit the entire native-profile job's execution budget.
    inherited = environment.get('TRINKET_XCODE_WALL_TIMEOUT_SECONDS', '')
    seconds = min(2100, int(inherited)) if inherited.isdecimal() and int(inherited) > 0 else 2100
    environment['TRINKET_XCODE_WALL_TIMEOUT_SECONDS'] = str(seconds)
    row = execute_profile(output, 'available-environment', environment,
                          ['./Scripts/test.sh', 'smoke', '--no-build'])
    row.update(plan='Smoke', textSize='uncontrolled', reduceMotion=None, nativeAuditsRequested=False,
               wallBudgetSeconds=seconds)
    (output / 'profiles.json').write_text(json.dumps([row], indent=2))
    return 0 if row['exitCode'] == 0 else 1


def run_profiles(udid, output, audit_policy='all'):
    if audit_policy not in ('all', 'representative'):
        raise ValueError(f'unsupported native audit policy: {audit_policy}')
    output.mkdir(parents=True, exist_ok=False)
    results = []
    with ExitStack() as settings:
        try:
            apply_size = settings.enter_context(native_text_size(udid))
        except (SimulatorPrerequisiteTimeout, ValueError, subprocess.SubprocessError) as error:
            if os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('TRINKET_CI_ADAPTIVE') == '1':
                return run_available_baseline(output, error)
            raise
        for name, size, reduced in [('default', TEXT_SIZES[0], False), ('largest', TEXT_SIZES[1], False),
                                     ('largest-reduced', TEXT_SIZES[1], True)]:
            environment = dict(os.environ, TRINKET_UI_PLAN='Profiles', TRINKET_UI_SUCCESS_SCREENSHOTS='1',
                               TEST_RUNNER_TRINKET_PROFILE_NAME=f'{output.name}/{name}',
                               TEST_RUNNER_TRINKET_PROFILE_AUDIT_POLICY=audit_policy,
                               TEST_RUNNER_TRINKET_PROFILE_LARGE_TEXT=str(int(size != 'large')),
                               TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION=str(int(reduced)))
            apply_size(size)
            row = execute_profile(output, name, environment,
                                  ['./Scripts/test.sh', 'ui', '--no-build', 'CriticalAccessibilityUITests'])
            results.append(dict(**row,
                                textSize=size, reduceMotion=reduced, nativeAuditsRequested=audit_policy == 'all' or name == 'largest',
                                reduceMotionSource='native Settings control with class restoration'))
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
    parser.add_argument('operation', choices=('matrix', 'definition', 'prepare', 'resolve', 'run', 'stage'))
    parser.add_argument('--scope', default='profiles')
    parser.add_argument('--name')
    parser.add_argument('--audit-policy', choices=('all', 'representative'), default='all')
    parser.add_argument('--udid')
    parser.add_argument('--results', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'matrix':
            print('matrix=' + json.dumps(coverage_matrix(args.scope), separators=(',', ':')))
            if os.environ.get('GITHUB_ACTIONS') == 'true' and (summary := os.environ.get('GITHUB_STEP_SUMMARY')):
                with Path(summary).open('a') as output:
                    output.write('### Planned player coverage\n\n' +
                                 ('One on-demand Duo rotation diagnostic.\n' if args.scope == 'rotation' else
                                  'Available iPhone and iPad reward-return journeys only.\n' if args.scope == 'reward-return' else
                                  'Available iPhone and iPad reward-return and native-settings journeys. '
                                  'Duo automation and duplicate iPadOS 26 settings are omitted from the default matrix. '
                                  'Actual OS/model substitutions and unavailable scope are retained in CICoverage receipts.\n'))
            return 0
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
        if not args.output:
            parser.error('run requires --output')
        return run_profiles(args.udid, args.output, args.audit_policy)
    except (CapabilityUnavailable, SimulatorPrerequisiteTimeout) as error:
        if path := os.environ.get('GITHUB_ENV'):
            with Path(path).open('a') as output:
                output.write('TRINKET_CI_SIMULATOR_AVAILABLE=false\nTRINKET_CI_ADAPTIVE=1\n')
        print(f'{UNAVAILABLE_MARKER} {error}', file=sys.stderr)
        return 78
    except (ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'Coverage prerequisite/cleanup failure: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
