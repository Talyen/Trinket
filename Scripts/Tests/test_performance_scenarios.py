from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('performance_scenarios', ROOT / 'Scripts/performance-scenarios.py')
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class PerformanceScenarioTests(unittest.TestCase):
    def setUp(self) -> None:
        self.baseline = json.loads((ROOT / 'Performance/Baselines/simulator-60.json').read_text())

    def test_full_selection_and_group_selection_keep_exact_coverage(self) -> None:
        full = module.select(self.baseline, [])
        self.assertEqual(set(full['scenarios']), set(full['coverage']))
        group = next(iter(full['coverage'].values()))['group']
        selected = module.select(self.baseline, [group])
        self.assertTrue(selected['scenarios'])
        self.assertTrue(all(entry['group'] == group for entry in selected['coverage'].values()))
        scenario = selected['scenarios'][0]
        one = module.select(self.baseline, [scenario])
        self.assertEqual(one['scenarios'], [scenario])
        self.assertEqual(one['testScenarios'], {one['coverage'][scenario]['test']: [scenario]})

    def test_removed_route_mapping_is_not_silent(self) -> None:
        broken = copy.deepcopy(self.baseline)
        contract = broken['routeContracts'][0]
        del contract['routes'][next(iter(contract['routes']))]
        with self.assertRaisesRegex(ValueError, 'navigation changed'):
            module.select(broken, [])

    def test_unknown_selection_and_unregistered_tests_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, 'unknown'):
            module.select(self.baseline, ['not-a-scenario'])
        broken = copy.deepcopy(self.baseline)
        first = next(iter(broken['coverage']))
        broken['coverage'][first]['test'] = 'MissingUITests/testMissing'
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            module.select(broken, [])
        del broken['coverage'][first]
        with self.assertRaisesRegex(ValueError, 'differ'):
            module.select(broken, [])
