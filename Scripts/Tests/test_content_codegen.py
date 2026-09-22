from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/abilities.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/homestead.py',
    'Scripts/internal/content/items.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/roster.py',
    'Scripts/internal/content/stages.py',
    'Scripts/internal/content/talents.py',
    'Scripts/internal/content/trigger_families/*.json',
)


import re
import subprocess
import sys

from script_test_support import ROOT, ScriptRegressionTestCase


class ContentCodegenTests(ScriptRegressionTestCase):
    def test_manifest_keyword_vocabulary_covers_core_keywords(self) -> None:
        sys.path.insert(0, str(ROOT / "Scripts"))
        from internal.content.content_codegen_modifiers import VALID_KEYWORDS
        source = (ROOT / "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift").read_text()
        cases = set(re.findall(r'^    case (\w+) =', source, re.MULTILINE))
        self.assertEqual(cases, set(VALID_KEYWORDS))

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
                "Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift",
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
                "./Scripts/test.sh style Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift",
                "./Scripts/test-package.sh TrinketContent",
            ],
        )
        self.assertEqual(
            plan[4:],
            [
                "./Scripts/check-module-boundaries.sh",
                "./Scripts/release-notes.sh validate",
                "./Scripts/check-artwork-budget.sh",
            ],
        )

    def test_live_manifests_validate_through_extracted_domains(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "Scripts/content_codegen.py"), "validate"],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Validated", result.stdout)

    def test_enemy_trait_lists_validate_and_render(self) -> None:
        sys.path.insert(0, str(ROOT / "Scripts"))
        from internal.content.roster import EnemyRow, validate_enemy_rows, render_enemy

        row = EnemyRow("test_enemy", "Test Enemy", "12", "false", "slash,bash,smite", "guard,bloodless", "mortal")
        abilities = {"slash", "bash", "smite"}
        traits = {"guard", "bloodless"}
        validate_enemy_rows([row], abilities, set(), traits)
        self.assertIn('traitIDs: ["guard", "bloodless"]', render_enemy(row))
        for invalid in ("", "guard,", "guard,guard", "missing"):
            with self.subTest(trait_ids=invalid):
                row.trait_ids = invalid
                with self.assertRaises(ValueError):
                    validate_enemy_rows([row], abilities, set(), traits)

    def test_trait_names_are_unique_case_insensitively(self) -> None:
        sys.path.insert(0, str(ROOT / "Scripts"))
        from internal.content.roster import TraitRow, validate_trait_rows

        rows = [TraitRow("guard", "Guard", "Gain Block.", "", "blockPerTurn:1"),
                TraitRow("other", "guard", "Gain Block.", "", "blockPerTurn:1")]
        with self.assertRaisesRegex(ValueError, "trait name"):
            validate_trait_rows(rows)
