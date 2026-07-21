#!/usr/bin/env python3
"""Generate Trinket content catalogs from ContentManifest TSV files."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_DIR = ROOT / "ContentManifest"
GENERATED_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Generated"
CONTENT_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Content"

TIER_ENUM = {
    "basic": "AbilityCatalogBasicGenerated",
    "skill": "AbilityCatalogSkillGenerated",
    "ultimate": "AbilityCatalogUltimateGenerated",
}

TIER_SOURCE = {
    "basic": CONTENT_DIR / "AbilityCatalogBasic.swift",
    "skill": CONTENT_DIR / "AbilityCatalogSkill.swift",
    "ultimate": CONTENT_DIR / "AbilityCatalogUltimate.swift",
}

VALID_SLOTS = frozenset({"weapon", "armor", "trinket"})
VALID_TIERS = frozenset({"basic", "skill", "ultimate"})
VALID_PATTERNS = frozenset({"direct_hit", "buff_only", "multi_damage"})
VALID_ENCOUNTERS = frozenset({"battle", "event", "shop", "rest", "mystery", "recruit"})
VALID_CHAPTER_THEMES = frozenset({"verdantForest"})
VALID_HOMESTEAD_RESOURCES = frozenset(
    {"wood", "stone", "iron", "food", "herbs", "hide", "crystal", "gold"}
)
VALID_HOMESTEAD_TINTS = frozenset(
    {"orange", "green", "yellow", "mint", "cyan", "indigo", "blue"}
)
VALID_HOMESTEAD_CATEGORIES = frozenset(
    {"farming", "crafting", "alchemy", "training", "arcana"}
)
VALID_HOMESTEAD_NODE_IDS = frozenset(
    {
        "wheatField",
        "herbGarden",
        "chickenCoop",
        "pasture",
        "culinaryArts",
        "blacksmithForge",
        "woolTailoring",
        "alchemyLab",
        "botanicalDistillation",
        "crystalGarden",
        "runesmithWorkshop",
        "hunterLodge",
        "agilityTraining",
        "detectMagic",
        "wishingWell",
    }
)
VALID_KEYWORDS = frozenset(
    {
        "physical",
        "bleed",
        "burn",
        "freeze",
        "poison",
        "holy",
        "stun",
        "health",
        "block",
        "armor",
        "leech",
        "gold",
        "mana",
        "dodge",
        "purge",
    }
)
SWIFT_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
KEBAB_IDENTIFIER = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SNAKE_IDENTIFIER = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
VALID_ROLES = frozenset({"hero", "companion"})
VALID_GROWTH_ARCHETYPES = frozenset({"tank", "assassin", "mage", "support", "bruiser"})


@dataclass
class AffixRow:
    id: str
    title: str
    slot: str
    keywords: str
    weight: str
    basic_description: str
    astral_description: str
    basic_modifiers: str
    astral_modifiers: str
    basic_triggers: str
    astral_triggers: str


@dataclass
class AbilityRow:
    pattern: str
    symbol: str
    id: str
    name: str
    tier: str
    amount: str = ""
    keyword: str = ""
    description: str = ""
    effects: str = ""
    damage_components: str = ""
    extras: str = ""
    leech: str = ""


@dataclass
class StageRow:
    chapter_id: str
    chapter_number: str
    chapter_title: str
    theme: str
    stage_number: str
    flavor_text: str
    encounter: str
    enemy_id: str
    encounter_art_id: str = ""
    encounter_art_title: str = ""


@dataclass
class ItemBaseRow:
    id: str
    name: str
    slot: str
    keywords: str


@dataclass
class TraitRow:
    id: str
    name: str
    description: str
    modifiers: str
    triggers: str


@dataclass
class CombatantRow:
    id: str
    name: str
    role: str
    max_health: str
    max_mana: str
    growth_archetype: str
    basics: str
    skills: str
    ultimates: str
    strength: str
    agility: str
    toughness: str
    intellect: str
    wisdom: str
    trait_id: str


@dataclass
class EnemyRow:
    id: str
    name: str
    max_health: str
    is_boss: str
    growth_archetype: str
    abilities: str
    strength: str
    agility: str
    toughness: str
    intellect: str
    wisdom: str
    positive_trait_id: str
    negative_trait_id: str


@dataclass
class HomesteadNodeRow:
    node_id: str
    title: str
    summary: str
    symbol_name: str
    tint: str
    category: str
    prerequisites: str
    tier: str
    cost: str
    bonus_title: str
    bonus_description: str


def read_tsv(path: Path) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        rows.append(line.split("\t"))
    return rows


def parse_affix_rows() -> list[AffixRow]:
    path = MANIFEST_DIR / "affixes.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "id",
        "title",
        "slot",
        "keywords",
        "weight",
        "basic_description",
        "astral_description",
        "basic_modifiers",
        "astral_modifiers",
        "basic_triggers",
        "astral_triggers",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    return [AffixRow(*row) for row in lines[1:]]


def parse_trait_rows() -> list[TraitRow]:
    path = MANIFEST_DIR / "traits.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = ["id", "name", "description", "modifiers", "triggers"]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    return [TraitRow(*row) for row in lines[1:]]


def parse_ability_rows() -> list[AbilityRow]:
    path = MANIFEST_DIR / "abilities.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "pattern",
        "symbol",
        "id",
        "name",
        "tier",
        "amount",
        "keyword",
        "description",
        "effects",
        "damage_components",
        "extras",
        "leech",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[AbilityRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(AbilityRow(*padded[: len(expected)]))
    return rows


def parse_stage_rows() -> list[StageRow]:
    path = MANIFEST_DIR / "stages.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "chapter_id",
        "chapter_number",
        "chapter_title",
        "theme",
        "stage_number",
        "flavor_text",
        "encounter",
        "enemy_id",
        "encounter_art_id",
        "encounter_art_title",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[StageRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(StageRow(*padded[: len(expected)]))
    return rows


def parse_item_base_rows() -> list[ItemBaseRow]:
    path = MANIFEST_DIR / "item_bases.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = ["id", "name", "slot", "keywords"]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    return [ItemBaseRow(*row) for row in lines[1:]]


def parse_combatant_rows() -> list[CombatantRow]:
    path = MANIFEST_DIR / "combatants.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "id",
        "name",
        "role",
        "max_health",
        "max_mana",
        "growth_archetype",
        "basics",
        "skills",
        "ultimates",
        "strength",
        "agility",
        "toughness",
        "intellect",
        "wisdom",
        "trait_id",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[CombatantRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(CombatantRow(*padded[: len(expected)]))
    return rows


def parse_enemy_rows() -> list[EnemyRow]:
    path = MANIFEST_DIR / "enemies.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "id",
        "name",
        "max_health",
        "is_boss",
        "growth_archetype",
        "abilities",
        "strength",
        "agility",
        "toughness",
        "intellect",
        "wisdom",
        "positive_trait_id",
        "negative_trait_id",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[EnemyRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(EnemyRow(*padded[: len(expected)]))
    return rows


def parse_homestead_node_rows() -> list[HomesteadNodeRow]:
    path = MANIFEST_DIR / "homestead_nodes.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = [
        "node_id",
        "title",
        "summary",
        "symbol_name",
        "tint",
        "category",
        "prerequisites",
        "tier",
        "cost",
        "bonus_title",
        "bonus_description",
    ]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list[HomesteadNodeRow] = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(HomesteadNodeRow(*padded[: len(expected)]))
    return rows


def swift_escape(value: str) -> str:
    value = value.replace("\\n", "\n")
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def parse_keywords(raw: str) -> str:
    if not raw:
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f".{part}" for part in parts) + "]"


def parse_modifier_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


def modifier_token_to_swift(token: str) -> str:
    if token.startswith("strength:"):
        return f".strength({token.split(':', 1)[1]})"
    if token.startswith("agility:"):
        return f".agility({token.split(':', 1)[1]})"
    if token.startswith("toughness:"):
        return f".toughness({token.split(':', 1)[1]})"
    if token.startswith("intellect:"):
        return f".intellect({token.split(':', 1)[1]})"
    if token.startswith("wisdom:"):
        return f".wisdom({token.split(':', 1)[1]})"
    if token.startswith("maximum_health:"):
        return f".maximumHealth({token.split(':', 1)[1]})"
    if token.startswith("damage_dealt:"):
        _, keyword, amount = token.split(":", 2)
        return f".damageDealt(.{keyword}, {amount})"
    if token.startswith("health_restored:"):
        return f".healthRestored({token.split(':', 1)[1]})"
    if token.startswith("leech_gained_percent:"):
        return f".leechGainedPercent({token.split(':', 1)[1]})"
    if token.startswith("leech_healing:"):
        return f".leechHealing({token.split(':', 1)[1]})"
    if token.startswith("gold_gained:"):
        return f".goldGained({token.split(':', 1)[1]})"
    if token.startswith("block_gained:"):
        return f".blockGained({token.split(':', 1)[1]})"
    if token.startswith("bleed_duration:"):
        return f".bleedDuration({token.split(':', 1)[1]})"
    if token.startswith("damage_taken_percent:"):
        _, keyword, amount = token.split(":", 2)
        return f".damageTakenPercent(.{keyword}, {amount})"
    if token.startswith("damage_taken_vulnerability:"):
        _, keyword, amount = token.split(":", 2)
        return f".damageTakenVulnerability(.{keyword}, {amount})"
    if token.startswith("companion_damage_dealt:"):
        return f".companionDamageDealt({token.split(':', 1)[1]})"
    if token.startswith("maximum_mana:"):
        return f".maximumMana({token.split(':', 1)[1]})"
    if token.startswith("leech_duration:"):
        return f".leechDuration({token.split(':', 1)[1]})"
    if token.startswith("mana_cost_reduction_percent:"):
        return f".manaCostReductionPercent({token.split(':', 1)[1]})"
    raise ValueError(f"Unknown modifier token: {token}")


def parse_trigger_tokens(raw: str) -> list[str]:
    if not raw:
        return []
    return [part.strip() for part in raw.split("|") if part.strip()]


def triggers_swift(raw: str) -> str:
    values: dict[str, str] = {}
    for token in parse_trigger_tokens(raw):
        if token.startswith("on_cleanse_heal:"):
            values["cleanseBonusHeal"] = token.split(":", 1)[1]
        elif token.startswith("on_gain_gold_heal:"):
            values["gainGoldBonusHealSelf"] = token.split(":", 1)[1]
        elif token.startswith("on_restore_health_heal_hero:"):
            values["restoreHealthAlsoHealHero"] = token.split(":", 1)[1]
        elif token.startswith("control_resistance:"):
            values["controlResistancePercent"] = token.split(":", 1)[1]
        elif token.startswith("dodge_chance_bonus:"):
            values["dodgeChanceBonus"] = token.split(":", 1)[1]
        elif token.startswith("physical_dodge_chance_bonus:"):
            values["physicalDodgeChanceBonus"] = token.split(":", 1)[1]
        elif token.startswith("ambush_bonus:"):
            values["ambushBonusDamage"] = token.split(":", 1)[1]
        elif token.startswith("regeneration:"):
            _, amount, interval = token.split(":", 2)
            values["regenerationAmount"] = amount
            values["regenerationIntervalTicks"] = interval
        elif token.startswith("passive_mitigation:"):
            values["passiveMitigationFlat"] = token.split(":", 1)[1]
        elif token.startswith("thorns_percent:"):
            values["thornsPercent"] = token.split(":", 1)[1]
        elif token.startswith("cannot_be_healed:"):
            values["cannotBeHealed"] = "true"
        elif token.startswith("burn_decay_slow:"):
            values["burnDecaySlowPercent"] = token.split(":", 1)[1]
        elif token.startswith("shield_erosion_on:"):
            _, keyword, ticks = token.split(":", 2)
            values["shieldErosionKeyword"] = f".{keyword}"
            values["shieldErosionTicks"] = ticks
        elif token.startswith("mitigation_shred_on:"):
            _, keyword, multiplier, duration = token.split(":", 3)
            values["mitigationShredKeyword"] = f".{keyword}"
            values["mitigationShredMultiplier"] = multiplier
            values["mitigationShredDurationTicks"] = duration
        elif token.startswith("freeze_control_vulnerability:"):
            values["freezeControlVulnerabilityPercent"] = token.split(":", 1)[1]
        elif token.startswith("mitigation_effectiveness_penalty:"):
            values["mitigationEffectivenessPenaltyPercent"] = token.split(":", 1)[1]
        elif token.startswith("leech_healing_multiplier:"):
            values["leechHealingMultiplier"] = token.split(":", 1)[1]
        elif token.startswith("hemorrhage_bleed_bonus:"):
            values["hemorrhageBleedBonus"] = token.split(":", 1)[1]
        elif token.startswith("on_bleed_apply_poison:"):
            values["onBleedApplyPoison"] = token.split(":", 1)[1]
        elif token.startswith("on_burn_apply_poison:"):
            values["onBurnApplyPoison"] = token.split(":", 1)[1]
        elif token.startswith("on_bleed_deal_burn_damage:"):
            values["onBleedDealBurnDamage"] = token.split(":", 1)[1]
        elif token.startswith("every_nth_bleed_apply_poison:"):
            _, count, potency = token.split(":", 2)
            values["everyNthBleedApplyCount"] = count
            values["everyNthBleedApplyPoisonPotency"] = potency
        elif token.startswith("freeze_damage_while_frozen:"):
            values["freezeDamageWhileFrozenBonus"] = token.split(":", 1)[1]
        elif token.startswith("damage_while_target_frozen:"):
            values["damageWhileTargetFrozenBonus"] = token.split(":", 1)[1]
        elif token.startswith("damage_below_health_percent:"):
            _, threshold, keyword, bonus = token.split(":", 3)
            values["damageBelowHealthPercentThreshold"] = threshold
            values["damageBelowHealthPercentKeyword"] = f".{keyword}"
            values["damageBelowHealthPercentBonus"] = bonus
        elif token.startswith("damage_after_dodge:"):
            values["damageAfterDodgeBonus"] = token.split(":", 1)[1]
        elif token.startswith("refresh_bleed_on_reapply:"):
            values["refreshBleedOnReapply"] = token.split(":", 1)[1]
        elif token.startswith("on_block_broken_block:"):
            values["blockBrokenBlockFlat"] = token.split(":", 1)[1]
        elif token.startswith("first_hit_apply_marked:"):
            values["firstHitApplyMarked"] = token.split(":", 1)[1]
        elif token.startswith("companion_heal_share_percent:"):
            values["companionHealSharePercent"] = token.split(":", 1)[1]
        elif token.startswith("once_below_health_percent_heal:"):
            _, threshold, amount = token.split(":", 2)
            values["onceBelowHealthPercentThreshold"] = threshold
            values["onceBelowHealthPercentHeal"] = amount
        elif token.startswith("block_per_action_while_deaths_door:"):
            values["blockPerActionWhileDeathsDoor"] = token.split(":", 1)[1]
        elif token.startswith("every_nth_burn_tick_freeze_damage:"):
            _, count, amount = token.split(":", 2)
            values["everyNthBurnTickCount"] = count
            values["everyNthBurnTickFreezeDamage"] = amount
        elif token.startswith("on_spend_mana_block:"):
            values["spendManaBlockFlat"] = token.split(":", 1)[1]
        elif token.startswith("on_holy_damage_block:"):
            values["holyDamageBlockFlat"] = token.split(":", 1)[1]
        elif token.startswith("on_holy_damage_cleanse:"):
            values["holyDamageCleanseCount"] = token.split(":", 1)[1]
        elif token.startswith("on_holy_damage_heal:"):
            values["holyDamageHealFlat"] = token.split(":", 1)[1]
        elif token.startswith("on_dodge_gold:"):
            values["dodgeGoldFlat"] = token.split(":", 1)[1]
        elif token.startswith("ignore_enemy_mitigation_percent:"):
            values["ignoreEnemyMitigationPercent"] = token.split(":", 1)[1]
        elif token.startswith("on_stun_deal_physical:"):
            values["stunDealPhysicalFlat"] = token.split(":", 1)[1]
        elif token.startswith("damage_while_target_stunned:"):
            values["damageWhileTargetStunnedBonus"] = token.split(":", 1)[1]
        elif token.startswith("on_enemy_stunned_apply_marked:"):
            values["enemyStunnedApplyMarked"] = token.split(":", 1)[1]
        elif token.startswith("on_dodge_block:"):
            values["dodgeBlockFlat"] = token.split(":", 1)[1]
        elif token.startswith("on_holy_damage_purge:"):
            values["holyDamagePurgeCount"] = token.split(":", 1)[1]
        else:
            raise ValueError(f"Unknown trigger token: {token}")
    order = [
        "cleanseBonusHeal",
        "gainGoldBonusHealSelf",
        "restoreHealthAlsoHealHero",
        "controlResistancePercent",
        "dodgeChanceBonus",
        "physicalDodgeChanceBonus",
        "ambushBonusDamage",
        "regenerationAmount",
        "regenerationIntervalTicks",
        "passiveMitigationFlat",
        "thornsPercent",
        "cannotBeHealed",
        "burnDecaySlowPercent",
        "shieldErosionKeyword",
        "shieldErosionTicks",
        "mitigationShredKeyword",
        "mitigationShredMultiplier",
        "mitigationShredDurationTicks",
        "freezeControlVulnerabilityPercent",
        "mitigationEffectivenessPenaltyPercent",
        "leechHealingMultiplier",
        "hemorrhageBleedBonus",
        "onBleedApplyPoison",
        "onBurnApplyPoison",
        "onBleedDealBurnDamage",
        "everyNthBleedApplyCount",
        "everyNthBleedApplyPoisonPotency",
        "freezeDamageWhileFrozenBonus",
        "damageWhileTargetFrozenBonus",
        "damageBelowHealthPercentThreshold",
        "damageBelowHealthPercentKeyword",
        "damageBelowHealthPercentBonus",
        "damageAfterDodgeBonus",
        "refreshBleedOnReapply",
        "blockBrokenBlockFlat",
        "firstHitApplyMarked",
        "companionHealSharePercent",
        "onceBelowHealthPercentThreshold",
        "onceBelowHealthPercentHeal",
        "blockPerActionWhileDeathsDoor",
        "everyNthBurnTickCount",
        "everyNthBurnTickFreezeDamage",
        "spendManaBlockFlat",
        "holyDamageBlockFlat",
        "holyDamageCleanseCount",
        "holyDamageHealFlat",
        "dodgeGoldFlat",
        "ignoreEnemyMitigationPercent",
        "stunDealPhysicalFlat",
        "damageWhileTargetStunnedBonus",
        "enemyStunnedApplyMarked",
        "dodgeBlockFlat",
        "holyDamagePurgeCount",
    ]
    parts = [f"{label}: {values[label]}" for label in order if label in values]
    if not parts:
        return "CombatTraitTriggers()"
    return "CombatTraitTriggers(" + ", ".join(parts) + ")"


def modifiers_swift(raw: str) -> str:
    mods = [modifier_token_to_swift(token) for token in parse_modifier_tokens(raw)]
    return "[" + ", ".join(mods) + "]"


def parse_effect_token(token: str) -> str:
    target = None
    if "@" in token:
        token, target_name = token.split("@", 1)
    else:
        target_name = None

    if token == "cleanse_random":
        effect = ".cleanseRandom"
    elif token == "purge":
        effect = ".purge(nil)"
    elif token == "cleanse":
        effect = ".cleanse(nil)"
    elif token.startswith("cleanse:"):
        effect = f".cleanse(.{token.split(':', 1)[1]})"
    elif token.startswith("burn:"):
        effect = f".burn({token.split(':', 1)[1]})"
    elif token.startswith("poison:"):
        effect = f".poison({token.split(':', 1)[1]})"
    elif token.startswith("bleed:"):
        effect = f".bleed({token.split(':', 1)[1]})"
    elif token.startswith("shield:"):
        parts = token.split(":")
        if len(parts) == 3:
            _, kind, amount = parts
            effect = f".shield(.{kind}, {amount})"
        elif len(parts) == 4:
            _, kind, amount, _duration = parts
            effect = f".shield(.{kind}, {amount})"
        else:
            raise ValueError(f"Invalid shield token: {token}")
    elif token.startswith("mitigation:"):
        raise ValueError(
            f"mitigation effect tokens are removed; convert Armor grants to shield:block:N ({token})"
        )
    elif token.startswith("instant_heal:"):
        _, kind, amount = token.split(":", 2)
        effect = f".instantHeal(.{kind}, {amount})"
    elif token.startswith("resource_gain:"):
        _, kind, amount = token.split(":", 2)
        effect = f".resourceGain(.{kind}, {amount})"
    elif token.startswith("thorns:"):
        _, keyword, amount, duration = token.split(":", 3)
        effect = f".thorns(.{keyword}, {amount}, {duration})"
    elif token.startswith("damage_keyword_override:"):
        _, keyword, bonus, duration = token.split(":", 3)
        effect = f".damageKeywordOverride(.{keyword}, {bonus}, {duration})"
    elif token.startswith("halve_shield:"):
        effect = f".halveShield(.{token.split(':', 1)[1]})"
    else:
        raise ValueError(f"Unknown effect token: {token}")

    if target_name:
        return f"TargetedEffect({effect}, target: .{target_name})"
    return f"TargetedEffect({effect})"


def targeted_effects_swift(raw: str) -> list[str]:
    if not raw:
        return []
    return [parse_effect_token(token.strip()) for token in raw.split("|") if token.strip()]


def damage_components_swift(raw: str) -> list[str]:
    if not raw:
        return []
    components: list[str] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        parts = token.split(":")
        if len(parts) == 2:
            amount, keyword = parts
            target = ".abilityTarget"
        elif len(parts) == 3:
            amount, keyword, target_name = parts
            target = f".{target_name}"
        else:
            raise ValueError(f"Invalid damage component token: {token}")
        if target == ".abilityTarget":
            components.append(f"DamageComponent({amount}, keyword: .{keyword})")
        else:
            components.append(
                f"DamageComponent({amount}, keyword: .{keyword}, target: {target})"
            )
    return components


def optional_description(description: str) -> str:
    if not description:
        return ""
    escaped = swift_escape(description)
    return f',\n        description: "{escaped}"'


def optional_leech(leech: str) -> str:
    if leech.strip().lower() in {"1", "true", "yes"}:
        return ",\n        hasLeech: true"
    return ""


def render_direct_hit(row: AbilityRow) -> str:
    amount = row.amount or "0"
    keyword = row.keyword or "physical"
    extras = targeted_effects_swift(row.extras)
    description = optional_description(row.description)
    leech = optional_leech(row.leech)
    if extras:
        extras_arg = ", ".join(extras)
        return (
            f"    static let {row.symbol} = AbilityBuilder.directHit(\n"
            f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
            f"        amount: {amount}, keyword: .{keyword}{description},\n"
            f"        extras: [{extras_arg}]{leech}\n"
            f"    )"
        )
    return (
        f"    static let {row.symbol} = AbilityBuilder.directHit(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        amount: {amount}, keyword: .{keyword}{description}{leech}\n"
        f"    )"
    )


def effect_swift(token: str) -> str:
    parsed = parse_effect_token(token.strip())
    return parsed.removeprefix("TargetedEffect(").removesuffix(")")


def render_buff_only(row: AbilityRow) -> str:
    effects = ", ".join(effect_swift(token) for token in row.effects.split("|") if token.strip())
    description = optional_description(row.description)
    leech = optional_leech(row.leech)
    return (
        f"    static let {row.symbol} = AbilityBuilder.buffOnly(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        effects: [{effects}]{description}{leech}\n"
        f"    )"
    )


def render_multi_damage(row: AbilityRow) -> str:
    damage = ", ".join(damage_components_swift(row.damage_components))
    effects = ", ".join(targeted_effects_swift(row.effects))
    description = optional_description(row.description)
    leech = optional_leech(row.leech)
    effects_clause = f",\n        effects: [{effects}]" if effects else ""
    return (
        f"    static let {row.symbol} = AbilityBuilder.multiDamage(\n"
        f'        id: "{row.id}", name: "{swift_escape(row.name)}", tier: .{row.tier},\n'
        f"        damageComponents: [{damage}]{effects_clause}{description}{leech}\n"
        f"    )"
    )


def render_ability(row: AbilityRow) -> str:
    if row.pattern == "direct_hit":
        return render_direct_hit(row)
    if row.pattern == "buff_only":
        return render_buff_only(row)
    if row.pattern == "multi_damage":
        return render_multi_damage(row)
    raise ValueError(f"Unsupported ability pattern '{row.pattern}' for {row.id}")


TOP_LEVEL = re.compile(r"^(?P<kind>enum|struct|class|actor|extension)\s+")
MEMBER = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open |case ))"
    r"(?P<body>(?:mutating )?(?:nonisolated )?(?:static )?(?:init|let|var|func|subscript)(?:\s|\())"
)
NESTED_TYPE = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open ))"
    r"(?P<body>(?:enum|struct|class|actor) )"
)


def publicize(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    in_public_type = False

    for line in lines:
        if depth == 0:
            top = TOP_LEVEL.match(line)
            if top and not line.startswith("public "):
                if re.search(r"\b\w+Generated\b", line):
                    in_public_type = False
                elif top.group("kind") == "extension":
                    # Members inherit access from `public extension`; do not
                    # also mark them `public` (redundant and warns).
                    line = f"public {line}"
                    in_public_type = False
                else:
                    line = f"public {line}"
                    in_public_type = True
            elif line.startswith("public extension "):
                in_public_type = False
            elif line.startswith("extension ") and not line.startswith("public "):
                line = f"public {line}"
                in_public_type = False
            else:
                in_public_type = False

        if in_public_type and depth == 1:
            match = MEMBER.match(line) or NESTED_TYPE.match(line)
            if match:
                rest = line.lstrip()
                line = f"{match.group('indent')}public {rest}"

        out.append(line)
        depth = max(0, depth + line.count("{") - line.count("}"))

    return "\n".join(out) + "\n"


def write_generated_file(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = publicize(
        "// Generated by Scripts/content_codegen.py — do not edit.\n"
        "import Foundation\n"
        "import TrinketCore\n\n"
        f"{body}\n"
    )
    # Skip rewrite when content is unchanged so mtimes do not invalidate dependents.
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def generate_affix_catalog(rows: list[AffixRow]) -> None:
    entries: list[str] = []
    for row in rows:
        entries.append(
            "        ItemAffixCatalogSupport.affix(\n"
            f'            id: "{row.id}",\n'
            f'            title: "{swift_escape(row.title)}",\n'
            f"            slot: .{row.slot},\n"
            f"            keywords: {parse_keywords(row.keywords)},\n"
            f"            weight: {row.weight},\n"
            f'            basic: ItemAffixPower(description: "{swift_escape(row.basic_description)}", modifiers: {modifiers_swift(row.basic_modifiers)}, triggers: {triggers_swift(row.basic_triggers)}),\n'
            f'            astral: ItemAffixPower(description: "{swift_escape(row.astral_description)}", modifiers: {modifiers_swift(row.astral_modifiers)}, triggers: {triggers_swift(row.astral_triggers)})\n'
            "        )"
        )

    body = (
        "enum ItemAffixCatalogGenerated {\n"
        "    static let definitions: [ItemAffixDefinition] = [\n"
        + ",\n".join(entries)
        + ",\n    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "ItemAffixCatalog.generated.swift", body)


def generate_ability_tier_catalog(tier: str, rows: list[AbilityRow]) -> None:
    enum_name = TIER_ENUM[tier]
    tier_rows = [row for row in rows if row.tier == tier]
    definitions = [render_ability(row) for row in tier_rows]
    all_entries = ",\n        ".join(row.symbol for row in tier_rows)
    body = (
        f"enum {enum_name} {{\n"
        + ("\n\n".join(definitions) if definitions else "")
        + ("\n\n" if definitions else "")
        + "    static let all: [Ability] = [\n"
        + (f"        {all_entries}\n" if tier_rows else "")
        + "    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / f"AbilityCatalog{tier.capitalize()}.generated.swift", body)


def parse_custom_ability_symbols(path: Path) -> list[tuple[str, str]]:
    text = path.read_text()
    return [(match.group(1), path.stem) for match in re.finditer(r"static let (\w+) = Ability\(", text)]


def parse_generated_ability_symbols(path: Path) -> list[tuple[str, str]]:
    text = path.read_text()
    enum_match = re.search(r"enum (\w+)", text)
    if not enum_match:
        return []
    enum_name = enum_match.group(1)
    return [(match.group(1), enum_name) for match in re.finditer(r"static let (\w+) = AbilityBuilder", text)]


def collect_ability_symbols() -> set[str]:
    symbols: set[str] = set()
    for row in parse_ability_rows():
        symbols.add(row.symbol)
    for tier in ("Basic", "Skill", "Ultimate"):
        hand_path = CONTENT_DIR / f"AbilityCatalog{tier}.swift"
        generated_path = GENERATED_DIR / f"AbilityCatalog{tier}.generated.swift"
        symbols.update(symbol for symbol, _ in parse_custom_ability_symbols(hand_path))
        if generated_path.exists():
            symbols.update(symbol for symbol, _ in parse_generated_ability_symbols(generated_path))
    return symbols


def parse_ability_symbol_list(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def ability_symbols_swift(raw: str) -> str:
    symbols = parse_ability_symbol_list(raw)
    return "[" + ", ".join(f".{symbol}" for symbol in symbols) + "]"


def primary_stats_swift(row: CombatantRow | EnemyRow) -> str:
    return (
        f"PrimaryStats(strength: {row.strength}, agility: {row.agility}, "
        f"toughness: {row.toughness}, intellect: {row.intellect}, wisdom: {row.wisdom})"
    )


def _validate_snake_id(label: str, value: str, row_id: str) -> None:
    if not SNAKE_IDENTIFIER.match(value):
        raise ValueError(
            f"{label} '{value}' for {row_id} must use lowercase letters, numbers, and underscores"
        )


def _validate_positive_int(label: str, value: str, row_id: str) -> None:
    if not value.isdigit():
        raise ValueError(f"{label} for {row_id} must be an integer")
    if int(value) < 0:
        raise ValueError(f"{label} for {row_id} must be non-negative")


def _validate_ability_symbols(raw: str, row_id: str, ability_symbols: set[str], expected_count: int | None = None) -> None:
    symbols = parse_ability_symbol_list(raw)
    if expected_count is not None and len(symbols) != expected_count:
        raise ValueError(f"{row_id} must list exactly {expected_count} ability symbols")
    for symbol in symbols:
        _validate_swift_symbol("ability symbol", symbol, row_id)
        if symbol not in ability_symbols:
            raise ValueError(f"Unknown ability symbol '{symbol}' for {row_id}")


def validate_trait_rows(rows: list[TraitRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate trait id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("trait id", row.id, row.id)
        _require_non_empty("trait name", row.name, row.id)
        _require_non_empty("trait description", row.description, row.id)

        for token in parse_modifier_tokens(row.modifiers):
            modifier_token_to_swift(token)
        triggers_swift(row.triggers)


def validate_combatant_rows(
    rows: list[CombatantRow], ability_symbols: set[str], trait_ids: set[str]
) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate combatant id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("combatant id", row.id, row.id)
        _require_non_empty("combatant name", row.name, row.id)
        if row.role not in VALID_ROLES:
            raise ValueError(f"Invalid combatant role '{row.role}' for {row.id}")
        if row.growth_archetype not in VALID_GROWTH_ARCHETYPES:
            raise ValueError(f"Invalid growth archetype '{row.growth_archetype}' for {row.id}")

        _validate_positive_int("max_health", row.max_health, row.id)
        if int(row.max_health) < 6:
            raise ValueError(f"max_health for {row.id} must be at least 6")
        _validate_positive_int("max_mana", row.max_mana, row.id)
        for stat in ("strength", "agility", "toughness", "intellect", "wisdom"):
            _validate_positive_int(stat, getattr(row, stat), row.id)

        _validate_ability_symbols(row.basics, row.id, ability_symbols, expected_count=2)
        _validate_ability_symbols(row.skills, row.id, ability_symbols, expected_count=2)
        _validate_ability_symbols(row.ultimates, row.id, ability_symbols, expected_count=2)
        _require_non_empty("trait_id", row.trait_id, row.id)
        if row.trait_id not in trait_ids:
            raise ValueError(f"Unknown trait_id '{row.trait_id}' for combatant {row.id}")
        render_party_combatant(row)


def validate_enemy_rows(
    rows: list[EnemyRow], ability_symbols: set[str], combatant_ids: set[str], trait_ids: set[str]
) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate enemy id: {row.id}")
        if row.id in combatant_ids:
            raise ValueError(f"Enemy id '{row.id}' conflicts with a hero/companion combatant id")
        seen.add(row.id)

        _validate_snake_id("enemy id", row.id, row.id)
        _require_non_empty("enemy name", row.name, row.id)
        if row.is_boss not in {"true", "false"}:
            raise ValueError(f"is_boss for {row.id} must be true or false")
        if row.growth_archetype not in VALID_GROWTH_ARCHETYPES:
            raise ValueError(f"Invalid growth archetype '{row.growth_archetype}' for {row.id}")

        if not row.max_health.isdigit():
            raise ValueError(f"max_health for {row.id} must be an integer")
        if int(row.max_health) < 1:
            raise ValueError(f"max_health for {row.id} must be positive")
        for stat in ("strength", "agility", "toughness", "intellect", "wisdom"):
            _validate_positive_int(stat, getattr(row, stat), row.id)

        _validate_ability_symbols(row.abilities, row.id, ability_symbols, expected_count=3)
        _require_non_empty("positive_trait_id", row.positive_trait_id, row.id)
        if row.positive_trait_id not in trait_ids:
            raise ValueError(f"Unknown positive_trait_id '{row.positive_trait_id}' for enemy {row.id}")
        if row.negative_trait_id:
            if row.negative_trait_id not in trait_ids:
                raise ValueError(f"Unknown negative_trait_id '{row.negative_trait_id}' for enemy {row.id}")
            if row.positive_trait_id == row.negative_trait_id:
                raise ValueError(f"Enemy {row.id} cannot use the same trait for positive and negative")
        render_enemy(row)


def render_party_combatant(row: CombatantRow) -> str:
    max_mana_clause = ""
    if row.max_mana and row.max_mana != "0":
        max_mana_clause = f",\n            maxMana: {row.max_mana}"
    return f"""        Combatant(
            id: "{swift_escape(row.id)}",
            name: "{swift_escape(row.name)}",
            role: .{row.role},
            maxHealth: {row.max_health}{max_mana_clause},
            abilityChoices: AbilityChoices(
                basics: {ability_symbols_swift(row.basics)},
                skills: {ability_symbols_swift(row.skills)},
                ultimates: {ability_symbols_swift(row.ultimates)}
            ),
            primaryStats: {primary_stats_swift(row)},
            growthArchetype: .{row.growth_archetype}
        )"""


def render_enemy(row: EnemyRow) -> str:
    flags: list[str] = []
    if row.is_boss == "true":
        flags.append("isBoss: true")
    flag_clause = ""
    if flags:
        flag_clause = ", " + ", ".join(flags)
    negative_clause = (
        f'negativeTraitID: "{swift_escape(row.negative_trait_id)}"'
        if row.negative_trait_id
        else "negativeTraitID: nil"
    )
    return (
        f"        Enemy(combatant: Combatant(id: \"{swift_escape(row.id)}\", "
        f"name: \"{swift_escape(row.name)}\", role: .enemy, maxHealth: {row.max_health}, "
        f"abilities: {ability_symbols_swift(row.abilities)}, "
        f"primaryStats: {primary_stats_swift(row)}, "
        f"growthArchetype: .{row.growth_archetype}), "
        f"positiveTraitID: \"{swift_escape(row.positive_trait_id)}\", "
        f"{negative_clause}{flag_clause})"
    )


def generate_traits_catalog(rows: list[TraitRow]) -> None:
    entries: list[str] = []
    for row in rows:
        entries.append(
            "        CombatantTraitDefinition(\n"
            f'            id: "{swift_escape(row.id)}",\n'
            f'            name: "{swift_escape(row.name)}",\n'
            f'            description: "{swift_escape(row.description)}",\n'
            f"            modifiers: {modifiers_swift(row.modifiers)},\n"
            f"            triggers: {triggers_swift(row.triggers)}\n"
            "        )"
        )

    body = (
        "enum GameContentTraitsGenerated {\n"
        "    static let definitions: [CombatantTraitDefinition] = [\n"
        + ",\n".join(entries)
        + ",\n    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentTraits.generated.swift", body)


def generate_roster_catalog(rows: list[CombatantRow]) -> None:
    heroes = [row for row in rows if row.role == "hero"]
    companions = [row for row in rows if row.role == "companion"]
    trait_map_entries = ",\n".join(
        f'        "{swift_escape(row.id)}": "{swift_escape(row.trait_id)}"' for row in rows
    )
    hero_blocks = ",\n".join(render_party_combatant(row) for row in heroes)
    companion_blocks = ",\n".join(render_party_combatant(row) for row in companions)
    body = (
        "enum GameContentRosterGenerated {\n"
        "    static let combatantTraitIDs: [String: String] = [\n"
        f"{trait_map_entries}\n"
        "    ]\n\n"
        "    static let heroes: [Combatant] = [\n"
        f"{hero_blocks}\n"
        "    ]\n\n"
        "    static let companions: [Combatant] = [\n"
        f"{companion_blocks}\n"
        "    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentRoster.generated.swift", body)


def generate_enemies_catalog(rows: list[EnemyRow]) -> None:
    enemy_blocks = ",\n".join(render_enemy(row) for row in rows)
    body = (
        "enum GameContentEnemiesGenerated {\n"
        "    static let enemies: [Enemy] = [\n"
        f"{enemy_blocks}\n"
        "    ]\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentEnemies.generated.swift", body)


def _require_non_empty(label: str, value: str, row_id: str) -> None:
    if not value.strip():
        raise ValueError(f"{label} is required for {row_id}")


def _validate_swift_symbol(label: str, value: str, row_id: str) -> None:
    if not SWIFT_IDENTIFIER.match(value):
        raise ValueError(f"{label} '{value}' for {row_id} must be a valid Swift identifier")


def _validate_kebab_id(label: str, value: str, row_id: str) -> None:
    if not KEBAB_IDENTIFIER.match(value):
        raise ValueError(
            f"{label} '{value}' for {row_id} must use lowercase letters, numbers, and hyphens"
        )


def _validate_affix_id(value: str, row_id: str) -> None:
    if KEBAB_IDENTIFIER.match(value) or SNAKE_IDENTIFIER.match(value):
        return
    raise ValueError(
        f"affix id '{value}' for {row_id} must use lowercase letters, numbers, hyphens, or underscores"
    )


def _validate_keywords(raw: str, row_id: str) -> None:
    if not raw:
        return
    for part in raw.split(","):
        keyword = part.strip()
        if not keyword:
            continue
        if keyword not in VALID_KEYWORDS:
            raise ValueError(f"Unknown keyword '{keyword}' for {row_id}")


def _validate_weight(raw: str, row_id: str) -> None:
    try:
        weight = int(raw)
    except ValueError as error:
        raise ValueError(f"Affix weight for {row_id} must be an integer") from error
    if weight <= 0:
        raise ValueError(f"Affix weight for {row_id} must be positive")


def validate_affix_rows(rows: list[AffixRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate affix id: {row.id}")
        seen.add(row.id)

        _validate_affix_id(row.id, row.id)
        _require_non_empty("affix title", row.title, row.id)
        if row.slot not in VALID_SLOTS:
            raise ValueError(f"Invalid affix slot '{row.slot}' for {row.id}")
        _validate_keywords(row.keywords, row.id)
        _validate_weight(row.weight, row.id)
        _require_non_empty("basic_description", row.basic_description, row.id)
        _require_non_empty("astral_description", row.astral_description, row.id)
        modifiers_swift(row.basic_modifiers)
        modifiers_swift(row.astral_modifiers)
        triggers_swift(row.basic_triggers)
        triggers_swift(row.astral_triggers)


def validate_ability_rows(rows: list[AbilityRow]) -> None:
    seen_ids: set[str] = set()
    seen_symbols_by_tier: dict[str, set[str]] = {tier: set() for tier in VALID_TIERS}

    for row in rows:
        if row.id in seen_ids:
            raise ValueError(f"Duplicate ability id: {row.id}")
        seen_ids.add(row.id)

        if row.tier not in VALID_TIERS:
            raise ValueError(f"Invalid ability tier '{row.tier}' for {row.id}")
        if row.pattern not in VALID_PATTERNS:
            raise ValueError(f"Invalid ability pattern '{row.pattern}' for {row.id}")

        _validate_kebab_id("ability id", row.id, row.id)
        _validate_swift_symbol("ability symbol", row.symbol, row.id)
        _require_non_empty("ability name", row.name, row.id)

        if row.symbol in seen_symbols_by_tier[row.tier]:
            raise ValueError(f"Duplicate ability symbol '{row.symbol}' in tier {row.tier}")
        seen_symbols_by_tier[row.tier].add(row.symbol)

        if row.keyword and row.keyword not in VALID_KEYWORDS:
            raise ValueError(f"Unknown ability keyword '{row.keyword}' for {row.id}")

        if row.pattern == "direct_hit":
            _require_non_empty("amount", row.amount, row.id)
            _require_non_empty("keyword", row.keyword, row.id)
            if not row.amount.isdigit():
                raise ValueError(f"direct_hit amount for {row.id} must be an integer")
            targeted_effects_swift(row.extras)
        elif row.pattern == "buff_only":
            _require_non_empty("effects", row.effects, row.id)
            for token in row.effects.split("|"):
                if token.strip():
                    parse_effect_token(token.strip())
        elif row.pattern == "multi_damage":
            _require_non_empty("damage_components", row.damage_components, row.id)
            damage_components_swift(row.damage_components)
            targeted_effects_swift(row.effects)

        # Ensure manifest rows codegen without DSL errors.
        render_ability(row)


def parse_item_templates(raw: str) -> str:
    if not raw.strip():
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f'"{swift_escape(part)}"' for part in parts) + "]"


def parse_material_rewards(raw: str) -> str:
    if not raw.strip():
        return "[]"
    amounts: list[str] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        resource, quantity = token.split(":", 1)
        amounts.append(f"ResourceAmount(.{resource.strip()}, {quantity.strip()})")
    return "[" + ", ".join(amounts) + "]"


def render_stage_encounter(row: StageRow) -> str:
    stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
    if row.encounter == "battle":
        if not row.enemy_id.strip():
            raise ValueError(f"battle encounter requires enemy_id for {stage_id}")
        return f'.battle(enemyID: "{swift_escape(row.enemy_id)}")'
    if row.encounter == "event":
        return ".event"
    if row.encounter == "shop":
        return ".shop"
    if row.encounter == "rest":
        return ".rest"
    if row.encounter == "mystery":
        event_id = row.enemy_id.strip()
        if not event_id:
            raise ValueError(f"mystery encounter requires enemy_id (mystery event id) for {stage_id}")
        return f'.mysteryEvent(eventID: "{swift_escape(event_id)}")'
    if row.encounter == "recruit":
        event_id = row.enemy_id.strip()
        if not event_id:
            raise ValueError(f"recruit encounter requires enemy_id (recruit event id) for {stage_id}")
        return f'.recruit(eventID: "{swift_escape(event_id)}")'
    stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
    raise ValueError(f"Unknown encounter '{row.encounter}' for {stage_id}")


def render_stage(row: StageRow) -> str:
    stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
    return f"""                Stage(
                    id: "{swift_escape(stage_id)}",
                    chapterID: "{swift_escape(row.chapter_id)}",
                    chapterNumber: {row.chapter_number},
                    stageNumber: {row.stage_number},
                    flavorText: "{swift_escape(row.flavor_text)}",
                    encounter: {render_stage_encounter(row)},
                    rewards: .empty
                )"""


def validate_stage_rows(rows: list[StageRow], enemy_ids: set[str] | None = None) -> None:
    seen_stage_ids: set[str] = set()
    chapters: dict[str, list[StageRow]] = {}

    for row in rows:
        stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
        if stage_id in seen_stage_ids:
            raise ValueError(f"Duplicate stage id: {stage_id}")
        seen_stage_ids.add(stage_id)

        if row.theme not in VALID_CHAPTER_THEMES:
            raise ValueError(f"Unknown chapter theme '{row.theme}' for {stage_id}")
        if row.encounter not in VALID_ENCOUNTERS:
            raise ValueError(f"Unknown encounter '{row.encounter}' for {stage_id}")
        if row.encounter == "battle" and not row.enemy_id.strip():
            raise ValueError(f"battle encounter requires enemy_id for {stage_id}")
        if row.encounter == "battle" and enemy_ids is not None and row.enemy_id not in enemy_ids:
            raise ValueError(f"Stage {stage_id} references unknown enemy '{row.enemy_id}'")
        if row.encounter in {"mystery", "recruit"} and not row.enemy_id.strip():
            raise ValueError(f"{row.encounter} encounter requires an event id for {stage_id}")
        if row.encounter not in {"battle", "mystery", "recruit"} and row.enemy_id.strip():
            raise ValueError(f"enemy_id only allowed for battle/mystery/recruit encounters at {stage_id}")
        if row.encounter == "battle" and (row.encounter_art_id.strip() or row.encounter_art_title.strip()):
            raise ValueError(f"encounter art fields only allowed for non-battle encounters at {stage_id}")
        if row.encounter in {"mystery", "recruit"} and (
            row.encounter_art_id.strip() or row.encounter_art_title.strip()
        ):
            raise ValueError(
                f"{row.encounter} encounters use event art; leave encounter art empty for {stage_id}"
            )
        if bool(row.encounter_art_id.strip()) != bool(row.encounter_art_title.strip()):
            raise ValueError(
                f"encounter_art_id and encounter_art_title must both be set or empty for {stage_id}"
            )

        for field_name, value in (
            ("chapter_number", row.chapter_number),
            ("stage_number", row.stage_number),
        ):
            if not value.isdigit():
                raise ValueError(f"{field_name} for {stage_id} must be an integer")

        chapters.setdefault(row.chapter_id, []).append(row)
        render_stage(row)

    for chapter_id, chapter_rows in chapters.items():
        numbers = [int(row.stage_number) for row in chapter_rows]
        expected = list(range(1, len(numbers) + 1))
        if sorted(numbers) != expected:
            raise ValueError(f"Chapter {chapter_id} stages must be numbered 1...N contiguously")
        titles = {row.chapter_title for row in chapter_rows}
        themes = {row.theme for row in chapter_rows}
        chapter_numbers = {row.chapter_number for row in chapter_rows}
        if len(titles) != 1 or len(themes) != 1 or len(chapter_numbers) != 1:
            raise ValueError(f"Chapter metadata must be consistent for {chapter_id}")


def generate_chapters_catalog(rows: list[StageRow]) -> None:
    chapters: dict[str, list[StageRow]] = {}
    chapter_meta: dict[str, StageRow] = {}
    for row in rows:
        chapters.setdefault(row.chapter_id, []).append(row)
        chapter_meta[row.chapter_id] = row

    chapter_blocks: list[str] = []
    for chapter_id in sorted(chapters, key=lambda cid: int(chapter_meta[cid].chapter_number)):
        chapter_rows = sorted(chapters[chapter_id], key=lambda row: int(row.stage_number))
        meta = chapter_meta[chapter_id]
        stage_blocks = ",\n".join(render_stage(row) for row in chapter_rows)
        chapter_blocks.append(
            f"""        Chapter(
            id: "{swift_escape(chapter_id)}",
            number: {meta.chapter_number},
            title: "{swift_escape(meta.chapter_title)}",
            theme: .{meta.theme},
            stages: [
{stage_blocks}
            ]
        )"""
        )

    body = (
        "enum GameContentChaptersGenerated {\n"
        "    static let chapters: [Chapter] = [\n"
        + ",\n".join(chapter_blocks)
        + "\n    ]\n}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentChapters.generated.swift", body)


def generate_stages_index() -> None:
    body = (
        "enum GameContentStagesIndexGenerated {\n"
        "    static let stagesByID: [String: Stage] = Dictionary(\n"
        "        uniqueKeysWithValues: GameContentChaptersGenerated.chapters.flatMap(\\.stages).map { ($0.id, $0) }\n"
        "    )\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentStagesIndex.generated.swift", body)


def generate_ability_index() -> None:
    body = (
        "enum AbilityCatalogIndexGenerated {\n"
        "    static let abilitiesByID: [String: Ability] = Dictionary(\n"
        "        uniqueKeysWithValues: AbilityCatalog.all.map { ($0.id, $0) }\n"
        "    )\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "AbilityCatalogIndex.generated.swift", body)


def parse_homestead_prerequisites(raw: str) -> str:
    if not raw.strip():
        return "[]"
    requirements: list[str] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        if ":" in token:
            node_id, tier = token.split(":", 1)
            requirements.append(
                f"HomesteadNodeRequirement(.{node_id.strip()}, tier: {tier.strip()})"
            )
        else:
            requirements.append(f"HomesteadNodeRequirement(.{token})")
    return "[" + ", ".join(requirements) + "]"


def render_homestead_tier(row: HomesteadNodeRow) -> str:
    return f"""                HomesteadNodeTier(
                    tier: {row.tier},
                    cost: {parse_material_rewards(row.cost)},
                    bonus: HomesteadBonus(
                        title: "{swift_escape(row.bonus_title)}",
                        description: "{swift_escape(row.bonus_description)}"
                    )
                )"""


def render_homestead_node(node_id: str, rows: list[HomesteadNodeRow]) -> str:
    meta = rows[0]
    tier_blocks = ",\n".join(render_homestead_tier(row) for row in sorted(rows, key=lambda row: int(row.tier)))
    return f"""        HomesteadNodeDefinition(
            id: .{node_id},
            title: "{swift_escape(meta.title)}",
            summary: "{swift_escape(meta.summary)}",
            symbolName: "{swift_escape(meta.symbol_name)}",
            tintStyle: .{meta.tint},
            category: .{meta.category},
            prerequisites: {parse_homestead_prerequisites(meta.prerequisites)},
            tiers: [
{tier_blocks}
            ]
        )"""


def validate_homestead_cost(raw: str, row_id: str) -> None:
    if not raw.strip():
        raise ValueError(f"cost is required for {row_id}")
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        resource, quantity = token.split(":", 1)
        if resource.strip() not in VALID_HOMESTEAD_RESOURCES:
            raise ValueError(f"Unknown homestead resource '{resource}' for {row_id}")
        if not quantity.strip().isdigit():
            raise ValueError(f"Cost quantity for {row_id} must be an integer")


def validate_homestead_prerequisites(raw: str, row_id: str, node_ids: set[str]) -> None:
    if not raw.strip():
        return
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        if ":" in token:
            node_id, tier = token.split(":", 1)
            node_id = node_id.strip()
            if not tier.strip().isdigit():
                raise ValueError(f"Prerequisite tier for {row_id} must be an integer")
        else:
            node_id = token
        if node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node '{node_id}' in prerequisites for {row_id}")
        if node_id not in node_ids:
            raise ValueError(f"Prerequisite node '{node_id}' for {row_id} is not defined in manifest")


def validate_homestead_node_rows(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    seen_tiers: set[tuple[str, int]] = set()

    for row in rows:
        row_id = f"{row.node_id}-tier-{row.tier}"
        if row.node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node id '{row.node_id}'")
        if row.tint not in VALID_HOMESTEAD_TINTS:
            raise ValueError(f"Unknown homestead tint '{row.tint}' for {row_id}")
        if row.category not in VALID_HOMESTEAD_CATEGORIES:
            raise ValueError(f"Unknown homestead category '{row.category}' for {row_id}")
        if not row.tier.isdigit():
            raise ValueError(f"tier for {row_id} must be an integer")
        tier_value = int(row.tier)
        if tier_value <= 0:
            raise ValueError(f"tier for {row_id} must be positive")
        if (row.node_id, tier_value) in seen_tiers:
            raise ValueError(f"Duplicate homestead tier: {row_id}")
        seen_tiers.add((row.node_id, tier_value))

        _require_non_empty("title", row.title, row_id)
        _require_non_empty("summary", row.summary, row_id)
        _require_non_empty("symbol_name", row.symbol_name, row_id)
        _require_non_empty("bonus_title", row.bonus_title, row_id)
        _require_non_empty("bonus_description", row.bonus_description, row_id)
        validate_homestead_cost(row.cost, row_id)
        nodes.setdefault(row.node_id, []).append(row)

    node_ids = set(nodes)
    for node_id, node_rows in nodes.items():
        for row in node_rows:
            validate_homestead_prerequisites(row.prerequisites, f"{node_id}-tier-{row.tier}", node_ids)

        titles = {row.title for row in node_rows}
        summaries = {row.summary for row in node_rows}
        symbols = {row.symbol_name for row in node_rows}
        tints = {row.tint for row in node_rows}
        categories = {row.category for row in node_rows}
        prerequisite_sets = {row.prerequisites for row in node_rows}
        if (
            len(titles) != 1
            or len(summaries) != 1
            or len(symbols) != 1
            or len(tints) != 1
            or len(categories) != 1
            or len(prerequisite_sets) != 1
        ):
            raise ValueError(f"Homestead node metadata must be consistent for {node_id}")

        tiers = sorted(int(row.tier) for row in node_rows)
        expected = list(range(1, len(tiers) + 1))
        if tiers != expected:
            raise ValueError(f"Homestead node {node_id} tiers must be numbered 1...N contiguously")
        render_homestead_node(node_id, node_rows)

    if set(nodes) != VALID_HOMESTEAD_NODE_IDS:
        missing = VALID_HOMESTEAD_NODE_IDS - set(nodes)
        extra = set(nodes) - VALID_HOMESTEAD_NODE_IDS
        if missing:
            raise ValueError(f"Homestead manifest missing nodes: {sorted(missing)}")
        if extra:
            raise ValueError(f"Homestead manifest has unknown nodes: {sorted(extra)}")


HOMESTEAD_NODE_ORDER = [
    "wheatField",
    "herbGarden",
    "chickenCoop",
    "pasture",
    "culinaryArts",
    "blacksmithForge",
    "woolTailoring",
    "alchemyLab",
    "botanicalDistillation",
    "crystalGarden",
    "runesmithWorkshop",
    "hunterLodge",
    "agilityTraining",
    "detectMagic",
    "wishingWell",
]


def generate_homestead_catalog(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    for row in rows:
        nodes.setdefault(row.node_id, []).append(row)

    if set(HOMESTEAD_NODE_ORDER) != VALID_HOMESTEAD_NODE_IDS:
        raise ValueError("HOMESTEAD_NODE_ORDER must match VALID_HOMESTEAD_NODE_IDS")

    node_blocks = ",\n".join(
        render_homestead_node(node_id, nodes[node_id])
        for node_id in HOMESTEAD_NODE_ORDER
    )
    body = (
        "enum GameContentHomesteadGenerated {\n"
        "    static let homesteadNodes: [HomesteadNodeDefinition] = [\n"
        + node_blocks
        + "\n    ]\n}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentHomestead.generated.swift", body)


def validate_item_base_rows(rows: list[ItemBaseRow]) -> None:
    seen_ids: set[str] = set()
    for row in rows:
        if row.id in seen_ids:
            raise ValueError(f"Duplicate item base id: {row.id}")
        seen_ids.add(row.id)
        if row.slot not in VALID_SLOTS:
            raise ValueError(f"Unknown item slot '{row.slot}' for {row.id}")
        for keyword in row.keywords.split(","):
            keyword = keyword.strip()
            if keyword and keyword not in VALID_KEYWORDS:
                raise ValueError(f"Unknown keyword '{keyword}' for item base {row.id}")


def generate_item_bases_catalog(rows: list[ItemBaseRow]) -> None:
    entries: list[str] = []
    for row in rows:
        entries.append(
            "        ItemBaseType("
            f'id: "{swift_escape(row.id)}", '
            f'name: "{swift_escape(row.name)}", '
            f"slot: .{row.slot}, "
            f"keywordAffinities: {parse_keywords(row.keywords)}"
            ")"
        )
    body = (
        "enum GameContentItemBasesGenerated {\n"
        "    static let itemBaseTypes: [ItemBaseType] = [\n"
        + ",\n".join(entries)
        + "\n    ]\n}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentItemBases.generated.swift", body)


def generate_encounter_art_catalog(rows: list[StageRow]) -> None:
    entries: list[str] = []
    for row in rows:
        if not row.encounter_art_id.strip():
            continue
        stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
        entries.append(
            f'        "{swift_escape(stage_id)}": (id: "{swift_escape(row.encounter_art_id)}", '
            f'title: "{swift_escape(row.encounter_art_title)}")'
        )
    body = (
        "enum GameContentEncounterArtGenerated {\n"
        "    static let stageEncounterArt: [String: (id: String, title: String)] = [\n"
        + ",\n".join(entries)
        + "\n    ]\n}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentEncounterArt.generated.swift", body)


def validate_manifests() -> tuple[
    list[AffixRow],
    list[TraitRow],
    list[AbilityRow],
    list[StageRow],
    list[CombatantRow],
    list[EnemyRow],
    list[HomesteadNodeRow],
    list[ItemBaseRow],
]:
    affix_rows = parse_affix_rows()
    trait_rows = parse_trait_rows()
    ability_rows = parse_ability_rows()
    combatant_rows = parse_combatant_rows()
    enemy_rows = parse_enemy_rows()
    stage_rows = parse_stage_rows()
    homestead_rows = parse_homestead_node_rows()
    item_base_rows = parse_item_base_rows()
    ability_symbols = collect_ability_symbols()

    validate_affix_rows(affix_rows)
    validate_trait_rows(trait_rows)
    validate_ability_rows(ability_rows)
    validate_combatant_rows(combatant_rows, ability_symbols, {row.id for row in trait_rows})
    validate_enemy_rows(
        enemy_rows,
        ability_symbols,
        {row.id for row in combatant_rows},
        {row.id for row in trait_rows},
    )
    validate_stage_rows(stage_rows, enemy_ids={row.id for row in enemy_rows})
    validate_homestead_node_rows(homestead_rows)
    validate_item_base_rows(item_base_rows)
    return (
        affix_rows,
        trait_rows,
        ability_rows,
        stage_rows,
        combatant_rows,
        enemy_rows,
        homestead_rows,
        item_base_rows,
    )


def generate_ability_shorthand() -> None:
    entries: list[tuple[str, str]] = []
    for tier in ("Basic", "Skill", "Ultimate"):
        hand_path = CONTENT_DIR / f"AbilityCatalog{tier}.swift"
        generated_path = GENERATED_DIR / f"AbilityCatalog{tier}.generated.swift"
        for symbol, enum_name in parse_custom_ability_symbols(hand_path):
            entries.append((symbol, f"AbilityCatalog{tier}.{symbol}"))
        if generated_path.exists():
            for symbol, enum_name in parse_generated_ability_symbols(generated_path):
                entries.append((symbol, f"{enum_name}.{symbol}"))

    entries.sort(key=lambda item: item[0])
    lines = [f"    static let {symbol} = {target}" for symbol, target in entries]
    body = "extension Ability {\n" + "\n".join(lines) + "\n}\n"
    write_generated_file(GENERATED_DIR / "AbilityShorthand.generated.swift", body)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "all"
    if command == "validate":
        (
            affix_rows,
            trait_rows,
            ability_rows,
            stage_rows,
            combatant_rows,
            enemy_rows,
            homestead_rows,
            item_base_rows,
        ) = validate_manifests()
        print(
            f"Validated {len(affix_rows)} affixes, "
            f"{len(trait_rows)} traits, "
            f"{len(ability_rows)} manifest abilities, "
            f"{len(stage_rows)} stages, "
            f"{len(combatant_rows)} combatants, "
            f"{len(enemy_rows)} enemies, "
            f"{len(homestead_rows)} homestead tiers, and "
            f"{len(item_base_rows)} item bases"
        )
        return 0
    if command == "shorthand":
        generate_ability_shorthand()
        print("Generated AbilityShorthand.generated.swift")
        return 0

    (
        affix_rows,
        trait_rows,
        ability_rows,
        stage_rows,
        combatant_rows,
        enemy_rows,
        homestead_rows,
        item_base_rows,
    ) = validate_manifests()
    generate_affix_catalog(affix_rows)
    generate_traits_catalog(trait_rows)
    for tier in ("basic", "skill", "ultimate"):
        generate_ability_tier_catalog(tier, ability_rows)
    generate_chapters_catalog(stage_rows)
    generate_stages_index()
    generate_roster_catalog(combatant_rows)
    generate_enemies_catalog(enemy_rows)
    generate_homestead_catalog(homestead_rows)
    generate_item_bases_catalog(item_base_rows)
    generate_encounter_art_catalog(stage_rows)
    generate_ability_shorthand()
    generate_ability_index()
    print(
        f"Generated {len(affix_rows)} affixes, "
        f"{len(trait_rows)} traits, "
        f"{len(ability_rows)} manifest abilities, "
        f"{len(stage_rows)} stages, "
        f"{len(combatant_rows)} combatants, "
        f"{len(enemy_rows)} enemies, "
        f"{len(homestead_rows)} homestead tiers, and "
        f"{len(item_base_rows)} item bases"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
