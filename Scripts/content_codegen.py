#!/usr/bin/env python3
"""Generate Trinket content catalogs from ContentManifest TSV files."""

from __future__ import annotations

import functools
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_DIR = ROOT / "ContentManifest"
GENERATED_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Generated"
CONTENT_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Content"
TRINKET_CONTENT_PACKAGE = ROOT / "Packages" / "TrinketContent"
TRIGGER_FAMILY_SCHEMA = ROOT / "Scripts" / "trigger_family_schema.json"


@functools.cache
def _trigger_families() -> dict:
    return json.loads(TRIGGER_FAMILY_SCHEMA.read_text(encoding="utf-8"))

VALID_SLOTS = frozenset({"weapon", "armor", "accessory", "trinket"})
VALID_TIERS = frozenset({"basic", "skill", "ultimate"})
VALID_ENCOUNTERS = frozenset(
    {"battle", "shop", "rest", "mystery", "recruit", "random_battle"}
)
VALID_CHAPTER_THEMES = frozenset({"forest", "dungeon", "desert", "tundra"})
# Recruit sentinel: empty id = any eligible unlock; this id = companion-only pool.
RANDOM_COMPANION_RECRUIT_ID = "random-companion"
VALID_HOMESTEAD_RESOURCES = frozenset(
    {"wood", "stone", "iron", "food", "herbs", "hide", "crystal", "gold"}
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
        "crystalGarden",
        "runesmithWorkshop",
        "hunterLodge",
        "agilityTraining",
        "moonlitSanctum",
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
        "leech",
        "gold",
        "mana",
        "dodge",
        "purge",
        "cleanse",
        "deathsDoor",
        "deaths_door",
    }
)
SWIFT_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
KEBAB_IDENTIFIER = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SNAKE_IDENTIFIER = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
VALID_ROLES = frozenset({"hero", "companion"})
VALID_GROWTH_ARCHETYPES = frozenset({"tank", "assassin", "mage", "support", "bruiser"})
VALID_ENEMY_FACTIONS = frozenset(
    {"mortal", "beast", "elemental", "construct", "undead", "corrupted"}
)


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
class StageRow:
    chapter_id: str
    chapter_number: str
    chapter_title: str
    theme: str
    stage_number: str
    encounter: str
    enemy_id: str
    encounter_art_id: str = ""
    encounter_art_title: str = ""


@dataclass
class ItemBaseRow:
    id: str
    name: str
    slot: str
    weapon_kind: str
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


@dataclass
class EnemyRow:
    id: str
    name: str
    max_health: str
    is_boss: str
    growth_archetype: str
    abilities: str
    trait_id: str
    faction: str


@dataclass
class HomesteadNodeRow:
    node_id: str
    title: str
    summary: str
    symbol_name: str
    category: str
    prerequisites: str
    tier: str
    cost: str
    bonus_title: str
    bonus_description: str
    modifiers: str
    production: str


@functools.cache
def _read_tsv_cached(path: Path) -> tuple[tuple[str, ...], ...]:
    rows: list[tuple[str, ...]] = []
    for line in path.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        rows.append(tuple(line.split("\t")))
    return tuple(rows)


def read_tsv(path: Path) -> list[list[str]]:
    return [list(row) for row in _read_tsv_cached(path)]


def _parse_tsv_rows(path: Path, expected: list[str], row_type):
    lines = read_tsv(path)
    header = lines[0]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    rows: list = []
    for raw in lines[1:]:
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(row_type(*padded[: len(expected)]))
    return rows


@functools.cache
def parse_affix_rows() -> list[AffixRow]:
    path = MANIFEST_DIR / "affixes.tsv"
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
    lines = read_tsv(path)
    if lines[0] != expected:
        raise ValueError(f"{path} header mismatch: {lines[0]}")
    rows: list[AffixRow] = []
    for idx, raw in enumerate(lines[1:], start=2):
        if len(raw) < 9:
            raise ValueError(f"{path}:{idx} missing required columns: expected at least 9, got {len(raw)}")
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(AffixRow(*padded[: len(expected)]))
    return rows


@functools.cache
def parse_trait_rows() -> list[TraitRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "traits.tsv",
        ["id", "name", "description", "modifiers", "triggers"],
        TraitRow,
    )


@functools.cache
def parse_stage_rows() -> list[StageRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "stages.tsv",
        [
            "chapter_id",
            "chapter_number",
            "chapter_title",
            "theme",
            "stage_number",
            "encounter",
            "enemy_id",
            "encounter_art_id",
            "encounter_art_title",
        ],
        StageRow,
    )


@functools.cache
def parse_item_base_rows() -> list[ItemBaseRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "item_bases.tsv",
        ["id", "name", "slot", "weapon_kind", "keywords"],
        ItemBaseRow,
    )


