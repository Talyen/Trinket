#!/usr/bin/env python3
"""Validate UI registration and emit ordered test-plan selections or CI filters."""
from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from collections import Counter
from pathlib import Path

from internal.cli import ROOT, read_json
from internal.ui_registration import REGISTRY, SUITES, registrations


def swift_code(source: str) -> str:
    """Mask comments and strings while retaining source positions and line breaks."""
    masked = list(source)
    length = len(source)
    string_pattern = re.compile(r'(#*)("""|")')

    def string_start(index: int) -> tuple[str, str] | None:
        match = string_pattern.match(source, index) if source[index] in '#"' else None
        return (match[1], match[2]) if match else None

    def comment_end(index: int) -> int:
        if source.startswith('//', index):
            end = source.find('\n', index)
            return length if end < 0 else end
        depth = 1
        index += 2
        while index < length and depth:
            if source.startswith('/*', index):
                depth += 1
                index += 2
            elif source.startswith('*/', index):
                depth -= 1
                index += 2
            else:
                index += 1
        if depth:
            raise ValueError('unterminated Swift block comment')
        return index

    def interpolation_end(index: int) -> int:
        depth = 1
        while index < length:
            if source.startswith(('//', '/*'), index):
                index = comment_end(index)
            elif string_start(index):
                index = string_end(index)
            elif source[index] == '(':
                depth += 1
                index += 1
            elif source[index] == ')':
                depth -= 1
                index += 1
                if depth == 0:
                    return index
            else:
                index += 1
        raise ValueError('unterminated Swift string interpolation')

    def string_end(index: int) -> int:
        hashes, quote = string_start(index)
        index += len(hashes) + len(quote)
        closing = quote + hashes
        escape = '\\' + hashes
        while index < length:
            if source.startswith(closing, index):
                return index + len(closing)
            if source.startswith(escape, index):
                index += len(escape)
                if index < length and source[index] == '(':
                    index = interpolation_end(index + 1)
                else:
                    index += 1
            else:
                index += 1
        raise ValueError('unterminated Swift string')

    index = 0
    while index < length:
        start = index
        if source.startswith(('//', '/*'), index):
            index = comment_end(index)
        elif string_start(index):
            index = string_end(index)
        else:
            index += 1
            continue
        for position in range(start, index):
            if source[position] not in '\r\n':
                masked[position] = ' '
    return ''.join(masked)


def registration_failures(root: Path, rows: list[dict]) -> list[str]:
    failures = []
    declarations = {suite: [] for suite in SUITES if any(row['suite'] == suite for row in rows)}
    classes = []
    parents = {}
    pattern = re.compile(r'\bclass\s+(\w+)\s*:\s*([\w.]+)')
    for path in sorted((root / 'TrinketUITests').rglob('*.swift')):
        parts = path.relative_to(root).parts
        suite = next((name for name in ('Smoke', 'Profiles', 'Soak') if name in parts), 'FullUI')
        eligible = not any(part in {'Performance', 'Support'} for part in parts)
        try:
            source = swift_code(path.read_text())
        except ValueError as error:
            raise ValueError(f'{path}: {error}') from error
        for name, parent in pattern.findall(source):
            parent = parent.rsplit('.', 1)[-1]
            classes.append((name, parent, suite, eligible))
            parents.setdefault(name, set()).add(parent)

    def is_test_case(name: str, seen: set[str]) -> bool:
        if name == 'XCTestCase' or name.endswith('UITestCase'):
            return True
        if name in seen:
            return False
        return any(is_test_case(parent, seen | {name}) for parent in parents.get(name, ()))

    for name, parent, suite, eligible in classes:
        if eligible and is_test_case(parent, set()):
            declarations.setdefault(suite, []).append(name)
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
    candidates = plan.get('testTargets') if isinstance(plan, dict) else None
    if not isinstance(candidates, list) or any(
        not isinstance(target, dict) or not isinstance(target.get('target'), dict) for target in candidates
    ):
        raise ValueError('UI plan must contain a testTargets array of target objects')
    targets = [target for target in candidates if target['target'].get('name') == 'TrinketUITests']
    if len(targets) != 1 or targets[0].get('automaticallyIncludesTests') is not False:
        raise ValueError('UI plan must explicitly select tests in exactly one TrinketUITests target')
    if targets[0].get('enabled', True) is not True or targets[0].get('skippedTests'):
        raise ValueError('UI plan must enable every selected TrinketUITests test without exclusions')
    return targets[0]


def generate(root: Path, rows: list[dict]) -> None:
    failures = registration_failures(root, rows)
    if failures:
        raise ValueError('; '.join(failures))
    updates = []
    for suite in dict.fromkeys(row['suite'] for row in rows):
        path = root / f'{suite}.xctestplan'
        plan = read_json(path) if path.exists() else copy.deepcopy(read_json(root / 'FullUI.xctestplan'))
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
        for suite in dict.fromkeys(row['suite'] for row in rows):
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
    mode.add_argument('--classes', choices=SUITES, help='emit class filters for a serial suite')
    parser.add_argument('--root', type=Path, default=ROOT, help='project root for generation')
    args = parser.parse_args()
    try:
        if args.generate or args.classes:
            rows = registrations(args.root)
            if args.generate:
                generate(args.root, rows)
            else:
                failures = registration_failures(args.root, rows)
                if failures:
                    raise ValueError('; '.join(failures))
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
