#!/usr/bin/env python3
"""Validate the performance inventory and resolve exact scenario/group selections."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from internal.cli import ROOT


def select(baseline: dict, selectors: list[str]) -> dict:
    inventory = baseline['coverage']
    if set(inventory) != set(baseline['scenarios']):
        raise ValueError('coverage inventory and baseline scenarios differ')
    plan = json.loads((ROOT / 'BattlePerformance.xctestplan').read_text())
    classes = set(plan['testTargets'][0]['selectedTests'])
    for scenario, entry in inventory.items():
        owner, method = entry['test'].split('/')
        source = ROOT / 'TrinketUITests/Performance' / f'{owner}.swift'
        if owner not in classes or not source.exists() or f'func {method}(' not in source.read_text():
            raise ValueError(f'{scenario}: unregistered test {entry["test"]}')
    declared: set[str] = set()
    for source in (ROOT / 'TrinketUITests/Performance').glob('*UITests.swift'):
        declared.update(value for value in re.findall(r'(?:measured\(|run\(scenario: |finishMeasurement\()"([^"\\]+)"', source.read_text()))
    missing = declared - set(inventory)
    if missing:
        raise ValueError(f'measured scenarios missing from inventory: {sorted(missing)}')
    for contract in baseline.get('routeContracts', []):
        source = (ROOT / contract['source']).read_text()
        body = source.split(f"public enum {contract['enum']}:", 1)[1].split('\n}', 1)[0]
        cases = set(re.findall(r'^    case (\w+)', body, re.MULTILINE))
        if cases != set(contract['routes']):
            raise ValueError(f"{contract['enum']}: navigation changed; update performance coverage")
        for route, scenarios in contract['routes'].items():
            if not scenarios or not set(scenarios) <= set(inventory):
                raise ValueError(f'{route}: missing scenario coverage')
    selected: set[str] = set()
    for selector in selectors:
        matches = {s for s, entry in inventory.items() if s == selector or entry['group'] == selector}
        if not matches:
            raise ValueError(f'unknown scenario or group: {selector}')
        selected.update(matches)
    result = dict(baseline)
    result['scenarios'] = [s for s in baseline['scenarios'] if (not selectors and inventory[s]["group"] != "diagnostic") or s in selected]
    result['coverage'] = {s: inventory[s] for s in result['scenarios']}
    result['testScenarios'] = {}
    for scenario, entry in result['coverage'].items():
        result['testScenarios'].setdefault(entry['test'], []).append(scenario)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--select', action='append', default=[])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--list', action='store_true')
    args = parser.parse_args()
    baseline = json.loads((ROOT / 'Performance/Baselines/simulator-60.json').read_text())
    try:
        selected = select(baseline, args.select)
    except ValueError as error:
        parser.error(str(error))
    if args.list:
        for scenario, entry in (selected if args.select else baseline)['coverage'].items():
            print(f'{entry["group"]:12} {scenario}')
    if args.output:
        args.output.write_text(json.dumps(selected, indent=2) + '\n')
    if not args.list:
        for test in sorted(selected['testScenarios']):
            print(test)
        if selected.get("launchMetricTest") and (not args.select or "launch-animation" in selected["scenarios"]):
            print(selected["launchMetricTest"])


if __name__ == '__main__':
    main()
