#!/usr/bin/env python3
"""Validate the performance inventory and resolve exact scenario/group selections."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from internal.cli import ROOT, read_json


def test_measurements(source: str) -> dict[str, list[str]]:
    # Test methods end at the next method declaration; nested measurement
    # closures stay inside their owner. Interpolated category names retain
    # their literal prefix/suffix when matching inventory entries.
    source = re.sub(
        r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
        lambda token: token[0] if token[0].startswith('"') else '', source,
    )
    methods = list(re.finditer(r'\bfunc\s+(\w+)\s*\(', source))
    result = {}
    for index, method in enumerate(methods):
        end = methods[index + 1].start() if index + 1 < len(methods) else len(source)
        body = source[method.end():end]
        result[method[1]] = re.findall(
            r'(?:\bmeasured\s*\(|\bfinishMeasurement\s*\(|\brun\s*\(\s*scenario\s*:)\s*"((?:\\.|[^"\\])*)"',
            body,
        )
    return result


def matches_measurement(scenario: str, measurement: str) -> bool:
    parts = re.split(r'\\\([^)]*\)', measurement)
    return re.fullmatch('.+'.join(re.escape(part) for part in parts), scenario) is not None


def select(baseline: dict, selectors: list[str]) -> dict:
    inventory = baseline['coverage']
    if set(inventory) != set(baseline['scenarios']):
        raise ValueError('coverage inventory and baseline scenarios differ')
    plan = read_json(ROOT / 'BattlePerformance.xctestplan')
    classes = set(plan['testTargets'][0]['selectedTests'])
    measurements = {
        source.stem: test_measurements(source.read_text())
        for source in (ROOT / 'TrinketUITests/Performance').glob('*UITests.swift')
    }
    for scenario, entry in inventory.items():
        owner, method = entry['test'].split('/')
        methods = measurements.get(owner, {})
        if owner not in classes or method not in methods:
            raise ValueError(f'{scenario}: unregistered test {entry["test"]}')
        if not any(matches_measurement(scenario, value) for value in methods[method]):
            raise ValueError(f'{scenario}: missing measurement in {entry["test"]}')
    declared = {
        value for methods in measurements.values() for values in methods.values()
        for value in values if '\\(' not in value
    }
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
    baseline = read_json(ROOT / 'Performance/Baselines/simulator-60.json')
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
