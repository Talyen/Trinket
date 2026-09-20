from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/talents.py',
    'Scripts/internal/content/trigger_families/*.json',
)


from script_test_support import ScriptRegressionTestCase
from internal.content import talents


class CodegenTalentsTests(ScriptRegressionTestCase):
    def test_talent_validation_requires_known_combatant(self) -> None:
        row = talents.TalentRow(
            id="unknown_hero_burn_t1_1",
            name="Flame",
            icon_id="sf:flame.fill",
            description="Burns target",
            modifiers="",
            triggers="",
        )
        with self.assertRaises(ValueError):
            talents.validate_talent_rows([row], combatant_ids=["knight", "ranger"])
