#!/usr/bin/env python3
"""Run every requested FullUI class once on the prepared functional runtime."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from internal.cli import load_sibling

PROFILE = load_sibling('exhaustive_ui_profile', 'ci-ui-profile.py')


def run(targets: list[str], environment: dict[str, str]) -> int:
    if environment.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Exhaustive UI routing is CI-owned; use an exact test.sh selector for local diagnostics.')
    registered = subprocess.check_output(
        [sys.executable, 'Scripts/check-testplan-sync.py', '--classes', 'FullUI'], text=True,
    ).split()
    if not targets or len(set(targets)) != len(targets) or any(target not in registered for target in targets):
        raise ValueError('Supply unique registered FullUI classes; no requested class may be dropped.')
    PROFILE.require_environment(environment)
    derived = environment.get('DERIVED_DATA_PATH') or str(Path('.DerivedData').resolve())
    results = environment.get('RESULTS_DIR') or str(Path(derived) / 'TestResults')
    test_environment = {**environment, 'TRINKET_ISOLATE': '1',
                        'DERIVED_DATA_PATH': derived, 'RESULTS_DIR': results}
    return subprocess.call([sys.executable, 'Scripts/ci_ui_retry.py', './Scripts/test.sh',
                            'ui', '--no-build', *targets], env=test_environment)


if __name__ == '__main__':
    try:
        raise SystemExit(run(sys.argv[1:], dict(os.environ)))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Exhaustive UI routing failed: {error}')
