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
    def test_registered_classes_reach_plans_filters_and_local_routing(self):
        rows = REGISTRY.registrations()
        for suite in ('Smoke', 'FullUI'):
            expected = [row['name'] for row in rows if row['suite'] == suite]
            filters = subprocess.check_output(
                ['python3', 'Scripts/check-testplan-sync.py', '--classes', suite], cwd=ROOT, text=True,
            ).split()
            self.assertEqual(filters, expected)
            plan = json.loads((ROOT / f'{suite}.xctestplan').read_text())
            self.assertEqual(REGISTRY.plan_target(plan)['selectedTests'], expected)
            matrix_classes = [name for shard in REGISTRY.matrix(rows, suite)['include'] for name in shard['target'].split()]
            self.assertCountEqual(matrix_classes, expected)
        output = subprocess.check_output(['bash', '-c', 'source Scripts/lib/smoke-classes.sh; env'], cwd=ROOT, text=True)
        for row in rows:
            if row['suite'] == 'Smoke':
                self.assertIn(f"TRINKET_SMOKE_CLASS_{row['key']}={row['name']}", output)
        self.assertEqual(REGISTRY.testplan_failures(), [])

    def test_matrix_preserves_group_and_class_order_from_input(self):
        rows = [
            dict(suite='FullUI', name='Later', shard='Play', rank=1, order=1),
            dict(suite='FullUI', name='First', shard='Shell', rank=0, order=0),
            dict(suite='FullUI', name='Earlier', shard='Play', rank=1, order=0),
        ]
        self.assertEqual(REGISTRY.matrix(rows, 'FullUI'), {'include': [
            {'name': 'Shell', 'target': 'First'}, {'name': 'Play', 'target': 'Earlier Later'},
        ]})

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
                base = 'FullGameStoreKitUITestCase' if suite == 'FullUI' else 'TrinketUITestCase'
                source.write_text(f'// class {name}: {base} {{}}\nclass {name}: {base} {{}}')
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

    def test_workflow_rejects_smoke_that_bypasses_registry_filters(self):
        read = Path.read_text
        workflow = ROOT / '.github/workflows/tests.yml'
        original = workflow.read_text()
        def changed(path, *args, **kwargs):
            return original.replace('--classes Smoke', '--classes Missing') if path == workflow else read(path, *args, **kwargs)
        with patch.object(Path, 'read_text', changed):
            self.assertTrue(any('registry-selected smoke' in error for error in REGISTRY.testplan_failures()))
