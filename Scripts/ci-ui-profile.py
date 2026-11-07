#!/usr/bin/env python3
"""Select an installed compatible CI simulator without downloading a runtime."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from internal.cli import load_sibling
from internal.ci_simulator_services import prepare_components
from internal.ci_capabilities import CapabilityUnavailable, UNAVAILABLE_MARKER, available_profiles, record_coverage

PROFILES = load_sibling('qualified_ui_profiles', 'coverage_profiles.py')
QUALIFIED_PROFILE = dict(device='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro',
                         runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-2', version='26.2', build='23C54')


def profile_environment(profile=None):
    profile = QUALIFIED_PROFILE if profile is None else profile
    return dict(TRINKET_SIM_DEVICE_TYPE=profile['device'],
                TRINKET_SIM_OS_MAJOR=profile['version'].split('.')[0],
                TRINKET_SIM_OS_VERSION=profile['version'],
                TRINKET_SIM_OS_BUILD=profile['build'],
                TEST_RUNNER_TRINKET_EXPECTED_OS_BUILD=profile['build'])


def require_environment(environment):
    version = environment.get('TRINKET_SIM_OS_VERSION', '')
    if (not environment.get('TRINKET_SIM_DEVICE_TYPE') or not version
            or not version.split('.')[0].isdigit() or int(version.split('.')[0]) < 26
            or not environment.get('TRINKET_SIM_OS_BUILD')):
        raise ValueError('Functional UI requires an installed iOS 26+ profile; run ci-ui-profile.py prepare first.')


def prepare(environment):
    if environment.get('GITHUB_ACTIONS') != 'true' or not environment.get('GITHUB_ENV'):
        raise ValueError('Functional UI provisioning requires GitHub Actions and its environment file.')
    prepare_components(environment)
    runtimes = json.loads(PROFILES.simctl('list', 'runtimes', 'available', '-j'))['runtimes']
    types = json.loads(PROFILES.simctl('list', 'devicetypes', '-j'))['devicetypes']
    devices = json.loads(PROFILES.simctl('list', 'devices', 'available', '-j'))['devices']
    choices = available_profiles(runtimes, types, devices, preferred_device=QUALIFIED_PROFILE['device'],
                                 sdk_version=environment.get('XCODE_VERSION', ''))
    if not choices:
        raise CapabilityUnavailable('No compatible installed iPhone runtime at iOS 26 or later.')
    profile = choices[0]
    runtime = next(item for item in runtimes if item['identifier'] == profile['runtime']
                   and item.get('buildversion', '') == profile['build'])
    PROFILES.warm_runtime_cache(runtime)
    with Path(environment['GITHUB_ENV']).open('a') as output:
        output.write(''.join(f'{key}={value}\n' for key, value in profile_environment(profile).items()))
        output.write('TRINKET_CI_ADAPTIVE=1\n')
        output.write('TRINKET_CI_SIMULATOR_AVAILABLE=true\n')
    record_coverage('simulator-selection', 'available', environment=environment, details=profile)
    print(f"Available CI simulator: {profile['device']}, iOS {profile['version']} ({profile['build']}).", flush=True)
    return runtime


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare',))
    parser.parse_args()
    try:
        prepare(dict(os.environ))
    except (CapabilityUnavailable, OSError, ValueError, subprocess.SubprocessError) as error:
        if path := os.environ.get('GITHUB_ENV'):
            with Path(path).open('a') as output:
                output.write('TRINKET_CI_SIMULATOR_AVAILABLE=false\nTRINKET_CI_ADAPTIVE=1\n')
        print(f'{UNAVAILABLE_MARKER} {error}', file=sys.stderr)
        raise SystemExit(78) from error
