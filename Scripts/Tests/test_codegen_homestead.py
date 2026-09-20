from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/homestead.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/trigger_families/*.json',
)


from script_test_support import ScriptRegressionTestCase
from internal.content import common
from internal.content import homestead


class CodegenHomesteadTests(ScriptRegressionTestCase):
    def test_homestead_prerequisite_tier_must_exist(self) -> None:
        with self.assertRaises(ValueError):
            homestead.validate_homestead_prerequisites(
                "wheatField:9", "orchard-tier-1", {"wheatField": {1, 2}}
            )

    def test_homestead_combat_tokens_reject_duplicates_and_bad_bonuses(self) -> None:
        with self.assertRaises(ValueError):
            homestead.parse_homestead_combat_tokens("astral_chance:5|astral_chance:10")
        with self.assertRaises(ValueError):
            homestead.parse_homestead_combat_tokens("astral_chance:many")
        with self.assertRaises(ValueError):
            homestead.parse_homestead_combat_tokens(
                "companion.dodge_chance_bonus:0.02|companion.dodge_chance_bonus:0.04"
            )

    def test_game_icons_require_qualified_sf_symbols(self) -> None:
        for icon_id in ["flame.fill", "other:flame", "lucide:sword", "sf:../flame", "sf:", "sf:flame..fill"]:
            with self.subTest(icon_id=icon_id), self.assertRaises(ValueError):
                common._validate_game_icon(icon_id, "sample")
        common._validate_game_icon("sf:burst.fill", "sample")
    def test_multiple_production_outputs_validate_each_resource(self) -> None:
        self.assertEqual(
            homestead.parse_homestead_production("gems:2|stone:1"),
            "[ResourceAmount(.gems, 2), ResourceAmount(.stone, 1)]",
        )
        for raw in ["gems:1|gems:2", "gems:1|stone:0", "gems:1|unknown:2"]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                homestead.parse_homestead_production(raw)
