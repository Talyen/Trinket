"""UI registration controls ordered Xcode selections and serial CI filters."""
from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import ROOT, load_script, write_json
from internal.change_routing import classify

REGISTRY = load_script('ui_registration', 'check-testplan-sync.py')


class UIRegistrationTests(unittest.TestCase):
    def test_discovery_handles_generic_qualified_and_escaped_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            support = root / 'TrinketUITests' / 'Support'
            support.mkdir(parents=True)
            (support / 'Bases.swift').write_text('''
                class GenericBase<Value: Collection>: XCTest . XCTestCase {}
                class PretendUITestCase: NSObject {}
                class EmptyUITestCase {}
            ''')
            source = root / 'TrinketUITests' / 'Cases.swift'
            source.write_text('''
                class ViaGeneric: GenericBase<[String]> {}
                class `EscapedTests`: XCTest . `XCTestCase` {}
                class NotTests: PretendUITestCase {}
                class NeitherTests: EmptyUITestCase {}
            ''')
            rows = [{'suite': 'FullUI', 'name': name} for name in ('ViaGeneric', 'EscapedTests')]
            self.assertEqual(REGISTRY.registration_failures(root, rows), [])
            for row in rows:
                with self.subTest(missing=row['name']):
                    failures = REGISTRY.registration_failures(root, [other for other in rows if other != row])
                    self.assertTrue(any(row['name'] in failure for failure in failures))

    def test_discovery_ignores_extended_regex_literals(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'TrinketUITests' / 'Cases.swift'
            source.parent.mkdir()
            source.write_text('''
                let regex = #/ class Phantom: XCTestCase {} " // /#
                let other = ##/ class AnotherPhantom: XCTestCase {} /##
                class RealTests: XCTestCase {}
            ''')
            self.assertEqual(REGISTRY.registration_failures(root, [{'suite': 'FullUI', 'name': 'RealTests'}]), [])
            source.write_text('let broken = #/unfinished')
            with self.assertRaisesRegex(ValueError, 'unterminated Swift extended regex'):
                REGISTRY.registration_failures(root, [])

    def test_discovery_handles_swift_declarations_and_ignores_non_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / 'TrinketUITests'
            (tests / 'Support').mkdir(parents=True)
            (tests / 'Flows').mkdir()
            (tests / 'Support' / 'Base.swift').write_text(
                'class CustomBase: TrinketUITestCase {}\n'
            )
            source = tests / 'Flows' / 'Cases.swift'
            source.write_text('''
                class DirectTests: XCTest.XCTestCase {}
                final class IndirectTests: CustomBase {}
                @MainActor public final class AttributedTests:
                    TrinketUITestCase {}
                class NotATest: TrinketUITestCaseHelper {}
                /* class BlockCommentTests: TrinketUITestCase {}
                   /* class NestedCommentTests: XCTestCase {} */
                */
                let sample = #"""
                class RawStringTests: TrinketUITestCase {}
                """#
                let interpolated = "\\(example(\"class StringTests: XCTestCase {}\"))"
            ''')
            rows = [{'suite': 'FullUI', 'name': name} for name in
                    ('DirectTests', 'IndirectTests', 'AttributedTests')]
            self.assertEqual(REGISTRY.registration_failures(root, rows), [])
            for row in rows:
                with self.subTest(missing=row['name']):
                    failures = REGISTRY.registration_failures(root, [other for other in rows if other != row])
                    self.assertTrue(any(f"missing=['{row['name']}']" in failure for failure in failures))

    def test_discovery_rejects_unterminated_swift_comments_and_strings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'TrinketUITests' / 'Fixture.swift'
            source.parent.mkdir()
            for text in ('/* unfinished', 'let sample = #"unfinished'):
                source.write_text(text)
                with self.subTest(text=text), self.assertRaisesRegex(ValueError, 'unterminated Swift'):
                    REGISTRY.registration_failures(root, [])

    def test_registered_classes_reach_plans_filters_and_local_routing(self):
        rows = REGISTRY.registrations()
        for suite in REGISTRY.SUITES:
            expected = [row['name'] for row in rows if row['suite'] == suite]
            filters = subprocess.check_output(
                ['python3', 'Scripts/check-testplan-sync.py', '--classes', suite], cwd=ROOT, text=True,
            ).split()
            self.assertEqual(filters, expected)
            plan = json.loads((ROOT / f'{suite}.xctestplan').read_text())
            self.assertEqual(REGISTRY.plan_target(plan)['selectedTests'], expected)
        smoke = {row['key']: row['name'] for row in rows if row['suite'] == 'Smoke'}
        for path, key in (
            ('Trinket/Features/Play/Shop/Probe.swift', 'SHOP'),
            ('Packages/TrinketBattleFeature/Sources/TrinketBattleFeature/Probe.swift', 'BATTLE'),
            ('Trinket/Features/Collection/Probe.swift', 'SHELL'),
            ('Trinket/Features/Onboarding/Probe.swift', 'SHELL'),
            ('TrinketUITests/Smoke/SmokeShellTests.swift', 'SHELL'),
        ):
            self.assertEqual(classify([path]).smoke_targets, [smoke[key]])
        self.assertEqual(REGISTRY.testplan_failures(), [])

    def test_generation_preserves_settings_and_rejects_missing_or_duplicate_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            registry = root / REGISTRY.REGISTRY
            registry.parent.mkdir(parents=True)
            original = 'Smoke|SHELL|SmokeFixture\nFullUI||FullFixture\n'
            registry.write_text(original)
            for suite, name, folder in [('Smoke', 'SmokeFixture', 'Smoke'), ('FullUI', 'FullFixture', 'Flows')]:
                source = root / 'TrinketUITests' / folder / 'Fixture.swift'
                source.parent.mkdir(parents=True)
                base = 'FullGameStoreKitUITestCase' if suite == 'FullUI' else 'TrinketUITestCase'
                source.write_text(f'// class {name}: {base} {{}}\nclass {name}: {base} {{}}')
                plan = {'configurations': [{'id': 'keep-me'}], 'defaultOptions': {'testExecutionOrdering': 'alphabetical'},
                        'testTargets': [{'automaticallyIncludesTests': False, 'selectedTests': ['Old'],
                                         'target': {'name': 'TrinketUITests', 'identifier': 'preserve-id'}}]}
                write_json(root / f'{suite}.xctestplan', plan)
            rows = REGISTRY.registrations(root)
            REGISTRY.generate(root, rows)
            before = [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')]
            for suite, name in [('Smoke', 'SmokeFixture'), ('FullUI', 'FullFixture')]:
                expected = copy.deepcopy(plan)
                expected['testTargets'][0]['selectedTests'] = [name]
                self.assertEqual(json.loads((root / f'{suite}.xctestplan').read_text()), expected)
            REGISTRY.generate(root, rows)
            self.assertEqual(before, [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')])
            smoke = root / 'Smoke.xctestplan'
            for exclusion in ({'enabled': False}, {'skippedTests': ['SmokeFixture']}):
                rejected = json.loads(before[0])
                rejected['testTargets'][0].update(exclusion)
                write_json(smoke, rejected)
                with self.subTest(exclusion=exclusion), self.assertRaisesRegex(ValueError, 'exclusions'):
                    REGISTRY.generate(root, rows)
                self.assertEqual(json.loads(smoke.read_text()), rejected)
                self.assertEqual((root / 'FullUI.xctestplan').read_bytes(), before[1])
            smoke.write_bytes(before[0])
            registry.write_text(original + 'FullUI||FullFixture\n')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                REGISTRY.registrations(root)
            registry.write_text(original.replace('FullFixture', 'Absent'))
            with self.assertRaisesRegex(ValueError, 'undeclared'):
                REGISTRY.generate(root, REGISTRY.registrations(root))
            self.assertEqual(before, [(root / f'{suite}.xctestplan').read_bytes() for suite in ('Smoke', 'FullUI')])

    def test_workflow_rejects_smoke_and_full_ui_that_bypass_registry_filters(self):
        read = Path.read_text
        workflow = ROOT / '.github/workflows/tests.yml'
        original = workflow.read_text()
        for before, after, diagnostic in (
            ('--classes Smoke', '--classes Missing', 'registry-selected smoke'),
            ('steps.ui-matrices.outputs.smoke-targets', 'steps.unrelated.outputs.targets', 'registry-selected smoke'),
            ('--classes FullUI', '--classes Smoke', 'registry-selected FullUI'),
            ('steps.ui-matrices.outputs.full-targets', 'steps.ui-matrices.outputs.smoke-targets', 'registry-selected FullUI'),
            ('steps.ui-targets.outputs.targets', 'steps.unrelated.outputs.targets', 'registry-selected FullUI'),
        ):
            with self.subTest(bypass=before):
                def changed(path, *args, **kwargs):
                    return original.replace(before, after) if path == workflow else read(path, *args, **kwargs)
                with patch.object(Path, 'read_text', changed):
                    self.assertTrue(any(diagnostic in error for error in REGISTRY.testplan_failures()))
