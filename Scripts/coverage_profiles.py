#!/usr/bin/env python3
"""Explicit simulator selection and restored native text settings for coverage."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
import plistlib
import shutil
from pathlib import Path
import subprocess
import sys

PROFILES = {
    'ios18': ('com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation', 18),
    'compact': ('com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation', 26),
    'tablet': ('com.apple.CoreSimulator.SimDeviceType.iPad-A16', 27),
}
TEXT_SIZES = ('large', 'accessibility-extra-extra-extra-large')


def select_profile(runtimes, device_types, type_id, major):
    """Fail closed: a requested runtime/type never falls back to another profile."""
    if not any(item.get('identifier') == type_id for item in device_types):
        raise ValueError(f'unavailable device type: {type_id}')
    candidates = [item for item in runtimes if item.get('isAvailable') is True
                  and item.get('platform') == 'iOS'
                  and str(item.get('version', '')).split('.')[0] == str(major)]
    if not candidates:
        raise ValueError(f'unavailable iOS {major} runtime')
    selected = max(candidates, key=lambda item: tuple(int(part) for part in item['version'].split('.')))
    supported = selected.get('supportedDeviceTypes')
    if supported and not any(item.get('identifier') == type_id for item in supported):
        raise ValueError(f'{type_id} is incompatible with {selected["identifier"]}')
    return selected


def simctl(*arguments):
    return subprocess.check_output(['xcrun', 'simctl', *arguments], text=True).strip()


@contextmanager
def native_text_size(udid, size, run=simctl):
    previous = run('ui', udid, 'content_size')
    if previous not in (*TEXT_SIZES, 'extra-small', 'small', 'medium', 'extra-large', 'extra-extra-large',
                        'extra-extra-extra-large', 'accessibility-medium', 'accessibility-large',
                        'accessibility-extra-large', 'accessibility-extra-extra-large'):
        raise ValueError(f'native content size unavailable: {previous}')
    def apply(requested):
        if run('ui', udid, 'content_size') != requested:
            run('ui', udid, 'content_size', requested)
        if run('ui', udid, 'content_size') != requested:
            raise ValueError('native content-size setting was not applied')
    try:
        apply(size)
        yield apply
    finally:
        apply(previous)


def resolve(name):
    type_id = os.environ['TRINKET_SIM_DEVICE_TYPE']
    major = int(os.environ['TRINKET_SIM_OS_MAJOR'])
    runtime = select_profile(json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes'],
                             json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes'], type_id, major)
    devices = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    existing = next((item['udid'] for item in devices.get(runtime['identifier'], [])
                     if item.get('name') == name and item.get('deviceTypeIdentifier') == type_id), '')
    print('\t'.join((type_id, runtime['identifier'], existing)))


def prepare_profile(name):
    type_id, major = PROFILES[name]
    types = json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes']
    if not any(item.get('identifier') == type_id for item in types):
        raise ValueError(f'unavailable device type: {type_id}')
    runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    if not any(item.get('isAvailable') is True and item.get('platform') == 'iOS'
               and str(item.get('version', '')).split('.')[0] == str(major) for item in runtimes):
        subprocess.run(['xcodebuild', '-downloadPlatform', 'iOS', '-buildVersion', f'{major}.0'],
                       check=True, timeout=1800)
        runtimes = json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    select_profile(runtimes, types, type_id, major)


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


def run_profiles(udid, output):
    output.mkdir(parents=True, exist_ok=False)
    record_identity(udid, output)
    results = []
    with native_text_size(udid, TEXT_SIZES[0]) as apply_size:
        for name, size, reduced in [('default', TEXT_SIZES[0], False), ('largest', TEXT_SIZES[1], False),
                                     ('largest-reduced', TEXT_SIZES[1], True)]:
            environment = dict(os.environ, TRINKET_UI_PLAN='Profiles', TRINKET_UI_SUCCESS_SCREENSHOTS='1',
                               TEST_RUNNER_TRINKET_PROFILE_LARGE_TEXT=str(int(size != 'large')),
                               TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION=str(int(reduced)))
            apply_size(size)
            with (output / f'{name}.log').open('w') as log:
                result = subprocess.run(['./Scripts/test.sh', 'ui', '--no-build', 'CriticalAccessibilityUITests'],
                                        env=environment, stdout=log, stderr=subprocess.STDOUT)
            results.append(dict(profile=name, log=f'{name}.log', resultsDirectory=os.environ.get('RESULTS_DIR'),
                                textSize=size, reduceMotion=reduced,
                                reduceMotionSource='native Settings control with class restoration',
                                status='passed' if result.returncode == 0 else 'failed', exitCode=result.returncode))
            (output / 'profiles.json').write_text(json.dumps(results, indent=2))
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
    parser.add_argument('operation', choices=('definition', 'prepare', 'resolve', 'run', 'stage'))
    parser.add_argument('--name')
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
            prepare_profile(args.name)
            return 0
        if args.operation == 'resolve':
            resolve(args.name)
            return 0
        if not args.udid or not args.output:
            parser.error('run requires --udid and --output')
        return run_profiles(args.udid, args.output)
    except (ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'Coverage prerequisite/cleanup failure: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
