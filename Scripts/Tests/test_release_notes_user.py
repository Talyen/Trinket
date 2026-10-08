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


if __name__ == "__main__":
    unittest.main()
