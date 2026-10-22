from __future__ import annotations

import re
import sys

from script_test_support import ROOT, ScriptRegressionTestCase, run_captured, run_python


class ContentCodegenTests(ScriptRegressionTestCase):
    def test_manifest_keyword_vocabulary_covers_core_keywords(self) -> None:
        sys.path.insert(0, str(ROOT / "Scripts"))
        from internal.content.content_codegen_modifiers import VALID_KEYWORDS
        source = (ROOT / "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift").read_text()
        cases = set(re.findall(r'^    case (\w+) =', source, re.MULTILINE))
        self.assertEqual(cases, set(VALID_KEYWORDS))

    def test_content_codegen_routes_generation_and_script_tests(self) -> None:
        for path, check in (
            ("Scripts/content_codegen.py", "./Scripts/test-scripts.sh"),
            ("Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityCatalog.swift",
             "./Scripts/test-package.sh TrinketContent"),
        ):
            with self.subTest(path=path):
                result = run_captured([str(ROOT / "Scripts/handoff.sh"), "--dry-run", "--paths", path], cwd=ROOT, env=self.verification_environment(hosted=True), expected=0)
                self.assertIn("./Scripts/generate.sh", result.stdout)
                self.assertIn("./Scripts/assert-generated-output.sh --idempotent", result.stdout)
                self.assertIn(check, result.stdout)

    def test_live_manifests_validate_through_extracted_domains(self) -> None:
        result = run_python('content_codegen.py', "validate", cwd=ROOT, expected=0)
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

    def test_affixes_must_share_a_keyword_with_a_base_of_their_slot(self) -> None:
        sys.path.insert(0, str(ROOT / "Scripts"))
        from internal.content.items import AffixRow, ItemBaseRow, validate_affix_reachability

        base = ItemBaseRow("emerald_ring", "Emerald Ring", "accessory", "", "poison,health")
        reachable = AffixRow(
            "venomous", "Venomous", "accessory", "poison", "8", "b", "a", "", "", "", "",
        )
        orphan = AffixRow(
            "keen", "Keen", "accessory", "physical", "8", "b", "a", "", "", "", "",
        )
        validate_affix_reachability([reachable], [base])
        with self.assertRaisesRegex(ValueError, "shares no keyword"):
            validate_affix_reachability([orphan, reachable], [base])
        with self.assertRaisesRegex(ValueError, "shares no keyword"):
            validate_affix_reachability([reachable], [])

    def test_authored_affix_ranges_reject_missing_fractional_and_out_of_range_fields(self) -> None:
        from dataclasses import replace
        from internal.content.items import AffixRow, validate_affix_rows

        row = AffixRow("test", "Test", "armor", "block", "8", "Gain 4 Block", "Gain 8 Block", "", "",
                       "startBattleBlock:4", "startBattleBlock:8", "startBattleBlock:3:5", "startBattleBlock:6:8")
        validate_affix_rows([row])
        for bounds in ("startBattleBlock:0:5", "startBattleBlock:5:3", "startBattleBlock:3.5:5",
                       "startBattleBlock:1:2", "startBattleBlock:nan:5", "missing:1:2",
                       "startBattleBlock:3:5|startBattleBlock:3:5"):
            with self.subTest(bounds=bounds), self.assertRaises(ValueError):
                validate_affix_rows([replace(row, basic_roll_ranges=bounds)])

    def test_item_manifests_reject_unusable_catalog_entries(self) -> None:
        from dataclasses import replace
        from internal.content.items import ItemBaseRow, validate_item_base_rows

        base = ItemBaseRow("emerald_ring", "Emerald Ring", "accessory", "", "poison,health")
        for overrides in ({"id": ""}, {"id": "invalid-id"}, {"id": "emerald_ring\n"}, {"name": " "},
                          {"keywords": "poison,poison"}, {"keywords": "poison,,health"}):
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                validate_item_base_rows([replace(base, **overrides)])
