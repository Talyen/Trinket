#!/usr/bin/env python3
"""Explicit simulator selection and restored native text settings for coverage."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
import plistlib
from pathlib import Path
import subprocess
import sys

PROFILES = {
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
    try:
        run('ui', udid, 'content_size', size)
        if run('ui', udid, 'content_size') != size:
            raise ValueError('native content-size setting was not applied')
        yield
    finally:
        run('ui', udid, 'content_size', previous)
        if run('ui', udid, 'content_size') != previous:
            raise ValueError('native content-size cleanup failed')


def resolve(name):
    type_id = os.environ['TRINKET_SIM_DEVICE_TYPE']
    major = int(os.environ['TRINKET_SIM_OS_MAJOR'])
    runtime = select_profile(json.loads(simctl('list', 'runtimes', 'available', '-j'))['runtimes'],
                             json.loads(simctl('list', 'devicetypes', '-j'))['devicetypes'], type_id, major)
    devices = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    existing = next((item['udid'] for item in devices.get(runtime['identifier'], [])
                     if item.get('name') == name and item.get('deviceTypeIdentifier') == type_id), '')
    print('\t'.join((type_id, runtime['identifier'], existing)))


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
    for name, size, reduced in [('default', TEXT_SIZES[0], False), ('largest', TEXT_SIZES[1], False),
                                 ('largest-reduced', TEXT_SIZES[1], True)]:
        environment = dict(os.environ, TRINKET_UI_PLAN='Profiles', TRINKET_UI_SUCCESS_SCREENSHOTS='1',
                           TEST_RUNNER_TRINKET_PROFILE_LARGE_TEXT=str(int(size != 'large')),
                           TEST_RUNNER_TRINKET_PROFILE_REDUCE_MOTION=str(int(reduced)),
                           RESULTS_DIR=str(output / name))
        with native_text_size(udid, size):
            with (output / f'{name}.log').open('w') as log:
                result = subprocess.run(['./Scripts/test.sh', 'ui', '--no-build', 'CriticalAccessibilityUITests'],
                                        env=environment, stdout=log, stderr=subprocess.STDOUT)
        results.append(dict(profile=name, textSize=size, reduceMotion=reduced,
                            reduceMotionSource='native Settings control with per-test restoration',
                            status='passed' if result.returncode == 0 else 'failed', exitCode=result.returncode))
        (output / 'profiles.json').write_text(json.dumps(results, indent=2))
    return 0 if all(item['exitCode'] == 0 for item in results) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('definition', 'resolve', 'run'))
    parser.add_argument('--name')
    parser.add_argument('--udid')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'definition':
            type_id, major = PROFILES[args.name]
            print(f'{type_id}\t{major}')
            return 0
        if args.operation == 'resolve':
            resolve(args.name)
            return 0
        if not args.udid or not args.output:
            parser.error('run requires --udid and --output')
        return run_profiles(args.udid, args.output)
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Coverage prerequisite/cleanup failure: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
