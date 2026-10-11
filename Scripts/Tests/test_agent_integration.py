from __future__ import annotations

SCRIPT_INPUTS = ('Scripts/agent-worktree.mjs', 'Scripts/agent-integrate.py')

import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from script_test_support import ROOT, ScriptRegressionTestCase


class AgentIntegrationTests(ScriptRegressionTestCase):
    """Protect shared main and unfinished task work across real linked checkouts."""

    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.env.update(GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                        GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        self.git(self.root, 'init', '-q', '-b', 'main')
        self.git(self.root, 'config', 'core.hooksPath', '/dev/null')
        scripts = self.root / 'Scripts'
        scripts.mkdir()
        for name in ('agent-worktree.mjs', 'agent-integrate.py'):
            shutil.copy2(ROOT / 'Scripts' / name, scripts / name)
        handoff = scripts / 'handoff.sh'
        handoff.write_text('#!/bin/sh\nexit 0\n')
        handoff.chmod(0o755)
        (self.root / '.gitignore').write_text('.worktrees/\nignored\n')
        (self.root / 'shared').write_text('baseline\n')
        self.commit(self.root)

    def git(self, root: Path, *args: str) -> str:
        return subprocess.check_output(['/usr/bin/git', '-C', str(root), *args],
                                       env=self.env, text=True, stderr=subprocess.PIPE).strip()

    def commit(self, root: Path) -> None:
        self.git(root, 'add', '.')
        self.git(root, 'commit', '-qm', 'fixture')

    def helper(self, root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(['node', str(root / 'Scripts/agent-worktree.mjs'), *args],
                              env=self.env, capture_output=True, text=True, timeout=30)

    def create(self, name: str, root: Path | None = None) -> Path:
        result = self.helper(root or self.root, 'create', '--task', name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return self.root / '.worktrees' / name

    def task(self, name: str) -> Path:
        task = self.create(name)
        (task / name).write_text('task work\n')
        self.commit(task)
        return task

    def assert_stopped(self, task: Path, main: str) -> subprocess.CompletedProcess[str]:
        result = self.helper(task, 'integrate')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), main)
        return result

    def test_independent_tasks_land_without_losing_either_change(self) -> None:
        first = self.task('first')
        # Creating from a linked worktree must still use the primary worktree root.
        second = self.create('second', first)
        (second / 'second').write_text('second task\n')
        self.commit(second)
        for task in (first, second):
            result = self.helper(task, 'integrate')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), self.git(task, 'rev-parse', 'HEAD'))
        self.assertEqual((self.root / 'first').read_text(), 'task work\n')
        self.assertEqual((self.root / 'second').read_text(), 'second task\n')
        self.assertEqual(self.git(self.root, 'status', '--porcelain'), '')

    def test_busy_lock_and_dirty_checkouts_preserve_main_and_task(self) -> None:
        task = self.task('task')
        main = self.git(self.root, 'rev-parse', 'HEAD')
        with (self.root / '.git/trinket-integration.lock').open('a+') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertIn('busy', self.assert_stopped(task, main).stderr)
        for dirty in (self.root, task):
            with self.subTest(checkout=dirty):
                evidence = dirty / 'unfinished'
                evidence.write_text('preserve me')
                self.assert_stopped(task, main)
                self.assertEqual(evidence.read_text(), 'preserve me')
                evidence.unlink()
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failed_or_mutating_verification_cannot_land(self) -> None:
        task = self.task('task')
        main = self.git(self.root, 'rev-parse', 'HEAD')
        for body in ('exit 1', 'echo unexpected > unfinished'):
            with self.subTest(handoff=body):
                (task / 'Scripts/handoff.sh').write_text(f'#!/bin/sh\n{body}\n')
                self.commit(task)
                self.assert_stopped(task, main)
                if (task / 'unfinished').exists():
                    self.assertEqual((task / 'unfinished').read_text().strip(), 'unexpected')
                    (task / 'unfinished').unlink()

    def test_rebase_conflict_leaves_main_unchanged_and_task_recoverable(self) -> None:
        task = self.create('task')
        (task / 'shared').write_text('task version\n')
        self.commit(task)
        (self.root / 'shared').write_text('main version\n')
        self.commit(self.root)
        main = self.git(self.root, 'rev-parse', 'HEAD')
        self.assert_stopped(task, main)
        self.assertEqual((self.root / 'shared').read_text(), 'main version\n')
        self.assertIn('task version', (task / 'shared').read_text())
        self.assertIn('UU shared', self.git(task, 'status', '--porcelain'))
        self.git(self.root, 'show-ref', '--verify', 'refs/heads/codex/task')

    def test_cleanup_preserves_unmerged_dirty_and_ignored_work(self) -> None:
        task = self.task('task')
        self.assertNotEqual(self.helper(self.root, 'remove', '--task', 'task').returncode, 0)
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('unfinished', 'ignored'):
            evidence = task / name
            evidence.write_text('preserve me')
            self.assertNotEqual(self.helper(self.root, 'remove', '--task', 'task').returncode, 0)
            self.assertEqual(evidence.read_text(), 'preserve me')
            evidence.unlink()
        result = self.helper(self.root, 'remove', '--task', 'task')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(task.exists())
        self.git(self.root, 'show-ref', '--verify', 'refs/heads/codex/task')

    def test_ignored_files_cannot_be_overwritten_by_rebase_or_landing(self) -> None:
        task = self.task('task')
        # Main acquires a tracked file that already holds ignored local work in task.
        (self.root / 'ignored').write_text('main version')
        self.git(self.root, 'add', '-f', 'ignored')
        self.commit(self.root)
        (task / 'ignored').write_text('task evidence')
        main = self.git(self.root, 'rev-parse', 'HEAD')
        self.assert_stopped(task, main)
        self.assertEqual((task / 'ignored').read_text(), 'task evidence')

        # Task acquires a tracked file that would overwrite ignored local work on main.
        other = self.task('other')
        (other / 'local-only').write_text('task version')
        (other / '.gitignore').write_text('.worktrees/\nignored\nlocal-only\n')
        self.git(other, 'add', '-f', 'local-only')
        self.commit(other)
        (self.root / '.git/info/exclude').write_text('local-only\n')
        (self.root / 'local-only').write_text('main evidence')
        self.assert_stopped(other, main)
        self.assertEqual((self.root / 'local-only').read_text(), 'main evidence')
