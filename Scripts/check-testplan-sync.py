#!/usr/bin/env python3
"""Validate UI registration, generate plan selections, or emit CI matrices."""
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
    shard_orders, shard_names, test_orders = {}, {}, set()
    for number, line in enumerate((root / REGISTRY).read_text().splitlines(), 1):
        if not line.strip() or line.startswith('#'):
            continue
        parts = line.split('|')
        if len(parts) != 6:
            raise ValueError(f'{REGISTRY}:{number}: expected suite|key|class|shard|shard_order|test_order')
        suite, key, name, shard, rank, order = parts
        if (suite not in {'Smoke', 'FullUI'} or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name)
                or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', shard)
                or (suite == 'Smoke' and not re.fullmatch(r'[A-Z][A-Z0-9_]*', key))
                or (suite == 'FullUI' and key) or not rank.isdigit() or not order.isdigit()):
            raise ValueError(f'{REGISTRY}:{number}: invalid registration')
        rank, order = int(rank), int(order)
        if name in classes or (key and key in keys):
            raise ValueError(f'{REGISTRY}:{number}: duplicate class or routing key')
        if (shard_orders.get((suite, shard), rank) != rank
                or shard_names.get((suite, rank), shard) != shard
                or (suite, shard, order) in test_orders):
            raise ValueError(f'{REGISTRY}:{number}: conflicting shard or test order')
        classes.add(name)
        keys.add(key)
        shard_orders[suite, shard] = rank
        shard_names[suite, rank] = shard
        test_orders.add((suite, shard, order))
        rows.append(dict(suite=suite, key=key, name=name, shard=shard, rank=rank, order=order))
    if {row['suite'] for row in rows} != {'Smoke', 'FullUI'}:
        raise ValueError(f'{REGISTRY}: both Smoke and FullUI must be nonempty')
    return rows


def matrix(rows: list[dict], suite: str) -> dict:
    shards = {}
    for row in sorted((row for row in rows if row['suite'] == suite), key=lambda row: (row['rank'], row['order'])):
        shards.setdefault(row['shard'], []).append(row['name'])
    return {'include': [dict(name=name, target=' '.join(classes)) for name, classes in shards.items()]}


def registration_failures(root: Path, rows: list[dict]) -> list[str]:
    failures = []
    for suite in ('Smoke', 'FullUI'):
        declared = []
        for path in sorted((root / 'TrinketUITests').rglob('*.swift')):
            parts = path.relative_to(root).parts
            if any(part in {'Performance', 'Support'} for part in parts) or ('Smoke' in parts) != (suite == 'Smoke'):
                continue
            declared += re.findall(r'(?:final\s+)?class\s+(\w+)\s*:\s*(?:SeededSmokeUITestCase|TrinketUITestCase)', path.read_text())
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
        # These expressions consume the same registry through the build job.
        for job, output in [('smoke', 'smoke-matrix'), ('exhaustive-ui', 'full-ui-matrix')]:
            section = re.search(rf'^  {job}:\n(.*?)(?=^  [\w-]+:|\Z)', workflow, re.M | re.S)
            expression = '${{ fromJSON(needs.build.outputs.' + output + ') }}'
            if not section or 'matrix: ' + expression not in section[1]:
                failures.append(f'.github/workflows/tests.yml {job} must consume registry matrix')
        return failures
    except (OSError, ValueError, KeyError) as error:
        return [str(error)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--generate', action='store_true', help='update only UI test-plan selections')
    mode.add_argument('--matrix', choices=('Smoke', 'FullUI'), help='emit one compact CI matrix')
    parser.add_argument('--root', type=Path, default=ROOT, help='project root for generation')
    args = parser.parse_args()
    try:
        if args.generate or args.matrix:
            rows = registrations(args.root)
            if args.generate:
                generate(args.root, rows)
            else:
                print(json.dumps(matrix(rows, args.matrix), separators=(',', ':')))
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