@functools.cache
def parse_combatant_rows() -> list[CombatantRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "combatants.tsv",
        [
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
        ],
        CombatantRow,
    )


@functools.cache
def parse_enemy_rows() -> list[EnemyRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "enemies.tsv",
        [
            "id",
            "name",
            "max_health",
            "is_boss",
            "growth_archetype",
            "abilities",
            "trait_id",
            "faction",
        ],
        EnemyRow,
    )


@functools.cache
def parse_homestead_node_rows() -> list[HomesteadNodeRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "homestead_nodes.tsv",
        [
            "node_id",
            "title",
            "summary",
            "symbol_name",
            "category",
            "prerequisites",
            "tier",
            "cost",
            "bonus_title",
            "bonus_description",
            "modifiers",
            "production",
        ],
        HomesteadNodeRow,
    )


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


_MODIFIER_SIMPLE: dict[str, str] = {
    "strength": ".strength",
    "agility": ".agility",
    "toughness": ".toughness",
    "intellect": ".intellect",
    "wisdom": ".wisdom",
    "maximum_health": ".maximumHealth",
    "health_restored": ".healthRestored",
    "leech_gained_percent": ".leechGainedPercent",
    "leech_healing": ".leechHealing",
    "gold_gained": ".goldGained",
    "gold_gained_percent": ".goldGainedPercent",
    "block_gained": ".blockGained",
    "bleed_duration": ".bleedDuration",
    "companion_damage_dealt": ".companionDamageDealt",
    "maximum_mana": ".maximumMana",
    "companion_bleed_damage_dealt": ".companionBleedDamageDealt",
    "poison_damage_dealt_percent": ".poisonDamageDealtPercent",
}

def modifier_token_to_swift(token: str) -> str:
    if ":" not in token:
        raise ValueError(f"Unknown modifier token: {token}")
    prefix, rest = token.split(":", 1)
    if prefix in _MODIFIER_SIMPLE:
        return f"{_MODIFIER_SIMPLE[prefix]}({rest})"
    if prefix == "damage_dealt":
        keyword, amount = rest.split(":", 1)
        return f".damageDealt(.{keyword}, {amount})"
    if prefix == "damage_taken_percent":
        keyword, amount = rest.split(":", 1)
        return f".damageTakenPercent(.{keyword}, {amount})"
    if prefix == "damage_taken_vulnerability":
        keyword, amount = rest.split(":", 1)
        return f".damageTakenVulnerability(.{keyword}, {amount})"
    raise ValueError(f"Unknown modifier token: {token}")


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
            # Support both bare flag and flag:value (value ignored)
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


def modifiers_swift(raw: str) -> str:
    mods = [modifier_token_to_swift(token) for token in parse_modifier_tokens(raw)]
    return "[" + ", ".join(mods) + "]"


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
            else:
                in_public_type = False

        if in_public_type and depth == 1:
            match = MEMBER.match(line) or NESTED_TYPE.match(line)
            if match:
                rest = line.lstrip()
                line = f"{match.group('indent')}public {rest}"

        out.append(line)
        depth = max(0, depth + swift_brace_delta(line))

    return "\n".join(out) + "\n"


