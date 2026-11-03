#!/usr/bin/env python3
"""Run all requested FullUI classes, using the qualified runtime for StoreKit recovery."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from internal.cli import load_sibling

PROFILES = load_sibling('exhaustive_profiles', 'coverage_profiles.py')
QUALIFIED_PROFILE = load_sibling('exhaustive_deploy', 'deploy-verification.py').QUALIFIED_PROFILE
PURCHASE_CLASS = 'FullGamePurchaseUITests'


def run(targets: list[str], environment: dict[str, str]) -> int:
    if environment.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Exhaustive UI routing is CI-owned; use an exact test.sh selector for local diagnostics.')
    registered = subprocess.check_output(
        [sys.executable, 'Scripts/check-testplan-sync.py', '--classes', 'FullUI'], text=True,
    ).split()
    if not targets or len(set(targets)) != len(targets) or any(target not in registered for target in targets):
        raise ValueError('Supply unique registered FullUI classes; no requested class may be dropped.')
    ordinary = [target for target in targets if target != PURCHASE_CLASS]

    def execute(selected, env):
        return subprocess.call([sys.executable, 'Scripts/ci_ui_retry.py', './Scripts/test.sh',
                                'ui', '--no-build', *selected], env=env)

    derived = environment.get('DERIVED_DATA_PATH') or str(Path('.DerivedData').resolve())
    results = environment.get('RESULTS_DIR') or str(Path(derived) / 'TestResults')
    test_environment = {**environment, 'TRINKET_ISOLATE': '1',
                        'DERIVED_DATA_PATH': derived, 'RESULTS_DIR': results}
    status = execute(ordinary, test_environment) if ordinary else 0
    if PURCHASE_CLASS not in targets:
        return status
    qualified = QUALIFIED_PROFILE
    purchase_environment = {**test_environment, 'TRINKET_SIM_DEVICE_TYPE': qualified['device'],
                            'TRINKET_SIM_OS_VERSION': qualified['version'],
                            'TRINKET_SIM_OS_MAJOR': qualified['version'].split('.')[0]}
    try:
        runtime = PROFILES.prepare_runtime(qualified['device'], int(qualified['version'].split('.')[0]), qualified['version'])
        if runtime.get('identifier') != qualified['runtime'] or runtime.get('buildversion') != qualified['build']:
            raise ValueError(f'StoreKit recovery requires {qualified}; found {runtime}')
        message = (f"FullUI purchase recovery: {qualified['device']}, iOS {runtime['version']} "
                   f"({runtime['buildversion']}); every {PURCHASE_CLASS} case remains required.")
        print(message, flush=True)
        if summary := environment.get('GITHUB_STEP_SUMMARY'):
            with Path(summary).open('a') as output:
                output.write('\n' + message + '\n')
        purchase_status = execute([PURCHASE_CLASS], purchase_environment)
        return status or purchase_status
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'::error::StoreKit recovery runtime prerequisite failed: {error}', flush=True)
        return status or 1


if __name__ == '__main__':
    try:
        raise SystemExit(run(sys.argv[1:], dict(os.environ)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Exhaustive UI routing failed: {error}')
