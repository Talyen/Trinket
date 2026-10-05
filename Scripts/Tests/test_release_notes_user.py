#!/usr/bin/env python3
"""Classifier and formatter tests for player-facing release notes."""

from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/install-device.sh',
    'Scripts/lib/promote.sh',
    'Scripts/promote.sh',
    'Scripts/record-time-profiler.sh',
    'Scripts/release-notes-user.py',
    'Scripts/release.sh',
    'Scripts/run-simulator.sh',
    'Scripts/test-deploy.sh',
    'Scripts/validate-commit-msg.sh',
)


import subprocess
import io
from contextlib import redirect_stdout
from unittest.mock import patch
import sys
import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT, load_script

notes = load_script("release_notes_user", "release-notes-user.py")


def commit(
    subject: str,
    *files: str,
    body: str = "",
) -> notes.Commit:
    return notes.Commit(subject=subject, body=body, files=files)


class ReleaseNotesUserTests(unittest.TestCase):
    def test_player_facing_classification_respects_product_paths_and_overrides(self) -> None:
        product = "Packages/BattleEngine/Sources/BattleEngine/Turns/BattleTurnEngine.swift"
        cases = (
            (commit("feat(content): add a hero", "ContentManifest/heroes.tsv"), True),
            (commit("fix(battle): resolve dodge", product), True),
            (commit("Add CI cache pruning", "Scripts/ci-gate.sh", ".github/workflows/tests.yml"), False),
            (commit("Add coverage", "Packages/BattleEngine/Tests/BattleEngineTests/Test.swift"), False),
            (commit("Extract dodge handling", product), False),
            (commit("refactor(battle): split handlers", product), False),
            (commit("feat(content): internal IDs", product, body="User-Facing: no"), False),
            (commit("chore: options default", "Scripts/release.sh", body="User-Facing: yes"), True),
            (commit("feat(battle): extract dodge trigger", product), True),
            (commit("Tighten dodge resolution", product), True),
        )
        for candidate, expected in cases:
            with self.subTest(subject=candidate.subject):
                self.assertEqual(notes.is_user_facing(candidate), expected)

    def test_build_notes_skips_infra_and_uses_fallback(self) -> None:
        summary, bullets = notes.build_notes(
            [
                commit("Add script regression coverage", "Scripts/Tests/test_ci_build_scripts.py"),
                commit("ci: speed up isolate slots", ".github/workflows/tests.yml"),
            ]
        )
        self.assertEqual(summary, "Bug fixes and improvements.")
        self.assertEqual(bullets, ["• Stability and performance improvements"])

    def test_build_notes_emits_player_lines(self) -> None:
        summary, bullets = notes.build_notes(
            [
                commit(
                    "feat(content): add a new hero",
                    "ContentManifest/heroes.tsv",
                    body="- SwiftFormat cleanup.\n- User-Facing: yes\n"
                         "- recruit a new hero in the collection.\n- Unused later detail.",
                ),
                commit(
                    "fix(battle): dodge blocked hits",
                    "Packages/BattleEngine/Sources/BattleEngine/Triggers/CombatTriggerEngine+Dodge.swift",
                ),
                commit("chore: regenerate project", "project.yml"),
                commit("fix: dodge blocked hits", "Packages/BattleEngine/Sources/Rule.swift"),
            ]
        )
        self.assertEqual(summary, "Recruit a new hero in the collection.")
        self.assertEqual(
            bullets,
            [
                "• Recruit a new hero in the collection.",
                "• Dodge blocked hits",
            ],
        )

    def test_git_log_preserves_marker_text_and_unusual_product_filenames(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(["git", "-c", "commit.gpgsign=false", *args], cwd=root,
                                      capture_output=True, text=True, check=True)
            git("init")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            name = "ContentManifest/card \n===COMMIT===.tsv"
            path = root / name
            path.parent.mkdir()
            path.write_text("content")
            git("add", "--", name)
            body = "- Restore battle rewards.\n===BODY===\n===FILES===\n===COMMIT==="
            git("commit", "-m", "fix: restore rewards", "-m", body)
            # An empty body must not be confused with the file-list separator.
            path.write_text("changed")
            git("add", "--", name)
            git("commit", "-m", "fix: improve rewards")
            with patch.object(notes, "ROOT", root):
                parsed = notes.load_commits(None)
            self.assertEqual(parsed, [commit("fix: improve rewards", name),
                                      commit("fix: restore rewards", name, body=body)])
            self.assertEqual(notes.build_notes(parsed)[1],
                             ["• Improve rewards", "• Restore battle rewards."])

    def test_release_dry_run_prints_player_draft_without_writing_notes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "notes.txt"
            output.write_text("existing release notes")
            draft = io.StringIO()
            with patch.object(notes, "OUTPUT", output), patch.object(notes, "latest_tag", return_value=None), \
                 patch.object(notes, "load_commits", return_value=[commit("fix: restore battle rewards", "Packages/Rewards.swift")]), \
                 patch.object(sys, "argv", ["release-notes-user.py", "--dry-run", "--version", "0.2.0"]), redirect_stdout(draft):
                notes.main()
            self.assertIn("Restore battle rewards", draft.getvalue())
            self.assertEqual(output.read_text(), "existing release notes")

    def test_strip_unreleased_flag_rewrites_changelog(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "CHANGELOG.md"
            path.write_text(
                "# Changelog\n\n## [Unreleased]\n\n<!-- placeholder -->\n\n## [0.1.0]\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    "python3",
                    str(ROOT / "Scripts" / "release-notes-user.py"),
                    "--strip-unreleased",
                    str(path),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("Unreleased", text)
            self.assertIn("## [0.1.0]", text)


if __name__ == "__main__":
    unittest.main()
