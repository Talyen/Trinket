#!/usr/bin/env python3
"""Trigger-DSL ownership for content codegen (extracted from content_codegen.py)."""

from __future__ import annotations

import functools
import json
import math
import re
from pathlib import Path

TRIGGER_FAMILY_SCHEMA = Path(__file__).resolve().parent / "trigger_family_schema.json"


@functools.cache
def _trigger_families() -> list:
    payload = json.loads(TRIGGER_FAMILY_SCHEMA.read_text(encoding="utf-8"))
    return payload["families"]


from .content_codegen_modifiers import VALID_KEYWORDS, parse_modifier_tokens as parse_trigger_tokens


_TRIGGER_SIMPLE_MAP: dict[str, str] = {
    "on_cleanse_draw": "cleanseBonusDraw",
    "on_cleanse_self_heal": "cleanseSelfHeal",
    "on_cleanse_heal": "cleanseBonusHeal",
    "on_gain_gold_heal": "gainGoldBonusHealSelf",
    "dodge_chance_bonus": "dodgeChanceBonus",
    "passive_mitigation": "passiveMitigationFlat",
    "thorns_percent": "thornsPercent",
    "burn_decay_slow": "burnDecaySlowPercent",
    "on_bleed_apply_poison": "onBleedApplyPoison",
    "on_burn_apply_poison": "onBurnApplyPoison",
    "on_bleed_deal_burn_damage": "onBleedDealBurnDamage",
    "poison_decay_increase_chance": "poisonDecayIncreaseChance",
    "freeze_damage_while_burning": "freezeDamageWhileBurningBonus",
    "damage_while_target_frozen": "damageWhileTargetFrozenBonus",
    "damage_after_dodge": "damageAfterDodgeBonus",
    "on_block_broken_block": "blockBrokenBlockFlat",
    "companion_leech_share_percent": "companionLeechSharePercent",
    "block_on_deaths_door": "blockOnDeathsDoor",
    "on_spend_mana_block": "spendManaBlockFlat",
    "on_spend_mana_random_dot": "spendManaRandomDoTFlat",
    "on_holy_damage_block": "holyDamageBlockFlat",
    "on_stun_damage_block": "stunDamageBlockFlat",
    "on_holy_damage_cleanse": "holyDamageCleanseCount",
    "on_holy_damage_heal": "holyDamageHealFlat",
    "on_burn_damage_heal": "burnDamageHealFlat",
    "on_dodge_gold": "dodgeGoldFlat",
    "ignore_enemy_mitigation_percent": "ignoreEnemyMitigationPercent",
    "on_stun_deal_physical": "stunDealPhysicalFlat",
    "damage_while_target_stunned": "damageWhileTargetStunnedBonus",
    "on_enemy_stunned_apply_marked": "enemyStunnedApplyMarked",
    "on_dodge_block": "dodgeBlockFlat",
    "on_dodge_apply_poison": "dodgeApplyPoison",
    "on_holy_damage_purge": "holyDamagePurgeCount",
    "once_death_revive_health": "onceDeathReviveHealth",
    "once_death_revive_block": "onceDeathReviveBlock",
    "on_enemy_stunned_purge": "enemyStunnedPurgeCount",
    "on_critical_purge": "criticalPurgeCount",
    "on_critical_gold": "criticalGoldFlat",
    "on_critical_action_gold": "criticalActionGoldFlat",
    "on_leech_restore_mana": "leechRestoreManaFlat",
    "on_gain_mana_block": "gainManaBlockFlat",
    "on_defeat_enemy_gold": "defeatEnemyGoldFlat",
    "on_leech_gold": "leechGoldFlat",
    "on_dodge_heal": "dodgeHealFlat",
    "on_dodge_deal_stun": "dodgeDealStunFlat",
    "block_per_turn": "blockPerTurn",
    "leech_chance": "leechChancePercent",
    "on_hit_attacker_burn": "onHitAttackerBurn",
    "turn_freeze_all_enemies": "turnFreezeDamageAllEnemies",
    "on_holy_damage_poison": "holyDamagePoisonFlat",
    "draw_every_other_turn": "drawEveryOtherTurn",
    "draw_on_health_loss": "drawOnHealthLoss",
    "physical_stun_buildup_percent": "physicalStunBuildupPercent",
    "block_gain_thorns_percent": "blockGainThornsPercent",
    "draw_on_spend_mana": "drawOnSpendMana",
    "physical_damage_block_percent": "physicalDamageBlockPercent",
    "on_bleed_damage_gold": "bleedDamageGoldFlat",
    "gold_per_turn": "goldPerTurn",
    "health_restored_poison_percent": "healthRestoredPoisonPercent",
    "sundering_block_multiplier": "sunderingBlockMultiplier",
    "victory_gold_flat": "victoryGoldFlat",
    "health_per_turn": "healthPerTurn",
    "companion_cards_per_turn": "companionCardsPerTurn",
    "freeze_extra_action_skips": "freezeExtraActionSkips",
    "stunned_damage_multiplier": "stunnedDamageMultiplier",
    "critical_chance_bonus": "criticalChanceBonus",
}

