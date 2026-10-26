from __future__ import annotations

from dataclasses import replace

from script_test_support import ScriptRegressionTestCase
from internal.content import common, homestead, talents


class ContentBoundaryRegressionTests(ScriptRegressionTestCase):
    def test_authored_quantities_fit_the_generated_swift_int(self) -> None:
        maximum = (1 << 63) - 1
        common._validate_positive_int("max_health", str(maximum), "ranger", minimum=1)
        self.assertEqual(common.parse_material_tokens(f"wood:+{maximum}"), [("wood", maximum)])
        for number in (maximum + 1, 1 << 100):
            with self.subTest(number=number):
                with self.assertRaisesRegex(ValueError, "fit a Swift Int"):
                    common._validate_positive_int("max_health", str(number), "ranger")
                with self.assertRaisesRegex(ValueError, "fit a Swift Int"):
                    common.parse_material_tokens(f"wood:{number}")
        for raw in ("1_000", "+1", " 1 "):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                common._validate_positive_int("max_health", raw, "ranger")
        with self.assertRaises(ValueError):
            common.parse_material_tokens("wood:1_000")

    def test_homestead_shared_scope_cannot_duplicate_either_recipient(self) -> None:
        for raw in (
            "maximum_health:2|hero.maximum_health:3",
            "hero.maximum_health:3|maximum_health:2",
            "maximum_health:2|companion.maximum_health:3",
            "companion.maximum_health:3|maximum_health:2",
        ):
            with self.subTest(raw=raw), self.assertRaisesRegex(ValueError, "Duplicate homestead bonus"):
                homestead.parse_homestead_combat_tokens(raw)
        hero, companion, _ = homestead.parse_homestead_combat_tokens(
            "hero.maximum_health:2|companion.maximum_health:3"
        )
        self.assertEqual(hero, [".maximumHealth(2)"])
        self.assertEqual(companion, [".maximumHealth(3)"])
        hero, companion, _ = homestead.parse_homestead_combat_tokens("maximum_health:2")
        self.assertEqual(hero, companion)

    def test_talent_identity_and_layout_match_runtime_tree_lookup(self) -> None:
        rows = [talents.TalentRow(
            id=f"ranger_poison_t{row}_{slot}", name="Talent", icon_id="sf:leaf.fill",
            description="Deal Poison damage", modifiers="", triggers="",
        ) for row, slot in [(row, slot) for row in range(1, 4) for slot in (1, 2)] + [(4, 1)]]
        talents.validate_talent_rows(rows, ["ranger"])
        talents.validate_talent_rows(rows + [replace(rows[-1], id="ranger_poison_t4_2")], ["ranger"])
        invalid = [
            rows[1:],
            rows[:-1],
            [replace(rows[0], id="ranger_poison_t99_1"), *rows[1:]],
            [replace(rows[0], id="ranger_poison_t1_3"), *rows[1:]],
            [replace(rows[0], id="ranger_missing_t1_1"), *rows[1:]],
            rows + [replace(rows[-1], id="ranger_poison_t6_1")],
            [],
        ]
        for candidate in invalid:
            with self.subTest(ids=[row.id for row in candidate]), self.assertRaises(ValueError):
                talents.validate_talent_rows(candidate, ["ranger"])
