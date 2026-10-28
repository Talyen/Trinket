"""Purchase CI must run every recovery case on the qualified runtime."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

from script_test_support import load_script

ROOT = Path(__file__).resolve().parents[2]
VERIFY = load_script('verify_purchase_ui', 'verify-purchase-ui.py')
REPORT = load_script('purchase_exhaustive_report', 'report-exhaustive-ci.py')


class PurchaseRoutingTests(unittest.TestCase):
    def test_class_partition_is_complete_and_fails_closed(self):
        script = str(ROOT / 'Scripts/check-testplan-sync.py')
        def classes(*extra):
            return subprocess.run([sys.executable, script, '--classes', 'FullUI', *extra],
                                  cwd=ROOT, text=True, capture_output=True)
        all_classes = classes().stdout.split()
        other = classes('--exclude-class', 'FullGamePurchaseUITests')
        self.assertEqual(other.returncode, 0, other.stderr)
        self.assertEqual(set(other.stdout.split()) | {'FullGamePurchaseUITests'}, set(all_classes))
        self.assertNotIn('FullGamePurchaseUITests', other.stdout.split())
        self.assertNotEqual(classes('--exclude-class', 'UnknownClass').returncode, 0)

    def test_fresh_full_class_requires_exact_revision_and_profile(self):
        calls = []
        class FakeVerification:
            def __init__(self, state, identity, reusable):
                self.reusable = reusable
            def ui_batch(self, mode, selectors):
                calls.append((self.reusable, mode, selectors))
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_SHA': 'abc'}
        identity = {'commit': 'abc'}
        with patch.dict(os.environ, env, clear=True), \
                patch.object(VERIFY.DEPLOY, 'capture', return_value='abc'), \
                patch.object(VERIFY.DEPLOY, 'profile', return_value=VERIFY.DEPLOY.QUALIFIED_PROFILE), \
                patch.object(VERIFY.DEPLOY.BUILD, 'identity', return_value=identity), \
                patch.object(VERIFY.DEPLOY, 'Verification', FakeVerification):
            VERIFY.main()
            self.assertEqual(calls, [(False, 'ui', ['FullGamePurchaseUITests'])])
            os.environ['GITHUB_SHA'] = 'wrong'
            with self.assertRaisesRegex(ValueError, 'exact workflow revision'):
                VERIFY.main()
            os.environ['GITHUB_SHA'] = 'abc'
            with patch.object(VERIFY.DEPLOY, 'profile', return_value={'build': 'wrong'}):
                with self.assertRaisesRegex(ValueError, 'requires'):
                    VERIFY.main()

    def test_aggregate_requires_both_unique_successful_shards(self):
        def job(name, conclusion):
            return {'name': 'tests / Exhaustive UI (' + name + ')', 'conclusion': conclusion,
                    'status': 'completed', 'html_url': 'https://example.invalid'}
        required = ('Exhaustive UI (All)', 'Exhaustive UI (Purchases 26.2)')
        for jobs, passed in [([job('All', 'success'), job('Purchases 26.2', 'success')], True),
                             ([job('All', 'success')], False),
                             ([job('All', 'success'), job('Purchases 26.2', 'failure')], False),
                             ([job('All', 'success'), job('Purchases 26.2', 'skipped')], False),
                             ([job('All', 'success'), job('Purchases 26.2', 'success'), job('Purchases 26.2', 'success')], False)]:
            summary, warnings = REPORT.report([{'jobs': jobs}], required)
            self.assertEqual('Exhaustive UI: passed' in summary, passed)
            self.assertEqual(bool(warnings) or '| skipped |' in summary, not passed)

    def test_workflow_routes_both_paths_and_requires_purchase_job(self):
        workflow = (ROOT / '.github/workflows/tests.yml').read_text()
        self.assertEqual(workflow.count('--classes FullUI --exclude-class FullGamePurchaseUITests'), 2)
        self.assertIn('needs: [changes, exhaustive-ui, exhaustive-purchases]', workflow)
        self.assertIn('--required-shard "Exhaustive UI (Purchases 26.2)"', workflow)
        self.assertIn('command: python3 Scripts/verify-purchase-ui.py', workflow)
        self.assertIn("item.get('buildversion') == '23C54'", workflow)


if __name__ == '__main__':
    unittest.main()