_FLAG_TRIGGERS: dict[str, str] = {
    "on_enemy_stunned_purge_all": "enemyStunnedPurgeAll",
    "on_critical_purge_all": "criticalPurgeAll",
    "first_hit_double_damage": "firstHitDoubleDamage",
    "repeat_mana_empowerment": "repeatManaEmpowerment",
    "freeze_damage_leech": "freezeDamageLeech",
    "poison_damage_leech": "poisonDamageLeech",
    "victory_gold_coin": "victoryGoldCoin",
}


def _apply_simple_trigger(token: str, values: dict[str, str]) -> bool:
    for prefix, field in _TRIGGER_SIMPLE_MAP.items():
        if token.startswith(prefix + ":"):
            values[field] = token.split(":", 1)[1]
            return True
    for prefix, field in _FLAG_TRIGGERS.items():
        if token == prefix or token.startswith(prefix + ":"):
            if ":" in token:
                remainder = token.split(":", 1)[1].strip()
                values[field] = "true" if not remainder or remainder.lower() in ("true", "1") else remainder
            else:
                values[field] = "true"
            return True
    return False


_BESPOKE_TRIGGER_SPECS: dict[str, tuple[str, dict[int, tuple[tuple[str, bool], ...]]]] = {
    "damage_below_health_percent": (
        "threshold[:keyword]:bonus",
        {
            2: (
                ("damageBelowHealthPercentThreshold", False),
                ("damageBelowHealthPercentBonus", False),
            ),
            3: (
                ("damageBelowHealthPercentThreshold", False),
                ("damageBelowHealthPercentKeyword", True),
                ("damageBelowHealthPercentBonus", False),
            ),
        },
    ),
    "once_below_health_percent_heal": (
        "threshold:amount",
        {
            2: (
                ("onceBelowHealthPercentThreshold", False),
                ("onceBelowHealthPercentHeal", False),
            ),
        },
    ),
    "dodge_chance_below_health_percent": (
        "threshold:bonus",
        {
            2: (
                ("dodgeChanceBelowHealthPercentThreshold", False),
                ("dodgeChanceBelowHealthPercentBonus", False),
            ),
        },
    ),
    "turn_random_damage_all_enemies": (
        "keyword:keyword:amount",
        {
            3: (
                ("turnRandomDamageAllEnemiesKeywordA", True),
                ("turnRandomDamageAllEnemiesKeywordB", True),
                ("turnRandomDamageAllEnemiesAmount", False),
            ),
        },
    ),
    "cards_played_mana": (
        "threshold:amount",
        {
            2: (
                ("cardsPlayedManaThreshold", False),
                ("cardsPlayedManaFlat", False),
            ),
        },
    ),
}


def _apply_bespoke_trigger(token: str, values: dict[str, str]) -> bool:
    for prefix, (usage, arities) in _BESPOKE_TRIGGER_SPECS.items():
        if not token.startswith(prefix + ":"):
            continue
        args = token.split(":")[1:]
        if len(args) not in arities:
            raise ValueError(f"{prefix} expects {usage}, got {token!r}")
        for (field, is_keyword), arg in zip(arities[len(args)], args):
            if is_keyword:
                if arg not in VALID_KEYWORDS:
                    raise ValueError(f"Unknown keyword {arg!r} in trigger token {token!r}")
                values[field] = f".{arg}"
            else:
                values[field] = arg
        return True
    return False


