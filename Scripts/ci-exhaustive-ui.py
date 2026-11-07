#!/usr/bin/env python3
"""Run every requested FullUI class once on the prepared functional runtime."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from internal.cli import load_sibling
from internal.ci_capabilities import available_ui_selectors, record_coverage

PROFILE = load_sibling('exhaustive_ui_profile', 'ci-ui-profile.py')
UI_RESULTS = load_sibling('exhaustive_ui_cases', 'ci_ui_retry.py')


def bounded_localizations(targets: list[str], environment: dict[str, str]) -> list[str]:
    suite = 'LocalizationUITests'
    if suite not in targets or environment.get('TRINKET_CI_FULL_LOCALIZATION') == '1':
        return targets
    cases = UI_RESULTS.expected_cases([suite])
    english = suite + '/testEnglishScreenshots'
    alternatives = sorted(case for case in cases if case != english)
    if english not in cases or not alternatives:
        raise ValueError('Cannot establish the localization portfolio for bounded selection.')
    selected = [english, alternatives[int(environment.get('GITHUB_RUN_NUMBER', '0')) % len(alternatives)]]
    record_coverage('localization-matrix', 'unavailable',
                    'Runner budget covers English and one rotating configuration; the remaining configurations are deferred.',
                    environment=environment, details={
                        'selected_selectors': selected,
                        'deferred_selectors': [case for case in cases if case not in selected],
                    })
    return [case for target in targets for case in (selected if target == suite else [target])]


def run(targets: list[str], environment: dict[str, str]) -> int:
    if environment.get('GITHUB_ACTIONS') != 'true':
        raise ValueError('Exhaustive UI routing is CI-owned; use an exact test.sh selector for local diagnostics.')
    registered = subprocess.check_output(
        [sys.executable, 'Scripts/check-testplan-sync.py', '--classes', 'FullUI'], text=True,
    ).split()
    if not targets or len(set(targets)) != len(targets) or any(target not in registered for target in targets):
        raise ValueError('Supply unique registered FullUI classes.')
    PROFILE.require_environment(environment)
    targets, deferred = available_ui_selectors(targets, {'build': environment.get('TRINKET_SIM_OS_BUILD')},
                                               UI_RESULTS.expected_cases)
    if deferred:
        record_coverage('StoreKit denial simulation', 'unavailable',
                        'The installed runtime lacks qualified denial-service behavior; ordinary purchase, approval, restore and refund checks remain selected.',
                        environment=environment, details={'deferred_selectors': deferred})
    targets = bounded_localizations(targets, environment)
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
