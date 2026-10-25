"""Bounded real-Git regressions for automatic sparse/CoW worktree creation."""
import unittest
from script_test_support import ROOT, ScriptRegressionTestCase, run_captured


class WorktreeStorageTests(ScriptRegressionTestCase):
    def test_default_storage_and_git_safety(self):
        result = run_captured(['node', str(ROOT / 'Scripts/Tests/worktree-storage-check.mjs'),
                               str(ROOT / 'Scripts/lib/worktree-storage.mjs')], timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS:', result.stdout)


if __name__ == '__main__':
    unittest.main()
