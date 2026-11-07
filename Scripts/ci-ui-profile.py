#!/usr/bin/env python3
"""Prepare the release-qualified functional UI baseline on the existing CI runner."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess

from internal.cli import load_sibling
from internal.ci_simulator_services import prepare_components

PROFILES = load_sibling('qualified_ui_profiles', 'coverage_profiles.py')
QUALIFIED_PROFILE = dict(device='com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro',
                         runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-2', version='26.2', build='23C54')


def profile_environment():
    return dict(TRINKET_SIM_DEVICE_TYPE=QUALIFIED_PROFILE['device'],
                TRINKET_SIM_OS_MAJOR=QUALIFIED_PROFILE['version'].split('.')[0],
                TRINKET_SIM_OS_VERSION=QUALIFIED_PROFILE['version'],
                TRINKET_SIM_OS_BUILD=QUALIFIED_PROFILE['build'],
                TEST_RUNNER_TRINKET_EXPECTED_OS_BUILD=QUALIFIED_PROFILE['build'])


def require_environment(environment):
    if any(environment.get(key) != value for key, value in profile_environment().items()):
        raise ValueError('Functional UI requires the prepared release-qualified profile; run ci-ui-profile.py prepare first.')


def prepare(environment):
    if environment.get('GITHUB_ACTIONS') != 'true' or not environment.get('GITHUB_ENV'):
        raise ValueError('Functional UI provisioning requires GitHub Actions and its environment file.')
    prepare_components(environment)
    profile = QUALIFIED_PROFILE
    runtime = PROFILES.prepare_runtime(profile['device'], int(profile['version'].split('.')[0]),
                                      profile['version'], build=profile['build'], download_timeout=600)
    if runtime.get('identifier') != profile['runtime'] or runtime.get('buildversion') != profile['build']:
        raise ValueError(f'Functional UI requires {profile}; found {runtime}')
    PROFILES.warm_runtime_cache(runtime)
    with Path(environment['GITHUB_ENV']).open('a') as output:
        output.write(''.join(f'{key}={value}\n' for key, value in profile_environment().items()))
    print(f"Functional UI: {profile['device']}, iOS {profile['version']} ({profile['build']}).", flush=True)
    return runtime


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare',))
    parser.parse_args()
    try:
        prepare(dict(os.environ))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'[coverage prerequisite] Functional UI preparation failed: {error}')
