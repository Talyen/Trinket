from __future__ import annotations

from script_test_support import ScriptRegressionTestCase, load_script
from internal.content import content_codegen_modifiers
from internal.content import content_codegen_triggers


class CodegenTriggersTests(ScriptRegressionTestCase):
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
