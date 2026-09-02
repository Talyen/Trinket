#!/usr/bin/env python3
"""Trigger-DSL ownership for content codegen (extracted from content_codegen.py)."""

from __future__ import annotations

import functools
import json
import re
from pathlib import Path

TRIGGER_FAMILY_SCHEMA = Path(__file__).resolve().parent / "trigger_family_schema.json"


@functools.cache
def _trigger_families() -> list:
    payload = json.loads(TRIGGER_FAMILY_SCHEMA.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        families = payload.get("families", payload)
        if isinstance(families, list):
            return families
    return payload


def parse_trigger_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


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


def triggers_swift(raw: str) -> str:
    families = _trigger_families()
    field_group = {
        field["name"]: family["family"]
        for family in families
        for field in family["fields"]
    }
    known_fields = set(field_group)
    values: dict[str, str] = {}
    for token in parse_trigger_tokens(raw):
        if _apply_simple_trigger(token, values):
            continue
        if token.startswith("damage_below_health_percent:"):
            parts = token.split(":")
            if len(parts) == 4:
                _, threshold, keyword, bonus = parts
                values["damageBelowHealthPercentThreshold"] = threshold
                values["damageBelowHealthPercentKeyword"] = f".{keyword}"
                values["damageBelowHealthPercentBonus"] = bonus
            else:
                _, threshold, bonus = parts
                values["damageBelowHealthPercentThreshold"] = threshold
                values["damageBelowHealthPercentBonus"] = bonus
            continue
        if token.startswith("once_below_health_percent_heal:"):
            _, threshold, amount = token.split(":", 2)
            values["onceBelowHealthPercentThreshold"] = threshold
            values["onceBelowHealthPercentHeal"] = amount
            continue
        if token.startswith("dodge_chance_below_health_percent:"):
            _, threshold, bonus = token.split(":", 2)
            values["dodgeChanceBelowHealthPercentThreshold"] = threshold
            values["dodgeChanceBelowHealthPercentBonus"] = bonus
            continue
        if token.startswith("turn_random_damage_all_enemies:"):
            parts = token.split(":")
            if len(parts) != 4:
                raise ValueError(
                    "turn_random_damage_all_enemies expects keyword:keyword:amount, "
                    f"got {token!r}"
                )
            _, keyword_a, keyword_b, amount = parts
            values["turnRandomDamageAllEnemiesKeywordA"] = f".{keyword_a}"
            values["turnRandomDamageAllEnemiesKeywordB"] = f".{keyword_b}"
            values["turnRandomDamageAllEnemiesAmount"] = amount
            continue
        if token.startswith("cards_played_mana:"):
            _, threshold, amount = token.split(":", 2)
            values["cardsPlayedManaThreshold"] = threshold
            values["cardsPlayedManaFlat"] = amount
            continue
        else:
            field, separator, value = token.partition(":")
            if not separator:
                raise ValueError(f"Unknown trigger token: {token}")
            if "_" in field:
                parts = field.split("_")
                field = parts[0] + "".join(part.title() for part in parts[1:])
            if field not in known_fields:
                raise ValueError(f"Unknown trigger token: {token}")
            if re.search(r",[A-Za-z_][A-Za-z0-9_]*:", value):
                raise ValueError(
                    f"Glued trigger token {token!r}; separate fields with |"
                )
            values[field] = value
    group_order = [family["family"] for family in families]
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
        gtype = "".join(p.capitalize() for p in re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+", g)) + "Triggers"
        inner = ", ".join(f"{label}: {values[label]}" for label in fields)
        parts.append(f"{g}: {gtype}({inner})")
    if not parts:
        return "CombatTraitTriggers()"
    return "CombatTraitTriggers(" + ", ".join(parts) + ")"