def swift_brace_delta(line: str) -> int:
    """Count Swift braces while ignoring string literals and line comments."""
    delta = 0
    in_string = False
    escaped = False
    index = 0
    while index < len(line):
        character = line[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
        elif character == '"':
            in_string = True
        elif character == "/" and index + 1 < len(line) and line[index + 1] == "/":
            break
        elif character == "{":
            delta += 1
        elif character == "}":
            delta -= 1
        index += 1
    return delta


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

    capacity = len(entries)
    chunk_size = 16
    chunks = [entries[index:index + chunk_size] for index in range(0, capacity, chunk_size)]
    chunk_appends = "\n".join(
        f"        list.append(contentsOf: chunk{index}())"
        for index in range(len(chunks))
    )
    chunk_functions = "\n\n".join(
        "    private static func chunk"
        f"{index}() -> [ItemAffixDefinition] {{\n"
        "        [\n"
        + ",\n".join(entry for entry in chunk)
        + "\n        ]\n"
        "    }"
        for index, chunk in enumerate(chunks)
    )
    body = (
        "enum ItemAffixCatalogGenerated {\n"
        "    static let definitions: [ItemAffixDefinition] = {\n"
        f"        var list = [ItemAffixDefinition]()\n"
        f"        list.reserveCapacity({capacity})\n"
        + chunk_appends
        + "\n        return list\n"
        "    }()\n"
        "\n"
        + chunk_functions
        + "\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "ItemAffixCatalog.generated.swift", body)


def parse_hand_ability_symbols(path: Path) -> list[str]:
    source = path.read_text()
    return re.findall(
        r"static let (\w+) = (?:Ability\(|AbilityBuilder\.(?:directHit|buffOnly|multiDamage)\()",
        source,
    )


def collect_ability_symbols() -> set[str]:
    symbols: set[str] = set()
    for tier in ("Basic", "Skill", "Ultimate"):
        hand_path = CONTENT_DIR / f"AbilityCatalog{tier}.swift"
        symbols.update(parse_hand_ability_symbols(hand_path))
    return symbols



def parse_ability_symbol_list(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def ability_symbols_swift(raw: str) -> str:
    symbols = parse_ability_symbol_list(raw)
    return "[" + ", ".join(f".{symbol}" for symbol in symbols) + "]"


def primary_stats_swift(row: CombatantRow) -> str:
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
    rows: list[CombatantRow], ability_symbols: set[str]
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

        _validate_ability_symbols(row.abilities, row.id, ability_symbols, expected_count=3)
        _require_non_empty("trait_id", row.trait_id, row.id)
        if row.trait_id not in trait_ids:
            raise ValueError(f"Unknown trait_id '{row.trait_id}' for enemy {row.id}")
        if row.faction not in VALID_ENEMY_FACTIONS:
            raise ValueError(f"Invalid faction '{row.faction}' for enemy {row.id}")
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
    faction = row.faction.strip() or "mortal"
    flags.append(f"faction: .{faction}")
    flag_clause = ", " + ", ".join(flags)
    return (
        f"        Enemy(combatant: Combatant(id: \"{swift_escape(row.id)}\", "
        f"name: \"{swift_escape(row.name)}\", role: .enemy, maxHealth: {row.max_health}, "
        f"abilities: {ability_symbols_swift(row.abilities)}, "
        f"primaryStats: GrowthArchetype.{row.growth_archetype}.identityPrimaryStats, "
        f"growthArchetype: .{row.growth_archetype}), "
        f"traitID: \"{swift_escape(row.trait_id)}\"{flag_clause})"
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

    capacity = len(entries)
    appends = "\n".join(
        f"        list.append({entry.strip()})"
        for entry in entries
    )
    body = (
        "enum GameContentTraitsGenerated {\n"
        "    static let definitions: [CombatantTraitDefinition] = {\n"
        f"        var list = [CombatantTraitDefinition]()\n"
        f"        list.reserveCapacity({capacity})\n"
        + appends
        + "\n        return list\n"
        "    }()\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentTraits.generated.swift", body)


def generate_roster_catalog(rows: list[CombatantRow]) -> None:
    heroes = [row for row in rows if row.role == "hero"]
    companions = [row for row in rows if row.role == "companion"]
    hero_appends = "\n".join(
        f"        list.append({render_party_combatant(row).strip()})"
        for row in heroes
    )
    companion_appends = "\n".join(
        f"        list.append({render_party_combatant(row).strip()})"
        for row in companions
    )
    body = (
        "enum GameContentRosterGenerated {\n"
        "    static let heroes: [Combatant] = {\n"
        f"        var list = [Combatant]()\n"
        f"        list.reserveCapacity({len(heroes)})\n"
        + hero_appends
        + "\n        return list\n"
        "    }()\n\n"
        "    static let companions: [Combatant] = {\n"
        f"        var list = [Combatant]()\n"
        f"        list.reserveCapacity({len(companions)})\n"
        + companion_appends
        + "\n        return list\n"
        "    }()\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentRoster.generated.swift", body)


def generate_enemies_catalog(rows: list[EnemyRow]) -> None:
    appends = "\n".join(
        f"        list.append({render_enemy(row).strip()})"
        for row in rows
    )
    body = (
        "enum GameContentEnemiesGenerated {\n"
        "    static let enemies: [Enemy] = {\n"
        f"        var list = [Enemy]()\n"
        f"        list.reserveCapacity({len(rows)})\n"
        + appends
        + "\n        return list\n"
        "    }()\n"
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
    if row.encounter == "random_battle":
        return ".randomBattle"
    if row.encounter == "shop":
        return ".shop"
    if row.encounter == "rest":
        return ".rest"
    if row.encounter == "mystery":
        event_id = row.enemy_id.strip()
        return f'.mysteryEvent(eventID: "{swift_escape(event_id)}")'
    if row.encounter == "recruit":
        event_id = row.enemy_id.strip()
        return f'.recruit(eventID: "{swift_escape(event_id)}")'
    raise ValueError(f"Unknown encounter '{row.encounter}' for {stage_id}")


def render_stage(row: StageRow) -> str:
    stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
    return f"""                Stage(
                    id: "{swift_escape(stage_id)}",
                    chapterID: "{swift_escape(row.chapter_id)}",
                    chapterNumber: {row.chapter_number},
                    stageNumber: {row.stage_number},
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
        if row.encounter == "random_battle" and row.enemy_id.strip():
            raise ValueError(f"random_battle must leave enemy_id empty at {stage_id}")
        if row.encounter not in {"battle", "mystery", "recruit"} and row.enemy_id.strip():
            raise ValueError(f"enemy_id only allowed for battle/mystery/recruit encounters at {stage_id}")
        if row.encounter in {"battle", "random_battle"} and (
            row.encounter_art_id.strip() or row.encounter_art_title.strip()
        ):
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

    capacity = len(chapter_blocks)
    appends = "\n".join(
        f"        list.append({block.strip()})"
        for block in chapter_blocks
    )
    body = (
        "enum GameContentChaptersGenerated {\n"
        "    static let chapters: [Chapter] = {\n"
        f"        var list = [Chapter]()\n"
        f"        list.reserveCapacity({capacity})\n"
        + appends
        + "\n        return list\n"
        "    }()\n"
        "}\n"
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


def generate_trigger_families() -> None:
    families = _trigger_families()
    merge_lines = {
        "add": lambda n: f"        {n} += other.{n}",
        "mul": lambda n: f"        {n} *= other.{n}",
        "add_excess": lambda n: f"        {n} = 1 + ({n} - 1) + (other.{n} - 1)",
        "or": lambda n: f"        {n} = {n} || other.{n}",
        "max": lambda n: f"        {n} = max({n}, other.{n})",
        "coalesce": lambda n: f"        {n} = other.{n} ?? {n}",
        "union": lambda n: (
            f"        {n} = Array(Set({n}).union(other.{n})).sorted()"
        ),
    }
    for family in families:
        type_name = family["file_stem"]
        family_id = family["family"]
        fields = family["fields"]
        props = "\n".join(
            f"    public var {f['name']}: {f['type']} = {f['default']}" for f in fields
        )
        init_params = ",\n".join(
            f"        {f['name']}: {f['type']} = {f['default']}" for f in fields
        )
        init_assigns = "\n".join(
            f"        self.{f['name']} = {f['name']}" for f in fields
        )
        merges = "\n".join(merge_lines[f["merge"]](f["name"]) for f in fields)
        decode_args = ",\n".join(
            "            {name}: values.decode({typ}.self, \"{name}\", default: {default})".format(
                name=f["name"], typ=f["type"], default=f["default"]
            )
            for f in fields
        )
        encodes = "\n".join(
            f'        try container.encodeNonDefault({f["name"]}, "{f["name"]}", default: {f["default"]})'
            for f in fields
        )
        field_names_literal = ", ".join(f'"{f["name"]}"' for f in fields)
        populated_checks = "\n".join(
            f'        if self.{f["name"]} != other.{f["name"]} {{ names.append("{f["name"]}") }}'
            for f in fields
        )
        text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import Foundation
import TrinketCore

/// The `{family_id}` trigger family of `CombatTraitTriggers`.
public struct {type_name}: Equatable, Hashable, Sendable {{
{props}

    public init(
{init_params}
    ) {{
{init_assigns}
    }}

    /// All field names for this family — avoids `Mirror` reflection.
    public static let fieldNames: [String] = [{field_names_literal}]

    /// Field names where `self` differs from `other`.
    func populatedFieldNames(comparedTo other: Self) -> [String] {{
        var names: [String] = []
{populated_checks}
        return names
    }}
}}

extension {type_name} {{
    mutating func merge(_ other: Self) {{
{merges}
    }}
}}

extension {type_name} {{
    /// Decodes this family's flat trigger keys.
    init(from values: DefaultingTriggerDecoder) throws {{
        try self.init(
{decode_args}
        )
    }}

    func encode(to container: inout KeyedEncodingContainer<TriggerCodingKey>) throws {{
{encodes}
    }}
}}
"""
        out = GENERATED_DIR / f"{type_name}.generated.swift"
        if out.exists() and out.read_text(encoding="utf-8") == text:
            continue
        out.write_text(text, encoding="utf-8")


def generate_ability_index() -> None:
    body = (
        "enum AbilityCatalogIndexGenerated {\n"
        "    static let abilitiesByID: [String: Ability] = Dictionary(\n"
        "        uniqueKeysWithValues: AbilityCatalog.all.map { ($0.id, $0) }\n"
        "    )\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "AbilityCatalogIndex.generated.swift", body)


def parse_homestead_combat_tokens(
    raw: str,
) -> tuple[list[str], list[str], int, int]:
    hero: list[str] = []
    companion: list[str] = []
    astral = 0
    gold = 0
    for token in parse_modifier_tokens(raw):
        if token.startswith("astral_chance:"):
            astral = int(token.split(":", 1)[1])
            continue
        if token.startswith("gold_find:"):
            gold = int(token.split(":", 1)[1])
            continue
        scope = "both"
        body = token
        if token.startswith("hero."):
            scope = "hero"
            body = token.removeprefix("hero.")
        elif token.startswith("companion."):
            scope = "companion"
            body = token.removeprefix("companion.")
        swift = modifier_token_to_swift(body)
        if scope in ("hero", "both"):
            hero.append(swift)
        if scope in ("companion", "both"):
            companion.append(swift)
    if not hero and not companion and astral == 0 and gold == 0:
        raise ValueError("homestead modifiers must declare combat bonuses")
    return hero, companion, astral, gold


def render_homestead_combat_bonus(raw: str) -> str:
    hero, companion, astral, gold = parse_homestead_combat_tokens(raw)
    parts: list[str] = []
    if hero:
        parts.append(f"heroModifiers: [{', '.join(hero)}]")
    if companion:
        parts.append(f"companionModifiers: [{', '.join(companion)}]")
    if astral:
        parts.append(f"astralChanceBonusPercent: {astral}")
    if gold:
        parts.append(f"goldFindPercent: {gold}")
    return "HomesteadTierCombatBonus(" + ", ".join(parts) + ")"


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
    production = parse_homestead_production(row.production)
    production_line = f",\n                    production: {production}" if production else ""
    return f"""                HomesteadNodeTier(
                    tier: {row.tier},
                    cost: {parse_material_rewards(row.cost)},
                    bonus: HomesteadBonus(
                        title: "{swift_escape(row.bonus_title)}",
                        description: "{swift_escape(row.bonus_description)}"
                    ),
                    combatBonus: {render_homestead_combat_bonus(row.modifiers)}{production_line}
                )"""


def parse_homestead_production(raw: str) -> str | None:
    if not raw.strip():
        return None
    resource, quantity = raw.split(":", 1)
    return f"ResourceAmount(.{resource.strip()}, {quantity.strip()})"


def render_homestead_node(node_id: str, rows: list[HomesteadNodeRow]) -> str:
    meta = rows[0]
    tier_blocks = ",\n".join(render_homestead_tier(row) for row in sorted(rows, key=lambda row: int(row.tier)))
    return f"""        HomesteadNodeDefinition(
            id: .{node_id},
            title: "{swift_escape(meta.title)}",
            summary: "{swift_escape(meta.summary)}",
            symbolName: "{swift_escape(meta.symbol_name)}",
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


def validate_homestead_prerequisites(
    raw: str, row_id: str, node_tiers: dict[str, set[int]]
) -> None:
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
            tier_value = int(tier.strip())
            if tier_value <= 0:
                raise ValueError(f"Prerequisite tier for {row_id} must be positive")
        else:
            node_id = token
        if node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node '{node_id}' in prerequisites for {row_id}")
        if node_id not in node_tiers:
            raise ValueError(f"Prerequisite node '{node_id}' for {row_id} is not defined in manifest")
        if ":" in token and tier_value not in node_tiers[node_id]:
            raise ValueError(
                f"Prerequisite tier {tier_value} for {row_id} is not defined on node '{node_id}'"
            )


def validate_homestead_node_rows(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    seen_tiers: set[tuple[str, int]] = set()

    for row in rows:
        row_id = f"{row.node_id}-tier-{row.tier}"
        if row.node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node id '{row.node_id}'")
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
        _require_non_empty("modifiers", row.modifiers, row_id)
        parse_homestead_combat_tokens(row.modifiers)
        validate_homestead_cost(row.cost, row_id)
        if row.production.strip():
            resource, quantity = row.production.split(":", 1)
            if resource.strip() not in VALID_HOMESTEAD_RESOURCES:
                raise ValueError(f"Unknown production resource '{resource}' for {row_id}")
            if not quantity.strip().isdigit() or int(quantity.strip()) <= 0:
                raise ValueError(f"Production quantity for {row_id} must be positive")
        nodes.setdefault(row.node_id, []).append(row)

    node_tiers = {
        node_id: {int(row.tier) for row in node_rows}
        for node_id, node_rows in nodes.items()
    }
    for node_id, node_rows in nodes.items():
        for row in node_rows:
            validate_homestead_prerequisites(
                row.prerequisites, f"{node_id}-tier-{row.tier}", node_tiers
            )

        titles = {row.title for row in node_rows}
        summaries = {row.summary for row in node_rows}
        symbols = {row.symbol_name for row in node_rows}
        categories = {row.category for row in node_rows}
        prerequisite_sets = {row.prerequisites for row in node_rows}
        if (
            len(titles) != 1
            or len(summaries) != 1
            or len(symbols) != 1
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
    "crystalGarden",
    "runesmithWorkshop",
    "hunterLodge",
    "agilityTraining",
    "moonlitSanctum",
    "wishingWell",
]


def generate_homestead_catalog(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    for row in rows:
        nodes.setdefault(row.node_id, []).append(row)

    if set(HOMESTEAD_NODE_ORDER) != VALID_HOMESTEAD_NODE_IDS:
        raise ValueError("HOMESTEAD_NODE_ORDER must match VALID_HOMESTEAD_NODE_IDS")

    node_count = len(HOMESTEAD_NODE_ORDER)
    appends = "\n".join(
        f"        list.append({render_homestead_node(node_id, nodes[node_id]).strip()})"
        for node_id in HOMESTEAD_NODE_ORDER
    )
    body = (
        "enum GameContentHomesteadGenerated {\n"
        "    static let homesteadNodes: [HomesteadNodeDefinition] = {\n"
        f"        var list = [HomesteadNodeDefinition]()\n"
        f"        list.reserveCapacity({node_count})\n"
        + appends
        + "\n        return list\n"
        "    }()\n"
        "}\n"
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
        valid_weapon_kinds = {"one_handed", "two_handed", "off_hand"}
        if row.slot == "weapon" and row.weapon_kind not in valid_weapon_kinds:
            raise ValueError(f"Unknown weapon kind '{row.weapon_kind}' for {row.id}")
        if row.slot != "weapon" and row.weapon_kind:
            raise ValueError(f"Non-weapon item base {row.id} cannot declare a weapon kind")
        for keyword in row.keywords.split(","):
            keyword = keyword.strip()
            if keyword and keyword not in VALID_KEYWORDS:
                raise ValueError(f"Unknown keyword '{keyword}' for item base {row.id}")


def generate_item_bases_catalog(rows: list[ItemBaseRow]) -> None:
    entries: list[str] = []
    swift_weapon_kinds = {
        "one_handed": ".oneHanded",
        "two_handed": ".twoHanded",
        "off_hand": ".offHand",
    }
    for row in rows:
        entries.append(
            "        ItemBaseType("
            f'id: "{swift_escape(row.id)}", '
            f'name: "{swift_escape(row.name)}", '
            f"slot: .{row.slot}, "
            f"weaponKind: {swift_weapon_kinds.get(row.weapon_kind, 'nil')}, "
            f"keywordAffinities: {parse_keywords(row.keywords)}"
            ")"
        )
    capacity = len(entries)
    appends = "\n".join(
        f"        list.append({entry.strip()})"
        for entry in entries
    )
    body = (
        "enum GameContentItemBasesGenerated {\n"
        "    static let itemBaseTypes: [ItemBaseType] = {\n"
        f"        var list = [ItemBaseType]()\n"
        f"        list.reserveCapacity({capacity})\n"
        + appends
        + "\n        return list\n"
        "    }()\n"
        "}\n"
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
    capacity = len(entries)
    appends = "\n".join(
        f"        dict[{entry.strip().split(':', 1)[0].strip()}] = {entry.strip().split(':', 1)[1].strip()}"
        for entry in entries
    )
    body = (
        "enum GameContentEncounterArtGenerated {\n"
        "    static let stageEncounterArt: [String: (id: String, title: String)] = {\n"
        f"        var dict = [String: (id: String, title: String)]()\n"
        f"        dict.reserveCapacity({capacity})\n"
        + appends
        + "\n        return dict\n"
        "    }()\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentEncounterArt.generated.swift", body)


@dataclass
class TalentRow:
    id: str
    name: str
    symbol_name: str
    description: str
    modifiers: str
    triggers: str


@functools.cache
def parse_talent_rows() -> list[TalentRow]:
    path = MANIFEST_DIR / "talents.tsv"
    lines = read_tsv(path)
    header = lines[0]
    expected = ["id", "name", "symbol_name", "description", "modifiers", "triggers"]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    return [TalentRow(*row) for row in lines[1:]]


def combatant_id_for_talent(talent_id: str, combatant_ids: list[str]) -> str:
    for combatant_id in sorted(combatant_ids, key=len, reverse=True):
        if talent_id.startswith(f"{combatant_id}_"):
            return combatant_id
    raise ValueError(f"Talent {talent_id} does not match a combatant id")


def generate_talent_catalog(rows: list[TalentRow], combatant_ids: list[str]) -> None:
    grouped: dict[str, list[TalentRow]] = {combatant_id: [] for combatant_id in combatant_ids}
    for row in rows:
        grouped[combatant_id_for_talent(row.id, combatant_ids)].append(row)

    def render_entry(row: TalentRow) -> str:
        return (
            f'            "{swift_escape(row.id)}": CombatantTalentEffect(\n'
            f'                name: "{swift_escape(row.name)}",\n'
            f'                symbolName: "{swift_escape(row.symbol_name)}",\n'
            f'                description: "{swift_escape(row.description)}",\n'
            f"                modifiers: {modifiers_swift(row.modifiers)},\n"
            f"                triggers: {triggers_swift(row.triggers)}\n"
            "            )"
        )

    group_lets: list[str] = []
    group_names: list[str] = []
    for combatant_id in combatant_ids:
        talent_rows = grouped[combatant_id]
        if not talent_rows:
            continue
        swift_name = "".join(part.title() for part in combatant_id.split("_"))
        group_name = f"{swift_name[:1].lower() + swift_name[1:]}Talents"
        group_names.append(group_name)
        entries = ",\n".join(render_entry(row) for row in talent_rows)
        group_lets.append(
            f"    static let {group_name}: [String: CombatantTalentEffect] = [\n"
            f"{entries}\n"
            "    ]"
        )

    merge = ",\n            ".join(group_names)
    body = (
        "extension CombatantTalentCatalog {\n"
        + "\n\n".join(group_lets)
        + "\n\n    static let signatureTalents: [String: CombatantTalentEffect] = {\n"
        "        var combined: [String: CombatantTalentEffect] = [:]\n"
        f"        combined.reserveCapacity({len(rows)})\n"
        "        for group in [\n"
        f"            {merge}\n"
        "        ] {\n"
        "            for (key, value) in group {\n"
        "                combined[key] = value\n"
        "            }\n"
        "        }\n"
        "        return combined\n"
        "    }()\n"
        "}\n"
    )
    write_generated_file(GENERATED_DIR / "CombatantTalentCatalog.generated.swift", body)


def validate_talent_rows(rows: list[TalentRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate talent id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("talent id", row.id, row.id)
        _require_non_empty("talent name", row.name, row.id)
        _require_non_empty("talent symbol_name", row.symbol_name, row.id)
        _require_non_empty("talent description", row.description, row.id)

        for token in parse_modifier_tokens(row.modifiers):
            modifier_token_to_swift(token)
        triggers_swift(row.triggers)


def validate_manifests() -> tuple[
    list[AffixRow],
    list[TraitRow],
    list[StageRow],
    list[CombatantRow],
    list[EnemyRow],
    list[HomesteadNodeRow],
    list[ItemBaseRow],
]:
    affix_rows = parse_affix_rows()
    trait_rows = parse_trait_rows()
    combatant_rows = parse_combatant_rows()
    enemy_rows = parse_enemy_rows()
    stage_rows = parse_stage_rows()
    homestead_rows = parse_homestead_node_rows()
    item_base_rows = parse_item_base_rows()
    talent_rows = parse_talent_rows()
    ability_symbols = collect_ability_symbols()

    validate_affix_rows(affix_rows)
    validate_trait_rows(trait_rows)
    validate_talent_rows(talent_rows)
    validate_combatant_rows(combatant_rows, ability_symbols)
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
        for symbol in parse_hand_ability_symbols(hand_path):
            entries.append((symbol, f"AbilityCatalog{tier}.{symbol}"))

    entries.sort(key=lambda item: item[0])
    lines = [f"    static let {symbol} = {target}" for symbol, target in entries]
    body = "extension Ability {\n" + "\n".join(lines) + "\n}\n"
    write_generated_file(GENERATED_DIR / "AbilityShorthand.generated.swift", body)


def parse_authored_ability_inventory_rows() -> list[tuple[str, str, str]]:
    """Regex-extract id/name/tier from hand ability catalogs (cross-check only)."""
    rows: list[tuple[str, str, str]] = []
    for tier_label, tier_enum in (
        ("basic", "Basic"),
        ("skill", "Skill"),
        ("ultimate", "Ultimate"),
    ):
        source = (CONTENT_DIR / f"AbilityCatalog{tier_enum}.swift").read_text()
        for match in re.finditer(
            r'static let \w+ = (?:Ability\(|AbilityBuilder\.(?:directHit|buffOnly|multiDamage)\()\s*'
            r'id: "([^"]+)",\s*name: "([^"]+)",\s*tier: \.(\w+)',
            source,
        ):
            ability_id, name, tier = match.groups()
            if tier != tier_label:
                raise ValueError(
                    f"Ability {ability_id} tier .{tier} does not match file AbilityCatalog{tier_enum}"
                )
            rows.append((ability_id, name, tier))
    rows.sort(key=lambda item: (item[2], item[1].lower()))
    return rows


def generate_ability_inventory() -> None:
    """Dump id/name/tier/summary from Swift Ability.summary for humans/agents."""
    expected = parse_authored_ability_inventory_rows()
    expected_ids = {ability_id for ability_id, _, _ in expected}

    completed = subprocess.run(
        [
            "swift",
            "run",
            "--package-path",
            str(TRINKET_CONTENT_PACKAGE),
            "AbilityInventoryDump",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        raise RuntimeError(
            "AbilityInventoryDump failed"
            + (f":\n{detail}" if detail else f" (exit {completed.returncode})")
        )

    tsv = completed.stdout
    # SPM occasionally prints build banners on stdout; keep only the TSV block.
    header = "id\tname\ttier\tsummary"
    start = tsv.find(header)
    if start < 0:
        raise RuntimeError(
            "AbilityInventoryDump stdout did not contain TSV header "
            f"{header!r}. stdout={tsv!r} stderr={completed.stderr!r}"
        )
    tsv = tsv[start:].lstrip("\n")
    if not tsv.endswith("\n"):
        tsv += "\n"

    lines = [line for line in tsv.splitlines() if line.strip()]
    if not lines or lines[0] != header:
        raise RuntimeError(f"AbilityInventoryDump produced unexpected header: {lines[:1]!r}")

    dumped_ids: set[str] = set()
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) != 4:
            raise RuntimeError(f"AbilityInventoryDump row must have 4 columns: {line!r}")
        ability_id, name, tier, summary = parts
        if not ability_id or not name or tier not in VALID_TIERS or not summary:
            raise RuntimeError(f"AbilityInventoryDump row invalid: {line!r}")
        if ability_id in dumped_ids:
            raise RuntimeError(f"AbilityInventoryDump duplicate id: {ability_id}")
        dumped_ids.add(ability_id)

    if dumped_ids != expected_ids:
        missing = sorted(expected_ids - dumped_ids)
        extra = sorted(dumped_ids - expected_ids)
        raise RuntimeError(
            "AbilityInventoryDump IDs do not match authored catalogs: "
            f"missing={missing!r} extra={extra!r}"
        )

    expected_by_id = {ability_id: (name, tier) for ability_id, name, tier in expected}
    for line in lines[1:]:
        ability_id, name, tier, _summary = line.split("\t")
        expected_name, expected_tier = expected_by_id[ability_id]
        if name != expected_name or tier != expected_tier:
            raise RuntimeError(
                f"AbilityInventoryDump metadata mismatch for {ability_id}: "
                f"got name={name!r} tier={tier!r}, "
                f"expected name={expected_name!r} tier={expected_tier!r}"
            )

    out = GENERATED_DIR / "AbilityInventory.generated.tsv"
    # Skip rewrite when unchanged so generate no-ops do not bump mtimes under
    # Packages/TrinketContent (Xcode watches the package tree).
    if out.exists() and out.read_text(encoding="utf-8") == tsv:
        return
    out.write_text(tsv)



def main() -> int:
    if len(sys.argv) > 2:
        raise SystemExit("Usage: content_codegen.py [validate|shorthand]")
    command = sys.argv[1] if len(sys.argv) > 1 else "all"
    if command not in {"all", "validate", "shorthand"}:
        raise SystemExit(f"Unknown command: {command}. Usage: content_codegen.py [validate|shorthand]")
    if command == "validate":
        (
            affix_rows,
            trait_rows,
            stage_rows,
            combatant_rows,
            enemy_rows,
            homestead_rows,
            item_base_rows,
        ) = validate_manifests()
        ability_count = len(collect_ability_symbols())
        print(
            f"Validated {len(affix_rows)} affixes, "
            f"{len(trait_rows)} traits, "
            f"{ability_count} abilities, "
            f"{len(stage_rows)} stages, "
            f"{len(combatant_rows)} combatants, "
            f"{len(enemy_rows)} enemies, "
            f"{len(homestead_rows)} homestead tiers, and "
            f"{len(item_base_rows)} item bases"
        )
        return 0
    if command == "shorthand":
        generate_ability_shorthand()
        generate_ability_inventory()
        print("Generated AbilityShorthand.generated.swift and AbilityInventory.generated.tsv")
        return 0

    (
        affix_rows,
        trait_rows,
        stage_rows,
        combatant_rows,
        enemy_rows,
        homestead_rows,
        item_base_rows,
    ) = validate_manifests()
    generate_affix_catalog(affix_rows)
    generate_traits_catalog(trait_rows)
    generate_chapters_catalog(stage_rows)
    generate_stages_index()
    generate_roster_catalog(combatant_rows)
    generate_enemies_catalog(enemy_rows)
    generate_homestead_catalog(homestead_rows)
    generate_item_bases_catalog(item_base_rows)
    generate_encounter_art_catalog(stage_rows)
    generate_trigger_families()
    talent_rows = parse_talent_rows()
    generate_talent_catalog(talent_rows, [row.id for row in combatant_rows])
    generate_ability_shorthand()
    generate_ability_inventory()
    generate_ability_index()
    ability_count = len(collect_ability_symbols())
    trigger_family_count = len(_trigger_families())
    print(
        f"Generated {len(affix_rows)} affixes, "
        f"{len(trait_rows)} traits, "
        f"{ability_count} abilities, "
        f"{len(stage_rows)} stages, "
        f"{len(combatant_rows)} combatants, "
        f"{len(enemy_rows)} enemies, "
        f"{len(homestead_rows)} homestead tiers, "
        f"{len(item_base_rows)} item bases, "
        f"{len(talent_rows)} talents, and "
        f"{trigger_family_count} trigger families"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
