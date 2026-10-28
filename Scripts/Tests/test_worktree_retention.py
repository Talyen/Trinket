"""Cross-checkout cache maintenance never widens the existing retention scope."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from internal import worktree_retention


class WorktreeRetentionTests(unittest.TestCase):
    def test_only_registered_unlocked_task_checkouts_are_scanned(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            good = root / '.worktrees/good'
            locked = root / '.worktrees/locked'
            for path in (good, locked):
                path.mkdir(parents=True)
                (path / '.git').write_text('gitdir: /somewhere')
            listing = (f'worktree {root}\0HEAD a\0\0worktree {good}\0HEAD b\0\0'
                       f'worktree {locked}\0HEAD c\0locked active\0\0worktree /outside\0HEAD d\0')
            result = subprocess.CompletedProcess([], 0, listing, '')
            with mock.patch.object(worktree_retention.subprocess, 'run', return_value=result), \
                 mock.patch.object(worktree_retention.retention, 'cleanup', return_value=(1, 100)) as clean:
                self.assertEqual(worktree_retention.cleanup(root, apply=True, products=True), (1, 100))
                clean.assert_called_once_with(good, apply=True, intermediates_only=True, products=True)

    def test_changed_registration_is_not_cleaned(self):
        root = Path('/fixture')
        with mock.patch.object(worktree_retention, 'task_worktrees', side_effect=[[root / '.worktrees/task'], []]), \
             mock.patch.object(worktree_retention.retention, 'cleanup') as clean:
            self.assertEqual(worktree_retention.cleanup(root, apply=True, products=True), (0, 0))
            clean.assert_not_called()
