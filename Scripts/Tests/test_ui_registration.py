"""UI registration controls both Xcode selections and CI shard membership."""
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/check-testplan-sync.py',
    'Scripts/config/ui-tests.tsv',
    'Scripts/lib/smoke-classes.sh',
)


import copy
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import ROOT, load_script

REGISTRY = load_script('ui_registration', 'check-testplan-sync.py')


class UIRegistrationTests(unittest.TestCase):
    def test_shipping_shards_and_shell_routing_are_preserved(self):
        rows = REGISTRY.registrations()
        self.assertEqual(REGISTRY.matrix(rows, 'Smoke'), {'include': [
            {'name': 'Shell', 'target': 'SmokeShellTests StarterOnboardingSmokeTests FullGamePurchaseSmokeTests'},
            {'name': 'Play', 'target': 'SmokeBattleTests SmokeShopTests'},
        ]})
        self.assertEqual(REGISTRY.matrix(rows, 'FullUI'), {'include': [
            {'name': 'Battle', 'target': 'BattleFlowUITests'},
            {'name': 'Collection', 'target': 'TabNavigationUITests HeroDetailAbilityPickerUITests'},
            {'name': 'Homestead', 'target': 'HomesteadNodeDetailUITests'},
            {'name': 'Play', 'target': 'PlayMapUITests PlayModeNavigationUITests MysteryRecruitUITests'},
        ]})
        output = subprocess.check_output(['bash', '-c', 'source Scripts/lib/smoke-classes.sh; env'], cwd=ROOT, text=True)
        for row in rows:
            if row['suite'] == 'Smoke':
                self.assertIn(f"TRINKET_SMOKE_CLASS_{row['key']}={row['name']}", output)
        self.assertEqual(REGISTRY.testplan_failures(), [])

    def test_generation_preserves_settings_and_rejects_missing_or_duplicate_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            registry = root / REGISTRY.REGISTRY
            registry.parent.mkdir(parents=True)
            original = 'Smoke|SHELL|SmokeFixture|Shell|0|0\nFullUI||FullFixture|All|0|0\n'
            registry.write_text(original)
            for suite, name, folder in [('Smoke', 'SmokeFixture', 'Smoke'), ('FullUI', 'FullFixture', 'Flows')]:
                source = root / 'TrinketUITests' / folder / 'Fixture.swift'
                source.parent.mkdir(parents=True)
                source.write_text(f'class {name}: TrinketUITestCase {{}}')
                plan = {'configurations': [{'id': 'keep-me'}], 'defaultOptions': {'testExecutionOrdering': 'alphabetical'},
                        'testTargets': [{'automaticallyIncludesTests': False, 'selectedTests': ['Old'],
                                         'target': {'name': 'TrinketUITests', 'identifier': 'preserve-id'}}]}
                (root / f'{suite}.xctestplan').write_text(json.dumps(plan))
            rows = REGISTRY.registrations(root)
            REGISTRY.generate(root, rows)
            before = [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')]
            for suite, name in [('Smoke', 'SmokeFixture'), ('FullUI', 'FullFixture')]:
                expected = copy.deepcopy(plan)
                expected['testTargets'][0]['selectedTests'] = [name]
                self.assertEqual(json.loads((root / f'{suite}.xctestplan').read_text()), expected)
            REGISTRY.generate(root, rows)
            self.assertEqual(before, [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')])
            registry.write_text(original + 'FullUI||FullFixture|Other|1|0\n')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                REGISTRY.registrations(root)
            registry.write_text(original.replace('FullFixture', 'Absent'))
            with self.assertRaisesRegex(ValueError, 'undeclared'):
                REGISTRY.generate(root, REGISTRY.registrations(root))
            self.assertEqual(before, [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')])

    def test_workflow_must_consume_registry_matrix(self):
        read = Path.read_text
        workflow = ROOT / '.github/workflows/tests.yml'
        original = workflow.read_text()
        def changed(path, *args, **kwargs):
            return original.replace('fromJSON(needs.build.outputs.smoke-matrix)', 'fromJSON(needs.build.outputs.missing)') if path == workflow else read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', changed):
            self.assertTrue(any('smoke must consume' in error for error in REGISTRY.testplan_failures()))