@functools.cache
def _trigger_schema_info() -> tuple[dict[str, str], list[str], dict[str, str]]:
    families = _trigger_families()
    field_group = {
        field["name"]: family["family"]
        for family in families
        for field in family["fields"]
    }
    group_order = [family["family"] for family in families]
    family_types = {family["family"]: family["file_stem"] for family in families}
    return field_group, group_order, family_types


@functools.cache
def _trigger_field_types() -> dict[str, str]:
    return {
        field["name"]: field["type"]
        for family in _trigger_families()
        for field in family["fields"]
    }


def _validate_trigger_value(field: str, raw_value: str, row_id: str) -> None:
    field_type = _trigger_field_types().get(field)
    if field_type is None:
        raise ValueError(f"Unknown trigger field: {field}")
    value = raw_value.strip()
    if field_type == "Int":
        try:
            int(value)
        except ValueError as error:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be an integer, got {raw_value!r}"
            ) from error
    elif field_type == "Double":
        try:
            parsed = float(value)
        except ValueError as error:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be a number, got {raw_value!r}"
            ) from error
        if not math.isfinite(parsed):
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be a finite number"
            )
    elif field_type == "Bool":
        if value not in ("true", "false"):
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be true or false, "
                f"got {raw_value!r}; drop the token for false"
            )
    elif field_type == "Keyword?":
        if not value.startswith(".") or value[1:] not in VALID_KEYWORDS:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be a known keyword, "
                f"got {raw_value!r}"
            )
    elif field_type == "[Int]":
        inner = value[1:-1] if value.startswith("[") and value.endswith("]") else None
        if inner is None:
            raise ValueError(
                f"Trigger value for {field} for {row_id} must be an integer list like [1, 4], "
                f"got {raw_value!r}"
            )
        for part in inner.split(","):
            if not part.strip():
                continue
            try:
                int(part.strip())
            except ValueError as error:
                raise ValueError(
                    f"Trigger value for {field} for {row_id} must be an integer list, "
                    f"got {raw_value!r}"
                ) from error


def triggers_swift(raw: str, row_id: str = "") -> str:
    field_group, group_order, family_types = _trigger_schema_info()
    known_fields = set(field_group)
    label = row_id or "triggers"
    seen_fields: dict[str, str] = {}
    values: dict[str, str] = {}
    for token in parse_trigger_tokens(raw):
        resolved: dict[str, str] = {}
        if not (_apply_simple_trigger(token, resolved) or _apply_bespoke_trigger(token, resolved)):
            field, separator, value = token.partition(":")
            if not separator:
                raise ValueError(f"Unknown trigger token: {token}")
            if "_" in field:
                parts = field.split("_")
                field = parts[0] + "".join(part.title() for part in parts[1:])
            if field not in known_fields:
                raise ValueError(f"Unknown trigger token: {token}")
            if re.search(r",[A-Za-z_][A-Za-z0-9_]*:", value):
                raise ValueError(f"Glued trigger token {token!r}; separate fields with |")
            resolved[field] = value
        for field in resolved:
            if field in seen_fields:
                raise ValueError(
                    f"Duplicate trigger field {field!r} for {label}: "
                    f"{token!r} repeats {seen_fields[field]!r}; merge into one token"
                )
            seen_fields[field] = token
        values.update(resolved)
    for field, raw_value in values.items():
        _validate_trigger_value(field, raw_value, label)
    grouped: dict[str, list[str]] = {g: [] for g in group_order}
    for label in values:
        try:
            grouped[field_group[label]].append(label)
        except KeyError as error:
            raise ValueError(f"Unknown trigger field: {label}") from error
    parts = []
    for g in group_order:
        fields = grouped[g]
        if not fields:
            continue
        gtype = family_types[g]
        inner = ", ".join(f"{label}: {values[label]}" for label in fields)
        parts.append(f"{g}: {gtype}({inner})")
    if not parts:
        return "CombatTraitTriggers()"
    return "CombatTraitTriggers(" + ", ".join(parts) + ")"
