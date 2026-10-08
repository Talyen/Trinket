"""Push checks must inspect the source actually shipped, without modifying it."""

from __future__ import annotations

SCRIPT_INPUTS = ('.gitignore', 'Scripts/pre-push-paths.py', '.githooks/pre-push')

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from script_test_support import ROOT


class PrePushTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('GIT_', 'SKIP_TRINKET_'))}
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        (self.root / 'old.swift').write_text('original\n')
        (self.root / 'untouched.txt').write_text('older source\n')
        self.commit()
        self.base = self.git('rev-parse', 'HEAD').stdout.strip()

    def git(self, *args):
        result = subprocess.run(['git', *args], cwd=self.root, env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def commit(self):
        self.git('add', '.')
        self.git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture')

    def refs(self, local=None, remote=None):
        local = local or self.git('rev-parse', 'HEAD').stdout.strip()
        return f'refs/heads/main {local} refs/heads/main {remote or self.base}\n'

    def select(self, refs):
        return subprocess.run(['python3', str(ROOT / 'Scripts/pre-push-paths.py')],
                              cwd=self.root, env=self.env, input=refs,
                              capture_output=True, text=True)

    def test_new_refs_cover_complete_tree_and_moves_keep_old_owner(self):
        self.git('mv', 'old.swift', 'renamed.swift')
        self.commit()
        selected = self.select(self.refs())
        self.assertEqual(selected.returncode, 0, selected.stderr)
        self.assertEqual(selected.stdout.splitlines(), ['old.swift', 'renamed.swift'])
        new_ref = self.select(self.refs(remote='0' * 40))
        self.assertEqual(new_ref.returncode, 0, new_ref.stderr)
        self.assertEqual(new_ref.stdout.splitlines(), ['renamed.swift', 'untouched.txt'])
        self.git('rm', 'renamed.swift')
        self.commit()
        deleted = self.select(self.refs())
        self.assertEqual(deleted.returncode, 0, deleted.stderr)
        self.assertEqual(deleted.stdout.splitlines(), ['old.swift'])

    def test_dirty_or_wrong_source_and_unavailable_revisions_fail(self):
        (self.root / 'old.swift').write_text('committed change\n')
        self.commit()
        for refs in (self.refs(local=self.base), self.refs(remote='1' * 40), 'malformed\n'):
            with self.subTest(refs=refs):
                self.assertNotEqual(self.select(refs).returncode, 0)
        for mode in ('unstaged', 'staged', 'untracked'):
            with self.subTest(mode=mode):
                path = self.root / ('new.txt' if mode == 'untracked' else 'old.swift')
                before = path.read_bytes() if path.exists() else None
                path.write_text('outstanding work\n')
                if mode == 'staged':
                    self.git('add', path.name)
                result = self.select(self.refs())
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('clean checkout', result.stderr)
                self.assertEqual(path.read_text(), 'outstanding work\n')
                # Undo only this test-owned fixture, never the real checkout.
                if before is None:
                    path.unlink()
                else:
                    path.write_bytes(before)
                    self.git('add', path.name)

    def test_deleting_a_remote_ref_does_not_check_dirty_source(self):
        (self.root / 'new.txt').write_text('outstanding work\n')
        for refs in ('', self.refs(local='0' * 40)):
            with self.subTest(refs=refs):
                result = self.select(refs)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, '')

    def test_hook_propagates_discovery_failure_and_rechecks_source(self):
        for relative in ('.gitignore', '.githooks/pre-push', 'Scripts/pre-push-paths.py',
                         'Scripts/internal/change_routing.py', 'Scripts/internal/agent_status.py',
                         'Scripts/internal/cli.py', 'Scripts/build-inputs.env', 'Scripts/config/ui-tests.tsv'):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        scripts = self.root / 'Scripts'
        for name in ('ensure-ci-tools.sh', 'test.sh', 'agent-push-gate.sh',
                     'check-api-bans.sh', 'check-exclusivity-footguns.sh',
                     'check-agent-invariants.sh', 'prepare-assets.sh'):
            path = scripts / name
            path.write_text('#!/bin/bash\nexit 0\n')
            path.chmod(0o755)
        (scripts / 'check-accessibility-ids.py').write_text('')
        self.commit()
        def hook(refs):
            return subprocess.run(['bash', '.githooks/pre-push'], cwd=self.root,
                                  env=self.env, input=refs, capture_output=True, text=True)
        missing = hook(self.refs(remote='1' * 40))
        self.assertNotEqual(missing.returncode, 0)
        self.assertNotIn('ensure pinned', missing.stdout)
        clean = hook(self.refs())
        self.assertEqual(clean.returncode, 0, clean.stdout + clean.stderr)
        path = scripts / 'agent-push-gate.sh'
        path.write_text('#!/bin/bash\nprintf changed > old.swift\n')
        self.commit()
        rewritten = hook(self.refs())
        self.assertNotEqual(rewritten.returncode, 0)
        self.assertIn('clean checkout', rewritten.stderr)
        self.assertNotIn('Pre-push gate passed', rewritten.stdout)


if __name__ == '__main__':
    unittest.main()
