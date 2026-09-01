#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from script_test_support import ROOT, ScriptRegressionTestCase, load_script

class ContentAndPolicyScriptTests(ScriptRegressionTestCase):
    def test_publicize_ignores_braces_in_string_literals(self) -> None:
        source = 'struct Thing {\n    let brace = "}"\n    let value = 1\n}\n'
        output = self.codegen.publicize(source)
        self.assertIn("public let value = 1", output)

    def test_homestead_prerequisite_tier_must_exist(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.validate_homestead_prerequisites(
                "wheatField:9", "orchard-tier-1", {"wheatField": {1, 2}}
            )

    def test_content_codegen_rejects_unknown_command(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "Scripts" / "content_codegen.py"), "typo"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown command", result.stderr)

    def test_triggers_swift_maps_known_token_to_grouped_field(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("on_cleanse_self_heal:2"),
            "CombatTraitTriggers(healing: HealingTriggers(cleanseSelfHeal: 2))",
        )

    def test_triggers_swift_rename_table_tokens(self) -> None:
        output = self.codegen.triggers_swift("on_cleanse_draw:1|on_gain_gold_heal:3")
        self.assertIn("cleanseBonusDraw: 1", output)
        self.assertIn("gainGoldBonusHealSelf: 3", output)

    def test_triggers_swift_damage_below_health_percent_both_arities(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("damage_below_health_percent:50:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentBonus: 5))",
        )
        self.assertEqual(
            self.codegen.triggers_swift("damage_below_health_percent:50:fire:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentKeyword: .fire, "
            "damageBelowHealthPercentBonus: 5))",
        )

    def test_triggers_swift_generic_path_converts_snake_case_field(self) -> None:
        self.assertEqual(
            self.codegen.triggers_swift("poison_decay_slow_percent:50"),
            "CombatTraitTriggers(dot: DotTriggers(poisonDecaySlowPercent: 50))",
        )

    def test_triggers_swift_unknown_token_fails_loudly(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.triggers_swift("not_a_real_trigger:1")

    def test_triggers_swift_rejects_glued_tokens(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.triggers_swift("poison_decay_slow_percent:50,bogus_field:1")

    def test_modifier_token_to_swift_multipart_keyword(self) -> None:
        self.assertEqual(
            self.codegen.modifier_token_to_swift("damage_dealt:fire:3"),
            ".damageDealt(.fire, 3)",
        )

    def test_plan_metadata_requires_lifecycle_fields_and_blocked_reason(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            valid = root / "valid.md"
            valid.write_text(
                "---\n"
                "type: execution-plan\n"
                "status: active\n"
                "created: 2026-08-20\n"
                "updated: 2026-08-20\n"
                "expires: 2026-09-03\n"
                "---\n\n# Plan\n",
                encoding="utf-8",
            )
            metadata, errors = self.check_docs.plan_metadata(valid)
            self.assertEqual(errors, [])
            self.assertEqual(metadata["status"], "active")

            blocked = root / "blocked.md"
            blocked.write_text(valid.read_text(encoding="utf-8").replace("status: active", "status: blocked"), encoding="utf-8")
            _, errors = self.check_docs.plan_metadata(blocked)
            self.assertIn("blocked plans require reason", errors)

    def test_completed_plans_are_summarized_instead_of_archived_verbatim(self) -> None:
        plan_name = f"ArchiveFixture{os.getpid()}"
        active_path = ROOT / "Docs" / "Plans" / f"{plan_name}.md"
        archived_path = ROOT / "Docs" / "Plans" / "Archived" / f"{plan_name}.md"
        plan = (
            "---\n"
            "type: execution-plan\n"
            "status: complete\n"
            "created: 2026-08-01\n"
            "updated: 2026-08-20\n"
            "expires: 2026-08-19\n"
            "---\n\n# Archived fixture\n"
        )
        try:
            active_path.write_text(plan, encoding="utf-8")
            rejected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-docs.py")],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("must be summarized in Docs/Plans/Archived/README.md and deleted", rejected.stderr)

            active_path.unlink()
            archived_path.write_text(plan, encoding="utf-8")
            archived_rejected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-docs.py")],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(archived_rejected.returncode, 0)
            self.assertIn("completed plan detail belongs in Git history", archived_rejected.stderr)
        finally:
            active_path.unlink(missing_ok=True)
            archived_path.unlink(missing_ok=True)

    def test_parallel_agent_plan_folder_is_rejected(self) -> None:
        plans_dir = ROOT / ".agents" / "plans"
        plan_path = plans_dir / f"ParallelPlanFixture{os.getpid()}.md"
        plans_dir.mkdir(parents=True, exist_ok=True)
        try:
            plan_path.write_text("# Parallel execution plan\n", encoding="utf-8")
            rejected = subprocess.run(
                [sys.executable, str(ROOT / "Scripts" / "check-docs.py")],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("execution plans are allowed only directly under Docs/Plans/", rejected.stderr)
        finally:
            plan_path.unlink(missing_ok=True)
            try:
                plans_dir.rmdir()
            except OSError:
                pass

    def test_proposal_evidence_identifier_resolution(self) -> None:
        self.assertTrue(self.check_docs.source_contains_identifier("performBatchMutation"))
        missing = "RemovedProposal" + "EvidenceSymbol"
        self.assertFalse(self.check_docs.source_contains_identifier(missing))

    def test_markdown_inventory_excludes_ignored_run_reports(self) -> None:
        paths = self.check_docs.markdown_files()
        self.assertTrue(paths)
        self.assertTrue(all(path.suffix == ".md" for path in paths))
        self.assertFalse(any("BalanceSweepReports" in path.parts for path in paths))

    def test_ui_style_requires_explicit_catalog_artwork_display_size(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "ArtworkFixture.swift"
            fixture.write_text(
                "Image.preparedAsset(named: art.imageName)\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(
                [str(ROOT / "Scripts" / "check-ui-style.sh"), str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("catalog artwork without explicit display size", rejected.stdout)

            fixture.write_text(
                "Image.preparedAsset(art, displaySize: .compact)\n",
                encoding="utf-8",
            )
            accepted = subprocess.run(
                [str(ROOT / "Scripts" / "check-ui-style.sh"), str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(accepted.returncode, 0, accepted.stdout + accepted.stderr)

    def test_comment_ban_rejects_inline_and_block_comments(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "CommentFixture.swift"
            fixture.write_text(
                "let value = 1 // inline rationale\n"
                "/* block rationale */\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [str(ROOT / "Scripts" / "check-comment-ban.sh"), "--", str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Comment ban violations (2)", result.stderr)

    def test_comment_ban_keeps_toolchain_and_transitional_allowlist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "AllowedCommentFixture.swift"
            fixture.write_text(
                "// swift-tools-version: 6.2\n"
                "struct Probe {} // swiftlint:disable:this type_body_length - fixture\n"
                "/// Concurrency-Safety: immutable fixture\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [str(ROOT / "Scripts" / "check-comment-ban.sh"), "--", str(fixture)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_agent_invariants_cover_entropy_sleep_persistence_and_concurrency(self) -> None:
        text = (ROOT / "Scripts" / "check-agent-invariants.sh").read_text(encoding="utf-8")
        self.assertIn(r"\b(Date|UUID)\(\)", text)
        self.assertIn("Task.sleep", text)
        self.assertIn("PersistenceCheck", text)
        self.assertIn("@unchecked Sendable", text)
        self.assertIn("ArtworkWorkingSetCheck", text)
        self.assertIn("Trinket/App/TrinketApp.swift", text)
        self.assertIn("swiftlint:disable must include ' - <reason>'", text)
        self.assertIn(r"//[[:space:]]*swiftlint:disable", text)

    def test_accessibility_ids_reject_duplicate_constants_and_raw_uitest_literals(self) -> None:
        checker = load_script("check_accessibility_ids", "check-accessibility-ids.py")
        duplicates = checker.unique_constants()
        self.assertEqual(duplicates, [])
        raw = checker.raw_uitest_literals(checker.allowlist())
        self.assertEqual(raw, [], raw)

    def test_style_gate_invokes_agent_invariants_and_accessibility_ids(self) -> None:
        text = (ROOT / "Scripts" / "test.sh").read_text(encoding="utf-8")
        self.assertIn("check-agent-invariants.sh", text)
        self.assertIn("check-accessibility-ids.sh", text)

    def test_content_codegen_routes_generation_and_script_tests(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Scripts/content_codegen.py",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = "\n".join(result.stdout.splitlines())
        self.assertIn("./Scripts/generate.sh", plan)
        self.assertIn("./Scripts/test-scripts.sh", plan)

    def test_authored_content_swift_routes_generation_style_and_package(self) -> None:
        result = subprocess.run(
            [
                str(ROOT / "Scripts" / "handoff.sh"),
                "--dry-run",
                "--paths",
                "Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = [line.strip() for line in result.stdout.splitlines() if line.startswith("  ")]
        self.assertEqual(
            plan[:4],
            [
                "./Scripts/generate.sh",
                "./Scripts/assert-generated-output.sh --idempotent",
                "./Scripts/test.sh style Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalogBasic.swift",
                "./Scripts/test-package.sh TrinketContent",
            ],
        )
        self.assertEqual(
            plan[4:],
            [
                "./Scripts/check-module-boundaries.sh",
                "./Scripts/check-swift-testing-migration.sh",
                "./Scripts/release-notes.sh validate",
                "./Scripts/check-artwork-budget.sh",
            ],
        )

if __name__ == "__main__":
    unittest.main()
