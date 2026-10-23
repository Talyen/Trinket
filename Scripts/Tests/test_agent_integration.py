from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from script_test_support import ROOT, ScriptRegressionTestCase, run_captured, write_executable


class AgentIntegrationTests(ScriptRegressionTestCase):
    """Protect shared main and unfinished task work across real linked checkouts."""

    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.archive = self.root.parent / (self.root.name + '-archives')
        self.addCleanup(lambda: shutil.rmtree(self.archive, ignore_errors=True))
        self.env['CODEX_WORKTREE_ARCHIVE_ROOT'] = str(self.archive)
        self.env.update(GIT_AUTHOR_NAME='Fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
                        GIT_COMMITTER_NAME='Fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')
        self.git(self.root, 'init', '-q', '-b', 'main')
        self.git(self.root, 'config', 'core.hooksPath', '/dev/null')
        scripts = self.root / 'Scripts'
        scripts.mkdir()
        for name in ('agent-worktree.mjs', 'agent-integrate.py'):
            shutil.copy2(ROOT / 'Scripts' / name, scripts / name)
        (scripts / 'internal').mkdir()
        shutil.copy2(ROOT / 'Scripts/internal/cli.py', scripts / 'internal/cli.py')
        shutil.copy2(ROOT / 'Scripts/internal/verification_evidence.py', scripts / 'internal/verification_evidence.py')
        (scripts / 'internal/change_routing.py').write_text(
            'def classify(*args, **kwargs): return None\n'
            'def automatic_plan(*args, **kwargs): return []\n')
        write_executable(scripts / 'handoff.sh', '#!/bin/sh\nexit 0\n')
        (self.root / '.gitignore').write_text('.worktrees/\nignored\n__pycache__/\n.DerivedData/\n.tools/\n')
        (self.root / 'shared').write_text('baseline\n')
        self.commit(self.root)

    def git(self, root: Path, *args: str) -> str:
        return subprocess.check_output(['/usr/bin/git', '-C', str(root), *args],
                                       env=self.env, text=True, stderr=subprocess.PIPE).strip()

    def commit(self, root: Path) -> None:
        self.git(root, 'add', '.')
        self.git(root, 'commit', '-qm', 'fixture')

    def helper(self, root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return run_captured(['node', str(root / 'Scripts/agent-worktree.mjs'), *args], env=self.env, timeout=30)

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
            if task == second:
                self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
                self.assertIn('Review incoming changes:', result.stderr)
                self.assertTrue(task.exists())
                self.assertEqual((self.root / 'first').read_text(), 'task work\n')
                self.assertFalse((self.root / 'second').exists())
                result = self.helper(task, 'integrate')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(task.exists())
            self.assertEqual(self.helper(task, 'cleanup').returncode, 0)
            self.assertFalse(task.exists())
            self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), self.git(self.root, 'rev-parse', 'codex/' + task.name))
        self.assertEqual((self.root / 'first').read_text(), 'task work\n')
        self.assertEqual((self.root / 'second').read_text(), 'second task\n')
        self.assertEqual(self.git(self.root, 'status', '--porcelain'), '')

    def test_main_advances_require_review_before_checks_or_landing(self) -> None:
        task = self.task('task')
        write_executable(task / 'Scripts/handoff.sh', '#!/bin/sh\necho checked >> "$(git rev-parse --git-common-dir)/checks"\n')
        self.commit(task)
        for name in ('first', 'second'):
            (self.root / name).write_text('incoming\n')
            self.commit(self.root)
            main = self.git(self.root, 'rev-parse', 'HEAD')
            result = self.helper(task, 'integrate')
            self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
            self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), main)
            self.assertFalse((self.root / '.git/checks').exists())
            self.assertEqual(self.git(task, 'merge-base', 'HEAD', 'main'), main)
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / '.git/checks').read_text(), 'checked\n')

    def test_reviewed_main_skips_redundant_checkpoint_but_rejects_a_later_advance(self) -> None:
        task = self.task('task')
        (self.root / 'incoming').write_text('reviewed main work')
        self.commit(self.root)
        reviewed = self.git(self.root, 'rev-parse', 'HEAD')
        for arguments in (('--reviewed-main', 'main'), ('--cleanup',), ('--keep-worktree', '--keep-worktree')):
            self.assertNotEqual(self.helper(task, 'integrate', *arguments).returncode, 0)
            self.assertTrue(task.exists())
            self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), reviewed)
        result = self.helper(task, 'integrate', '--reviewed-main', reviewed)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(task.exists())
        self.assertEqual((self.root / 'task').read_text(), 'task work\n')
        other = self.task('other')
        (self.root / 'later').write_text('unreviewed main work')
        self.commit(self.root)
        main = self.git(self.root, 'rev-parse', 'HEAD')
        previous = self.git(other, 'rev-parse', 'HEAD')
        result = self.helper(other, 'integrate', '--reviewed-main', reviewed)
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), main)
        self.assertEqual(self.git(other, 'rev-parse', 'HEAD'), previous)

    def test_landing_requires_current_compiled_evidence_and_preserves_it_across_commit(self) -> None:
        from internal.verification_evidence import source_identity
        task = self.task('compiled')
        routing = task / 'Scripts/internal/change_routing.py'
        routing.write_text('from types import SimpleNamespace\n'
                           'def classify(*args, **kwargs): return None\n'
                           'def automatic_plan(*args, **kwargs): return [SimpleNamespace(\n'
                           ' id="package:Example", argv=("./Scripts/test-package.sh", "Example"), deferred=False)]\n')
        tools = self.root / '.tools'
        tools.mkdir()
        write_executable(tools / 'xcodebuild', '#!/bin/sh\necho Fixture-Xcode\n')
        self.env['PATH'] = str(tools) + os.pathsep + self.env['PATH']
        self.commit(task)
        main = self.git(self.root, 'rev-parse', 'HEAD')
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn('package:Example', result.stderr)
        self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), main)
        report = task / '.DerivedData/Deliverables/Verification/check.json'
        report.parent.mkdir(parents=True)
        def evidence():
            report.write_text(json.dumps({'source_identity': source_identity(task),
                'toolchain': {'developer_dir': self.env.get('DEVELOPER_DIR', ''), 'xcode': 'Fixture-Xcode', 'architecture': os.uname().machine},
                'checks': [{'id': 'package:Example', 'argv': ['./Scripts/test-package.sh', 'Example'], 'outcome': 'passed'}]}))
        evidence()
        failed = report.with_name('failed.json')
        failure = json.loads(report.read_text())
        failure['checks'][0]['outcome'] = 'failed'
        failed.write_text(json.dumps(failure))
        self.assertEqual(self.helper(task, 'integrate').returncode, 3)
        (task / 'task').write_text('changed after verification\n')
        self.commit(task)
        self.assertEqual(self.helper(task, 'integrate').returncode, 3)
        # Committing identical sources and changing guidance preserve compiled evidence.
        (task / 'task').write_text('verified contents\n')
        evidence()
        identity = source_identity(task)
        (task / 'notes.md').write_text('Guidance-only change after verification\n')
        self.assertEqual(source_identity(task), identity)
        self.commit(task)
        self.assertEqual(source_identity(task), identity)
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stderr)

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
        result = self.helper(task, 'integrate', '--keep-worktree')
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('unfinished', 'ignored'):
            evidence = task / name
            evidence.write_text('preserve me')
            self.assertNotEqual(self.helper(self.root, 'remove', '--task', 'task').returncode, 0)
            self.assertEqual(evidence.read_text(), 'preserve me')
            evidence.unlink()
        result = self.helper(task, 'cleanup')
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
        ignore = other / '.gitignore'
        ignore.write_text(ignore.read_text() + 'local-only\n')
        self.git(other, 'add', '-f', 'local-only')
        self.commit(other)
        (self.root / '.git/info/exclude').write_text('local-only\n')
        (self.root / 'local-only').write_text('main evidence')
        result = self.assert_stopped(other, main)
        self.assertIn('Ignored file would be overwritten', result.stderr)
        self.assertIn('local-only', result.stderr)
        self.assertEqual((self.root / 'local-only').read_text(), 'main evidence')
        report = json.loads((other / '.DerivedData/Deliverables/task-report.json').read_text())
        self.assertEqual(report['completion_state'], 'local checks passed; landing pending')

    def test_explicit_cleanup_deletes_local_outputs_and_preserves_peer(self) -> None:
        task = self.task('task')
        peer = self.task('peer')
        (task / 'ignored').mkdir()
        (task / 'ignored/build-output').write_text('rebuildable')
        (task / 'ignored/peer').symlink_to(peer, target_is_directory=True)
        (peer / 'unfinished').write_text('peer work')
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(task.exists())
        self.assertEqual((task / 'ignored/build-output').read_text(), 'rebuildable')
        self.assertEqual(self.helper(task, 'cleanup').returncode, 0)
        self.assertFalse(task.exists())
        self.assertEqual(list(self.archive.iterdir()), [])
        self.assertNotIn(str(task), self.git(self.root, 'worktree', 'list', '--porcelain'))
        self.assertEqual((peer / 'unfinished').read_text(), 'peer work')
        self.git(self.root, 'show-ref', '--verify', 'refs/heads/codex/task')

    def test_landing_reports_local_state_and_preserves_deliverables_before_explicit_cleanup(self) -> None:
        task = self.task('task')
        captures = task / '.DerivedData/Deliverables'
        captures.mkdir(parents=True)
        (captures / 'screen.png').write_bytes(b'fixture capture')
        (task / 'ignored').write_text('other task evidence')
        explicit = self.helper(task, 'evidence', 'ignored')
        self.assertEqual(explicit.returncode, 0, explicit.stderr)
        write_executable(task / 'Scripts/handoff.sh', '#!/bin/sh\necho checked >> "$(git rev-parse --git-common-dir)/checks"\n')
        self.commit(task)
        head = self.git(task, 'rev-parse', 'HEAD')
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(task.exists())
        self.assertEqual((self.root / '.git/checks').read_text(), 'checked\n')
        evidence = self.root / '.git/trinket-evidence/codex/task'
        saved = list(evidence.glob('*/files/.DerivedData/Deliverables/screen.png'))
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0].read_bytes(), b'fixture capture')
        manifest = json.loads(next(evidence.glob(head[:12] + '-*/evidence.json')).read_text())
        self.assertEqual(manifest['preserved_at_commit'], head)
        self.assertEqual(next(evidence.glob('*/files/ignored')).read_text(), 'other task evidence')
        report = json.loads(next(evidence.glob('*/files/.DerivedData/Deliverables/task-report.json')).read_text())
        self.assertEqual(report['static_verified_commit'], head)
        self.assertIn('task', report['changed_paths'])
        self.assertEqual(report['completion_state'], 'locally integrated; hosted verification pending')
        self.assertEqual(self.helper(task, 'cleanup').returncode, 0)
        self.assertFalse(task.exists())

    def test_invalid_evidence_preserves_main_and_never_follows_peer_symlinks(self) -> None:
        task = self.task('task')
        main = self.git(self.root, 'rev-parse', 'HEAD')
        captures = task / '.DerivedData/Deliverables'
        captures.mkdir(parents=True)
        (captures / 'foreign').symlink_to(self.root / 'shared')
        self.assert_stopped(task, main)
        self.assertTrue(task.exists())
        self.assertNotEqual(self.helper(task, 'evidence', '../outside').returncode, 0)

    def test_locked_worktree_cleanup_is_blocked_after_landing(self) -> None:
        task = self.task('task')
        self.git(self.root, 'worktree', 'lock', str(task))
        result = self.helper(task, 'integrate')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotEqual(self.helper(task, 'cleanup').returncode, 0)
        self.assertTrue(task.exists())
        self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), self.git(task, 'rev-parse', 'HEAD'))
        # Retry cleanup alone after unlocking and advancing main. A dirty primary
        # checkout is safe here because cleanup never writes its files or ref.
        self.git(self.root, 'worktree', 'unlock', str(task))
        (self.root / 'later').write_text('later work')
        self.commit(self.root)
        main = self.git(self.root, 'rev-parse', 'HEAD')
        (self.root / 'unfinished').write_text('preserve main work')
        result = self.helper(task, 'cleanup')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(task.exists())
        self.assertEqual(self.git(self.root, 'rev-parse', 'HEAD'), main)
        self.assertEqual((self.root / 'unfinished').read_text(), 'preserve main work')

    def test_cleanup_cannot_remove_unmerged_or_dirty_task_work(self) -> None:
        task = self.task('task')
        self.assertNotEqual(self.helper(task, 'cleanup').returncode, 0)
        self.assertTrue(task.exists())
        self.assertEqual(self.helper(task, 'integrate', '--keep-worktree').returncode, 0)
        (task / 'unfinished').write_text('preserve task work')
        self.assertNotEqual(self.helper(task, 'cleanup').returncode, 0)
        self.assertEqual((task / 'unfinished').read_text(), 'preserve task work')
