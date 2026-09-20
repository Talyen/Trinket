from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/trigger_families/*.json',
)


import json
from pathlib import Path
import tempfile
from unittest.mock import patch

from script_test_support import ScriptRegressionTestCase, load_script
from internal.content import content_codegen_modifiers
from internal.content import content_codegen_triggers


class CodegenTriggersTests(ScriptRegressionTestCase):
    def test_split_schema_rejects_duplicate_fields_and_unsafe_index_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            index = folder / "index.json"
            family = {"family": "sample", "file_stem": "SampleTriggers",
                      "fields": [{"name": "bonus", "type": "Int", "default": "0", "merge": "add"}]}
            (folder / "sample.json").write_text(json.dumps(family))
            with patch.object(content_codegen_triggers, "TRIGGER_FAMILY_SCHEMA", index):
                try:
                    for names in (["../sample.json"], ["sample.json", "sample.json"]):
                        index.write_text(json.dumps({"families": names}))
                        content_codegen_triggers._trigger_families.cache_clear()
                        with self.assertRaises(ValueError):
                            content_codegen_triggers._trigger_families()
                    index.write_text(json.dumps({"families": ["sample.json"]}))
                    family["fields"].append(family["fields"][0])
                    (folder / "sample.json").write_text(json.dumps(family))
                    content_codegen_triggers._trigger_families.cache_clear()
                    with self.assertRaisesRegex(ValueError, "Duplicate"):
                        content_codegen_triggers._trigger_families()
                finally:
                    content_codegen_triggers._trigger_families.cache_clear()

    def test_modifier_schema_rejects_ambiguous_names_and_unsupported_shapes(self) -> None:
        from internal.content.modifier_schema import modifier_definitions
        row = {"token": "maximum_health", "case": "maximumHealth", "type": "Int", "keyword": False}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "modifiers.json"
            for rows in ([row, row], [{**row, "type": "Float"}], [{**row, "keyword": "false"}]):
                path.write_text(json.dumps(rows))
                with self.assertRaises(ValueError):
                    modifier_definitions(path)

    def test_triggers_swift_maps_known_token_to_grouped_field(self) -> None:
        self.assertEqual(
            content_codegen_triggers.triggers_swift("on_cleanse_self_heal:2"),
            "CombatTraitTriggers(healing: HealingTriggers(cleanseSelfHeal: 2))",
        )

    def test_triggers_swift_rename_table_tokens(self) -> None:
        output = content_codegen_triggers.triggers_swift("on_cleanse_draw:1|on_gain_gold_heal:3")
        self.assertIn("cleanseBonusDraw: 1", output)
        self.assertIn("gainGoldBonusHealSelf: 3", output)

    def test_triggers_swift_damage_below_health_percent_both_arities(self) -> None:
        self.assertEqual(
            content_codegen_triggers.triggers_swift("damage_below_health_percent:50:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentBonus: 5))",
        )
        self.assertEqual(
            content_codegen_triggers.triggers_swift("damage_below_health_percent:50:burn:5"),
            "CombatTraitTriggers(damage: DamageTriggers("
            "damageBelowHealthPercentThreshold: 50, damageBelowHealthPercentKeyword: .burn, "
            "damageBelowHealthPercentBonus: 5))",
        )

    def test_triggers_swift_generic_path_converts_snake_case_field(self) -> None:
        self.assertEqual(
            content_codegen_triggers.triggers_swift("poison_decay_slow_percent:50"),
            "CombatTraitTriggers(dot: DotTriggers(poisonDecaySlowPercent: 50))",
        )

    def test_triggers_swift_unknown_token_fails_loudly(self) -> None:
        with self.assertRaises(ValueError):
            content_codegen_triggers.triggers_swift("not_a_real_trigger:1")

    def test_triggers_swift_rejects_glued_tokens(self) -> None:
        with self.assertRaises(ValueError):
            content_codegen_triggers.triggers_swift("poison_decay_slow_percent:50,bogus_field:1")

    def test_triggers_swift_rejects_duplicate_fields(self) -> None:
        for tokens in (
            "block_per_turn:1|block_per_turn:2",
            "cards_played_mana:2:3|cards_played_mana:4:5",
            "on_cleanse_draw:1|cleanseBonusDraw:2",
            "on_cleanse_draw:1|cleanse_bonus_draw:2",
            "cards_played_mana:2:3|cardsPlayedManaFlat:4",
        ):
            for value in (tokens, "|".join(reversed(tokens.split("|")))):
                with self.subTest(value=value), self.assertRaisesRegex(ValueError, "Duplicate trigger field"):
                    content_codegen_triggers.triggers_swift(value)

    def test_triggers_swift_rejects_badly_typed_values(self) -> None:
        for token in [
            "block_per_turn:foo",
            "first_hit_double_damage:banana",
            "damage_below_health_percent:50:shadow:5",
            "turn_random_damage_all_enemies:burn:shadow",
            "bonusManaOnTurns:[1, banana]",
        ]:
            with self.subTest(token=token), self.assertRaises(ValueError):
                content_codegen_triggers.triggers_swift(token)

    def test_triggers_swift_bespoke_arity_errors_name_expected_shape(self) -> None:
        for token in [
            "damage_below_health_percent:50",
            "damage_below_health_percent:1:2:3:4",
            "once_below_health_percent_heal:10",
            "dodge_chance_below_health_percent:10",
            "turn_random_damage_all_enemies:burn:5",
            "cards_played_mana:1:2:3",
        ]:
            with self.subTest(token=token):
                with self.assertRaises(ValueError) as ctx:
                    content_codegen_triggers.triggers_swift(token)
                self.assertIn("expects", str(ctx.exception))

    def test_trigger_alias_targets_exist_in_schema(self) -> None:
        triggers = load_script("internal.content.content_codegen_triggers", "internal/content/content_codegen_triggers.py")
        names = {
            field["name"]
            for family in content_codegen_triggers._trigger_families()
            for field in family["fields"]
        }
        for token, field in list(triggers._TRIGGER_SIMPLE_MAP.items()) + list(
            triggers._FLAG_TRIGGERS.items()
        ):
            self.assertIn(field, names, f"alias {token!r} targets unknown field")
        for prefix, (_, arities) in triggers._BESPOKE_TRIGGER_SPECS.items():
            for fields in arities.values():
                for field, _ in fields:
                    self.assertIn(field, names, f"bespoke {prefix!r} sets unknown field")

    def test_modifiers_swift_rejects_duplicates_and_bad_amounts(self) -> None:
        with self.assertRaises(ValueError):
            content_codegen_modifiers.modifiers_swift("maximum_health:4|maximum_health:8", "sample")
        with self.assertRaises(ValueError):
            content_codegen_modifiers.modifiers_swift("damage_dealt:burn:1|damage_dealt:burn:2", "sample")
        for token in ["maximum_health:foo", "outgoing_damage_percent:foo", "damage_dealt:burn:foo"]:
            with self.subTest(token=token), self.assertRaises(ValueError):
                content_codegen_modifiers.modifiers_swift(token, "sample")

    def test_modifier_token_to_swift_multipart_keyword(self) -> None:
        self.assertEqual(
            content_codegen_modifiers.modifier_token_to_swift("damage_dealt:burn:3"),
            ".damageDealt(.burn, 3)",
        )

    def test_modifier_token_to_swift_rejects_unknown_keyword(self) -> None:
        with self.assertRaises(ValueError):
            content_codegen_modifiers.modifier_token_to_swift("damage_dealt:shadow:3")
        with self.assertRaises(ValueError):
            content_codegen_modifiers.modifier_token_to_swift("damage_taken_percent:arcane:0.2")

    def test_modifier_token_to_swift_rejects_malformed_token(self) -> None:
        with self.assertRaises(ValueError):
            content_codegen_modifiers.modifier_token_to_swift("damage_dealt:fire")

    def test_affix_policies_preserve_seeded_order_and_require_explicit_classification(self) -> None:
        import hashlib
        from internal.content.affix_rolling import rolling_policies, validate_affix_rolling, generate_affix_rolling
        from internal.content import affix_rolling
        families = content_codegen_triggers._trigger_families()
        policies = rolling_policies(families)
        ordered = sorted(((name, policy) for name, policy in policies.items() if 'order' in policy),
                         key=lambda row: row[1]['order'])
        # Frozen pre-migration order/type sequence: existing seeded rolls must not
        # change when the declaration list becomes generated. New fields append.
        baseline = '\n'.join(f'{policy["kind"]}:{name}' for name, policy in ordered[:59])
        self.assertEqual(hashlib.sha256(baseline.encode()).hexdigest(),
                         '0a8b6702d8b445345f702919422def283377f84d3022c6d01e9a6fbf3db8526b')
        validate_affix_rolling('onBleedApplyPoison:1|onBleedDealPoisonChancePercent:20', 'infected')
        with self.assertRaisesRegex(ValueError, 'explicit affix_roll'):
            validate_affix_rolling('ghostfrost:true', 'unclassified')
        with tempfile.TemporaryDirectory() as directory, patch.object(affix_rolling, 'GENERATED_DIR', Path(directory)):
            generate_affix_rolling(families)
            output = Path(directory) / 'AffixRolling.generated.swift'
            before = output.read_bytes()
            generate_affix_rolling(families)
            self.assertEqual(before, output.read_bytes())
            self.assertIn('.int(\\.onBleedApplyPoison, name: "onBleedApplyPoison")', before.decode())
            self.assertIn('"sunderingBlockMultiplier":', before.decode())
        for policy in ({'reason': ''}, {'kind': 'percent', 'order': 0}, {'kind': 'int', 'order': -1},
                       {'kind': 'int', 'order': 0, 'reason': 'ambiguous'}):
            with self.subTest(policy=policy), self.assertRaises(ValueError):
                rolling_policies([{'fields': [{'name': 'value', 'type': 'Int', 'affix_roll': policy}]}])
