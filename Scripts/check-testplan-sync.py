#!/usr/bin/env python3
"""Validate UI registration and emit ordered test-plan selections or CI filters."""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

from internal.cli import ROOT, read_json

REGISTRY = 'Scripts/config/ui-tests.tsv'


def registrations(root: Path = ROOT) -> list[dict]:
    rows, classes, keys = [], set(), set()
    for number, line in enumerate((root / REGISTRY).read_text().splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('|')
        if len(parts) != 3:
            raise ValueError(f'{REGISTRY}:{number}: expected suite|key|class')
        suite, key, name = parts
        if (suite not in {'Smoke', 'FullUI'} or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name)
                or (suite == 'Smoke' and not re.fullmatch(r'[A-Z][A-Z0-9_]*', key))
                or (suite == 'FullUI' and key)):
            raise ValueError(f'{REGISTRY}:{number}: invalid registration')
        if name in classes or (key and key in keys):
            raise ValueError(f'{REGISTRY}:{number}: duplicate class or routing key')
        classes.add(name)
        keys.add(key)
        rows.append(dict(suite=suite, key=key, name=name))
    if {row['suite'] for row in rows} != {'Smoke', 'FullUI'}:
        raise ValueError(f'{REGISTRY}: both Smoke and FullUI must be nonempty')
    return rows


def registration_failures(root: Path, rows: list[dict]) -> list[str]:
    failures = []
    declarations = {'Smoke': [], 'FullUI': []}
    for path in sorted((root / 'TrinketUITests').rglob('*.swift')):
        parts = path.relative_to(root).parts
        if any(part in {'Performance', 'Support'} for part in parts):
            continue
        suite = 'Smoke' if 'Smoke' in parts else 'FullUI'
        declarations[suite].extend(re.findall(r'^[ \t]*(?:final\s+)?class\s+(\w+)\s*:\s*\w+UITestCase', path.read_text(), re.M))
    for suite, declared in declarations.items():
        registered = {row['name'] for row in rows if row['suite'] == suite}
        if set(declared) != registered:
            failures.append(f'{suite} registry class mismatch: missing={sorted(set(declared) - registered)}, '
                            f'undeclared={sorted(registered - set(declared))}')
        duplicate = [name for name, count in Counter(declared).items() if count > 1]
        if duplicate:
            failures.append(f'{suite} duplicate class declarations: {sorted(duplicate)}')
    return failures


def plan_target(plan: dict) -> dict:
    targets = [target for target in plan['testTargets'] if target.get('target', {}).get('name') == 'TrinketUITests']
    if len(targets) != 1 or targets[0].get('automaticallyIncludesTests') is not False:
        raise ValueError('UI plan must explicitly select tests in exactly one TrinketUITests target')
    return targets[0]


def generate(root: Path, rows: list[dict]) -> None:
    failures = registration_failures(root, rows)
    if failures:
        raise ValueError('; '.join(failures))
    updates = []
    for suite in ('Smoke', 'FullUI'):
        path = root / f'{suite}.xctestplan'
        plan = read_json(path)
        selected = [row['name'] for row in rows if row['suite'] == suite]
        target = plan_target(plan)
        if target.get('selectedTests') == selected:
            continue
        target['selectedTests'] = selected
        updates.append((path, json.dumps(plan, indent=2) + '\n'))
    for path, content in updates:
        path.write_text(content)


def testplan_failures() -> list[str]:
    try:
        rows = registrations(ROOT)
        failures = registration_failures(ROOT, rows)
        for suite in ('Smoke', 'FullUI'):
            selections = plan_target(read_json(ROOT / f'{suite}.xctestplan')).get('selectedTests', [])
            expected = [row['name'] for row in rows if row['suite'] == suite]
            if selections != expected:
                failures.append(f'{suite}.xctestplan selectedTests must match {REGISTRY}; run ./Scripts/generate.sh')
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        build = re.search(r'^  build:\n(.*?)(?=^  [\w-]+:|\Z)', workflow, re.M | re.S)
        if not build or '--classes Smoke' not in build[1]:
            failures.append('.github/workflows/tests.yml build must compute registry-selected smoke targets')
        if not build or './Scripts/test.sh smoke --no-build' not in build[1] or \
                'steps.ui-matrices.outputs.smoke-targets' not in build[1]:
            failures.append('.github/workflows/tests.yml build must run registry-selected smoke on its build runner')
        full_ui = re.search(r'^  exhaustive-ui:\n(.*?)(?=^  [\w-]+:|\Z)', workflow, re.M | re.S)
        if not full_ui or '--classes FullUI' not in full_ui[1] or \
                './Scripts/test.sh ui --no-build ${{ steps.ui-targets.outputs.targets }}' not in full_ui[1] or \
                not build or '--classes FullUI' not in build[1] or \
                './Scripts/test.sh ui --no-build ${{ steps.ui-matrices.outputs.full-targets }}' not in build[1]:
            failures.append('.github/workflows/tests.yml exhaustive-ui must consume every registry-selected FullUI class')
        return failures
    except (OSError, ValueError, KeyError) as error:
        return [str(error)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--generate', action='store_true', help='update only UI test-plan selections')
    mode.add_argument('--classes', choices=('Smoke', 'FullUI'), help='emit class filters for a serial suite')
    parser.add_argument('--root', type=Path, default=ROOT, help='project root for generation')
    args = parser.parse_args()
    try:
        if args.generate or args.classes:
            rows = registrations(args.root)
            if args.generate:
                generate(args.root, rows)
            else:
                print(' '.join(row['name'] for row in rows if row['suite'] == args.classes))
            return 0
        failures = testplan_failures()
        if failures:
            print('Test plan sync checks failed:', file=sys.stderr)
            for failure in failures:
                print(f'- {failure}', file=sys.stderr)
            return 1
        print('Test plan sync passed.')
        return 0
    except (OSError, ValueError, KeyError) as error:
        print(f'UI registration failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
