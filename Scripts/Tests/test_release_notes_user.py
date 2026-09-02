#!/usr/bin/env python3
"""Classifier and formatter tests for player-facing release notes."""

from __future__ import annotations

import subprocess
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
    def test_content_feat_is_user_facing(self) -> None:
        self.assertTrue(
            notes.is_user_facing(
                commit(
                    "feat(content): add a new hero",
                    "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog.swift",
                    "ContentManifest/abilities.tsv",
                )
            )
        )

    def test_battle_engine_fix_is_user_facing(self) -> None:
        self.assertTrue(
            notes.is_user_facing(
                commit(
                    "fix(battle): resolve dodge against blocked hits",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine+Dodge.swift",
                )
            )
        )

    def test_scripts_only_add_is_not_user_facing(self) -> None:
        self.assertFalse(
            notes.is_user_facing(
                commit("Add CI cache pruning", "Scripts/ci-gate.sh", ".github/workflows/tests.yml")
            )
        )

    def test_test_only_add_is_not_user_facing(self) -> None:
        self.assertFalse(
            notes.is_user_facing(
                commit(
                    "Add coverage for dodge triggers",
                    "Packages/BattleEngine/Tests/BattleEngineTests/CombatTriggerFieldCoverageTests.swift",
                )
            )
        )

    def test_refactor_extract_is_not_user_facing(self) -> None:
        self.assertFalse(
            notes.is_user_facing(
                commit(
                    "Extract dodge handling from CombatTriggerEngine",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine+Dodge.swift",
                )
            )
        )
        self.assertFalse(
            notes.is_user_facing(
                commit(
                    "refactor(battle): split trigger handlers",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine.swift",
                )
            )
        )

    def test_user_facing_no_overrides_feat(self) -> None:
        self.assertFalse(
            notes.is_user_facing(
                commit(
                    "feat(content): reshuffle internal catalog ids",
                    "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog.swift",
                    body="User-Facing: no",
                )
            )
        )

    def test_user_facing_yes_overrides_scripts_only(self) -> None:
        self.assertTrue(
            notes.is_user_facing(
                commit(
                    "chore: surface a player-visible options default",
                    "Scripts/release.sh",
                    body="User-Facing: yes",
                )
            )
        )

    def test_feat_extract_is_kept(self) -> None:
        self.assertTrue(
            notes.is_user_facing(
                commit(
                    "feat(battle): extract dodge into its own trigger",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine+Dodge.swift",
                )
            )
        )

    def test_imperative_product_change_is_kept(self) -> None:
        self.assertTrue(
            notes.is_user_facing(
                commit(
                    "Tighten dodge resolution on blocked hits",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine+Dodge.swift",
                )
            )
        )

    def test_player_line_prefers_body_bullet(self) -> None:
        line = notes.player_line(
            commit(
                "feat(battle): retarget when a hero dies mid-turn",
                "Packages/BattleEngine/Sources/BattleEngine/BattleTurnEngine.swift",
                body="- Enemies now pick a new target if the current one dies mid-turn.",
            )
        )
        self.assertEqual(
            line,
            "Enemies now pick a new target if the current one dies mid-turn.",
        )

    def test_build_notes_skips_infra_and_uses_fallback(self) -> None:
        summary, bullets = notes.build_notes(
            [
                commit("Add script regression coverage", "Scripts/Tests/test_ci_verification_scripts.py"),
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
                    body="- Recruit a new hero in the collection.",
                ),
                commit(
                    "fix(battle): dodge blocked hits",
                    "Packages/BattleEngine/Sources/BattleEngine/CombatTriggerEngine+Dodge.swift",
                ),
                commit("chore: regenerate project", "project.yml"),
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

    def test_strip_unreleased_placeholder(self) -> None:
        changelog = (
            "# Changelog\n\n"
            "## [0.2.0] - 2026-08-26\n\n"
            "### Added\n\n"
            "- Something players can see.\n\n"
            "## [Unreleased]\n\n"
            "<!-- New entries are generated at release time by ./Scripts/release.sh from git history. -->\n\n"
            "## [0.1.0] - 2026-07-04\n"
        )
        stripped = notes.strip_unreleased_section(changelog)
        self.assertNotIn("Unreleased", stripped)
        self.assertIn("## [0.2.0]", stripped)
        self.assertIn("## [0.1.0]", stripped)

    def test_parse_git_log_reads_subject_body_and_files(self) -> None:
        raw = (
            "===COMMIT===\n"
            "feat(content): add a new hero\n"
            "===BODY===\n"
            "- Recruit a new hero in the collection.\n"
            "\n"
            "===FILES===\n"
            "ContentManifest/heroes.tsv\n"
            "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog.swift\n"
        )
        parsed = notes.parse_git_log(raw)
        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0].subject, "feat(content): add a new hero")
        self.assertEqual(parsed[0].body, "- Recruit a new hero in the collection.")
        self.assertEqual(
            parsed[0].files,
            (
                "ContentManifest/heroes.tsv",
                "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog.swift",
            ),
        )

    def test_cliff_appstore_toml_is_gone(self) -> None:
        self.assertFalse((ROOT / "cliff-appstore.toml").exists())

    def test_does_not_write_prompt_file(self) -> None:
        source = (ROOT / "Scripts" / "release-notes-user.py").read_text(encoding="utf-8")
        self.assertNotIn(".prompt.md", source)
        self.assertNotIn("PROMPT", source)

    def test_release_dry_run_still_prints_player_draft(self) -> None:
        release = (ROOT / "Scripts" / "release.sh").read_text(encoding="utf-8")
        self.assertIn("release-notes-user.py", release)
        self.assertIn("--dry-run", release)
        result = subprocess.run(
            [sys.executable, str(ROOT / "Scripts" / "release-notes-user.py"), "--dry-run", "--version", "0.2.0"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip())
        self.assertNotIn(".prompt.md", result.stdout)

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

    def test_github_release_uses_store_notes(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(encoding="utf-8")
        self.assertIn("ReleaseNotes/en-US.txt", workflow)
        self.assertIn("See CHANGELOG.md for the full developer log.", workflow)
        self.assertNotIn("github-body", workflow)

    def test_release_notes_sh_strips_unreleased_after_prepend(self) -> None:
        script = (ROOT / "Scripts" / "release-notes.sh").read_text(encoding="utf-8")
        self.assertIn("--strip-unreleased CHANGELOG.md", script)

    def test_commit_msg_hook_does_not_nag_user_facing(self) -> None:
        hook = (ROOT / "Scripts" / "validate-commit-msg.sh").read_text(encoding="utf-8")
        self.assertNotIn("User-Facing", hook)


if __name__ == "__main__":
    unittest.main()
