from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/agent-worktree.mjs',
    'Scripts/bin/git',
    'Scripts/config/destructive-git-commands.txt',
    'Scripts/git-safety-guard.mjs',
    'Scripts/setup-git-safety.mjs',
)

from pathlib import Path
import os
import shutil
import subprocess
import tempfile
from script_test_support import ScriptRegressionTestCase, ROOT


class GitSafetyTests(ScriptRegressionTestCase):
    def test_force_push_refspecs_require_a_clean_readable_tree(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_git = root / "git"
            capture = root / "pushed"
            fake_git.write_text('#!/bin/sh\n'
                                'case "$1" in\n'
                                '  diff) exit "$FIXTURE_DIRTY" ;;\n'
                                '  ls-files) exit 0 ;;\n'
                                '  push) touch "$FIXTURE_PUSHED" ;;\n'
                                'esac\n')
            fake_git.chmod(0o755)
            for dirty, arguments, allowed in (("1", ["origin", "+HEAD:main"], False),
                                             ("2", ["origin", "+HEAD:main"], False),
                                             ("0", ["origin", "+HEAD:main"], True),
                                             ("1", ["-vf", "origin", "HEAD:main"], False),
                                             ("1", ["origin", "HEAD:main"], True)):
                with self.subTest(dirty=dirty, arguments=arguments):
                    capture.unlink(missing_ok=True)
                    result = subprocess.run([str(ROOT / "Scripts/bin/git"), "push", *arguments],
                                            cwd=root, capture_output=True, text=True,
                                            env={**os.environ, "REAL_GIT": str(fake_git),
                                                 "FIXTURE_DIRTY": dirty, "FIXTURE_PUSHED": str(capture),
                                                 "REAL_GIT_BYPASS": "0"})
                    self.assertEqual(result.returncode, 0 if allowed else 1, result.stdout + result.stderr)
                    self.assertEqual(capture.exists(), allowed)

    def test_git_setup_preserves_foreign_wrappers_and_updates_owned_wrappers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "Scripts/setup-git-safety.mjs", scripts)
            home = root / "home"
            wrapper = home / ".local/bin/git"
            wrapper.parent.mkdir(parents=True)
            (root / ".envrc").write_text(str(scripts / "bin"))
            environment = {**os.environ, "HOME": str(home)}
            for previous in ("#!/bin/sh\necho custom git\n", None,
                             "#!/bin/sh\n# Global harness-agnostic shim: if inside Trinket repo, delegate to repo guard\nold\n"):
                if previous is None:
                    wrapper.unlink()
                else:
                    wrapper.write_text(previous)
                result = subprocess.run(["node", str(scripts / "setup-git-safety.mjs")],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                if previous and "custom git" in previous:
                    self.assertEqual(wrapper.read_text(), previous)
                else:
                    self.assertIn(str(scripts / "bin/git"), wrapper.read_text())
                    self.assertNotIn("\nold\n", wrapper.read_text())


    def test_worktree_remove_preserves_unregistered_directories(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "Scripts/agent-worktree.mjs", scripts)
            worktree = root / ".worktrees/task"
            worktree.mkdir(parents=True)
            evidence = worktree / "unfinished.txt"
            evidence.write_text("work in progress")
            fake_git = root / "git"
            fake_git.write_text('#!/bin/sh\nprintf "worktree %s/task-other\\0\\0" "$FIXTURE_WORKTREES"\nexit "${FIXTURE_GIT_STATUS:-0}"\n')
            fake_git.chmod(0o755)
            for task, status in (("!!!", "0"), ("task", "0"), ("task", "1")):
                with self.subTest(task=task, status=status):
                    worktree.mkdir(parents=True, exist_ok=True)
                    evidence.write_text("work in progress")
                    result = subprocess.run(
                        ["node", str(scripts / "agent-worktree.mjs"), "remove", "--task", task],
                        env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                             "FIXTURE_WORKTREES": str(root / ".worktrees"), "FIXTURE_GIT_STATUS": status},
                        capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(evidence.read_text(), "work in progress")


    def test_git_guard_refuses_without_changing_target_repository(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            env.update(REAL_GIT="/usr/bin/git", GIT_OPTIONAL_LOCKS="0")
            def git(*args):
                return subprocess.check_output(["/usr/bin/git", *args], cwd=root, env=env)
            git("init", "-q")
            (root / "tracked").write_text("original")
            git("add", "tracked")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
            (root / "tracked").write_text("staged")
            git("add", "tracked")
            (root / "tracked").write_text("unstaged")
            (root / "untracked").write_text("unfinished")
            index = (root / ".git/index").read_bytes()
            for prefix in ([], ["-C", str(root)], ["-c", "core.quotepath=false", "-C", str(root)]):
                result = subprocess.run([str(ROOT / "Scripts/bin/git"), *prefix, "reset", "--hard"],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual((root / "tracked").read_text(), "unstaged")
                self.assertEqual((root / "untracked").read_text(), "unfinished")
                self.assertEqual((root / ".git/index").read_bytes(), index)
                self.assertEqual(git("stash", "list"), b"")

    def test_checkout_paths_without_separator_preserve_dirty_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
            env.update(REAL_GIT="/usr/bin/git", GIT_OPTIONAL_LOCKS="0")
            def git(*args):
                return subprocess.check_output(["/usr/bin/git", *args], cwd=root, env=env)
            git("init", "-q")
            tracked = root / "tracked"
            tracked.write_text("original")
            git("add", "tracked")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
            git("branch", "safe-branch")
            for args in (("tracked",), ("HEAD", "tracked"), ("--quiet", "HEAD", "tracked"), ("-qf", "HEAD")):
                with self.subTest(args=args):
                    tracked.write_text("unfinished")
                    result = subprocess.run([str(ROOT / "Scripts/bin/git"), "checkout", *args],
                                            cwd=root, env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertEqual(tracked.read_text(), "unfinished")
            # Safe branch navigation and creation may carry dirty work forward.
            result = subprocess.run([str(ROOT / "Scripts/bin/git"), "switch", "-qf", "safe-branch"],
                                    cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(tracked.read_text(), "unfinished")
            for args in (("safe-branch",), ("-b", "new-branch", "HEAD")):
                result = subprocess.run([str(ROOT / "Scripts/bin/git"), "checkout", *args],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(tracked.read_text(), "unfinished")
