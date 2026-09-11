#!/usr/bin/env python3
"""Generate Trinket content catalogs from ContentManifest TSV files."""

from __future__ import annotations

import functools
import csv
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from content_codegen_modifiers import (
    VALID_KEYWORDS,
    modifier_field_key,
    modifier_token_to_swift,
    modifiers_swift,
    parse_modifier_tokens,
    reject_duplicate_modifier_tokens,
)
from content_codegen_triggers import (
    _trigger_families,
    triggers_swift,
)

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_DIR = ROOT / "ContentManifest"
GENERATED_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Generated"
CONTENT_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Content"
TRINKET_CONTENT_PACKAGE = ROOT / "Packages" / "TrinketContent"
ABILITY_INVENTORY_STAMP = ROOT / ".DerivedData" / "AbilityInventory.stamp"


VALID_SLOTS = frozenset({"weapon", "armor", "accessory", "trinket"})
VALID_TIERS = frozenset({"basic", "skill", "ultimate"})
VALID_ENCOUNTERS = frozenset(
    {"battle", "shop", "mystery", "recruit", "random_battle"}
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
HOMESTEAD_NODE_ORDER = (
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
)
VALID_HOMESTEAD_NODE_IDS = frozenset(HOMESTEAD_NODE_ORDER)
SWIFT_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_KEBAB_BODY = r"[a-z0-9]+(?:-[a-z0-9]+)*"
KEBAB_IDENTIFIER = re.compile(rf"^{_KEBAB_BODY}$")
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
    basics: str
    skills: str
    ultimates: str


@dataclass
class EnemyRow:
    id: str
    name: str
    max_health: str
    is_boss: str
    abilities: str
    trait_id: str
    faction: str


@dataclass
class HomesteadNodeRow:
    node_id: str
    title: str
    summary: str
    icon_id: str
    category: str
    prerequisites: str
    tier: str
    stage_name: str
    cost: str
    bonus_title: str
    bonus_description: str
    modifiers: str
    production: str


@functools.cache
def _read_tsv_cached(path: Path) -> tuple[tuple[str, ...], ...]:
    rows: list[tuple[str, ...]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for fields in csv.reader(handle, delimiter="\t"):
            if not fields or (len(fields) == 1 and not fields[0]):
                continue
            if fields[0].startswith("#"):
                continue
            rows.append(tuple(fields))
    return tuple(rows)


def read_tsv(path: Path) -> list[list[str]]:
    return [list(row) for row in _read_tsv_cached(path)]


def _parse_tsv_rows(path: Path, expected: list[str], row_type, min_columns: int | None = None):
    lines = read_tsv(path)
    header = lines[0]
    if header != expected:
        raise ValueError(f"{path} header mismatch: {header}")
    min_cols = min_columns if min_columns is not None else len(expected)
    rows: list = []
    for idx, raw in enumerate(lines[1:], start=2):
        if len(raw) < min_cols:
            raise ValueError(f"{path}:{idx} missing required columns: expected at least {min_cols}, got {len(raw)}")
        if len(raw) > len(expected):
            raise ValueError(f"{path}:{idx} has {len(raw)} columns, expected {len(expected)}")
        padded = raw + [""] * (len(expected) - len(raw))
        rows.append(row_type(*padded[: len(expected)]))
    return rows


# Trailing DSL columns may be omitted (no trailing tabs required); missing
# trailing values parse as "". Affixes carry two trailing trigger columns,
# talents carry trailing modifiers/triggers. All other manifests require
# full-width rows.
AFFIX_REQUIRED_COLUMNS = 9
TALENT_REQUIRED_COLUMNS = 4


def read_manifest_table(path: Path) -> tuple[list[str], list[list[str]]]:
    """Shared #-header TSV reader for media manifests.

    Skips blank lines and #-comments; the first content row is the header with
    its leading # stripped. Ragged rows are rejected so truncated inputs fail
    fast instead of silently dropping columns.
    """
    with path.open(newline="", encoding="utf-8") as handle:
        raw_rows = list(csv.reader(handle, delimiter="\t"))
    header: list[str] = []
    rows: list[list[str]] = []
    for line_number, row in enumerate(raw_rows, start=1):
        if not row or (len(row) == 1 and not row[0].strip()):
            continue
        if not header:
            if not row[0].lstrip().startswith("#"):
                raise ValueError(f"{path}:{line_number} manifest header must start with #")
            header = [row[0].lstrip("#").strip()] + [cell.strip() for cell in row[1:]]
            continue
        if row[0].lstrip().startswith("#"):
            continue
        if len(row) != len(header):
            raise ValueError(
                f"{path}:{line_number} has {len(row)} columns, expected {len(header)}"
            )
        rows.append([cell.strip() for cell in row])
    if not header:
        raise ValueError(f"{path} has no header row")
    return header, rows


ART_MANIFEST = ROOT / "ArtManifest" / "curated-assets.tsv"


@functools.cache
def collect_art_ids() -> set[str]:
    header, rows = read_manifest_table(ART_MANIFEST)
    if "id" not in header:
        raise ValueError(f"{ART_MANIFEST} header must declare an id column")
    id_index = header.index("id")
    return {row[id_index] for row in rows}


@functools.cache
def _read_content_source(name: str) -> str:
    return (CONTENT_DIR / name).read_text(encoding="utf-8")


@functools.cache
def collect_mystery_event_ids() -> set[str]:
    ids: set[str] = set()
    for name in ("MysteryEventPool+Wilds.swift", "MysteryEventPool+Relics.swift"):
        ids.update(re.findall(r'makeEvent\(\s*id:\s*"([^"]+)"', _read_content_source(name)))
    if not ids:
        raise ValueError("mystery event id scrape found no ids; update collect_mystery_event_ids")
    return ids


@functools.cache
def collect_recruit_event_ids() -> set[str]:
    ids = set(re.findall(r'recruit\(\s*id:\s*"([^"]+)"', _read_content_source("RecruitEventPool.swift")))
    if not ids:
        raise ValueError("recruit event id scrape found no ids; update collect_recruit_event_ids")
    return ids


@functools.cache
def parse_affix_rows() -> list[AffixRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "affixes.tsv",
        [
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
        ],
        AffixRow,
        min_columns=AFFIX_REQUIRED_COLUMNS,
    )


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
            "basics",
            "skills",
            "ultimates",
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
            "icon_id",
            "category",
            "prerequisites",
            "tier",
            "stage_name",
            "cost",
            "bonus_title",
            "bonus_description",
            "modifiers",
            "production",
        ],
        HomesteadNodeRow,
    )


def swift_escape(value: str) -> str:
    """Escape a manifest string for a Swift literal.

    Manifests spell newlines as a literal backslash-n (see homestead bonus
    descriptions); those become real newlines first so the final pass escapes
    every backslash, quote, and newline exactly once.
    """
    value = value.replace("\\n", "\n")
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def parse_keywords(raw: str) -> str:
    if not raw:
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f".{part}" for part in parts) + "]"


def write_generated_file(path: Path, body: str) -> None:
    content = (
        "// Generated by Scripts/content_codegen.py — do not edit.\n"
        "import Foundation\n"
        "import TrinketCore\n\n"
        f"{body}\n"
    )
    write_if_changed(path, content)


def write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Skip rewrite when content is unchanged so mtimes do not invalidate dependents.
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def list_catalog_property(
    prop: str, item_type: str, entries: list[str], chunk_size: int | None = None
) -> str:
    if chunk_size is None:
        appends = "\n".join(f"        list.append({entry.strip()})" for entry in entries)
        return (
            f"    static let {prop}: [{item_type}] = {{\n"
            f"        var list = [{item_type}]()\n"
            f"        list.reserveCapacity({len(entries)})\n"
            + appends
            + "\n        return list\n"
            "    }()\n"
        )
    chunks = [entries[index:index + chunk_size] for index in range(0, len(entries), chunk_size)]
    chunk_appends = "\n".join(
        f"        list.append(contentsOf: chunk{index}())" for index in range(len(chunks))
    )
    chunk_functions = "\n\n".join(
        "    private static func chunk"
        f"{index}() -> [{item_type}] {{\n"
        "        [\n"
        + ",\n".join(entry for entry in chunk)
        + "\n        ]\n"
        "    }"
        for index, chunk in enumerate(chunks)
    )
    return (
        f"    static let {prop}: [{item_type}] = {{\n"
        f"        var list = [{item_type}]()\n"
        f"        list.reserveCapacity({len(entries)})\n"
        + chunk_appends
        + "\n        return list\n"
        "    }()\n"
        "\n"
        + chunk_functions
        + "\n"
    )


def generate_affix_catalog(rows: list[AffixRow]) -> None:
    entries: list[str] = []
    for row in rows:
        entries.append(
            "        ItemAffixCatalog.affix(\n"
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
        + list_catalog_property("definitions", "ItemAffixDefinition", entries, chunk_size=16)
        + "}\n"
    )
    write_generated_file(GENERATED_DIR / "ItemAffixCatalog.generated.swift", body)


ABILITY_DECL_BUILDERS = r"(?:Ability\(|AbilityBuilder\.(?:directHit|buffOnly|multiDamage)\()"


@functools.cache
def _read_ability_source(tier: str) -> str:
    return (CONTENT_DIR / f"AbilityCatalog{tier}.swift").read_text()


def ability_symbols_in_source(source: str) -> list[str]:
    return re.findall(rf"static let (\w+) = {ABILITY_DECL_BUILDERS}", source)


def collect_ability_symbols() -> set[str]:
    return set(collect_ability_tiers())


def collect_ability_tiers() -> dict[str, str]:
    tiers: dict[str, str] = {}
    for tier in ("Basic", "Skill", "Ultimate"):
        tier_name = tier.lower()
        for symbol in ability_symbols_in_source(_read_ability_source(tier)):
            previous = tiers.setdefault(symbol, tier_name)
            if previous != tier_name:
                raise ValueError(
                    f"Ability symbol '{symbol}' appears in both {previous} and {tier_name} catalogs"
                )
    return tiers



def parse_ability_symbol_list(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def ability_symbols_swift(raw: str) -> str:
    symbols = parse_ability_symbol_list(raw)
    return "[" + ", ".join(f".{symbol}" for symbol in symbols) + "]"


def primary_stats_swift(row: CombatantRow) -> str:
    return "PrimaryStats()"


def _validate_snake_id(label: str, value: str, row_id: str) -> None:
    if not SNAKE_IDENTIFIER.match(value):
        raise ValueError(
            f"{label} '{value}' for {row_id} must use lowercase letters, numbers, and underscores"
        )


def _validate_positive_int(label: str, value: str, row_id: str, minimum: int = 0) -> None:
    if not value.isdigit():
        raise ValueError(f"{label} for {row_id} must be an integer")
    if int(value) < minimum:
        if minimum == 1:
            raise ValueError(f"{label} for {row_id} must be positive")
        raise ValueError(f"{label} for {row_id} must be non-negative")


def _validate_ability_symbols(
    raw: str,
    row_id: str,
    ability_symbols: set[str],
    expected_count: int | None = None,
    expected_tier: str | None = None,
    ability_tiers: dict[str, str] | None = None,
) -> None:
    symbols = parse_ability_symbol_list(raw)
    if expected_count is not None and len(symbols) != expected_count:
        raise ValueError(f"{row_id} must list exactly {expected_count} ability symbols")
    if len(set(symbols)) != len(symbols):
        raise ValueError(f"{row_id} must not repeat an ability symbol within a tier")
    for symbol in symbols:
        _validate_swift_symbol("ability symbol", symbol, row_id)
        if symbol not in ability_symbols:
            raise ValueError(f"Unknown ability symbol '{symbol}' for {row_id}")
        if expected_tier is not None and ability_tiers is not None and ability_tiers[symbol] != expected_tier:
            raise ValueError(
                f"Ability symbol '{symbol}' for {row_id} belongs to the {ability_tiers[symbol]} tier, "
                f"not {expected_tier}"
            )


def validate_trait_rows(rows: list[TraitRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate trait id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("trait id", row.id, row.id)
        _require_non_empty("trait name", row.name, row.id)
        _require_non_empty("trait description", row.description, row.id)

        modifiers_swift(row.modifiers, row.id)
        triggers_swift(row.triggers, row.id)


def validate_combatant_rows(
    rows: list[CombatantRow],
    ability_symbols: set[str],
    ability_tiers: dict[str, str] | None = None,
) -> None:
    ability_tiers = ability_tiers or collect_ability_tiers()
    seen: set[str] = set()
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate combatant id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("combatant id", row.id, row.id)
        _require_non_empty("combatant name", row.name, row.id)
        if row.role not in VALID_ROLES:
            raise ValueError(f"Invalid combatant role '{row.role}' for {row.id}")

        _validate_positive_int("max_health", row.max_health, row.id)
        if int(row.max_health) < 6:
            raise ValueError(f"max_health for {row.id} must be at least 6")
        _validate_positive_int("max_mana", row.max_mana, row.id)

        _validate_ability_symbols(
            row.basics,
            row.id,
            ability_symbols,
            expected_count=4,
            expected_tier="basic",
            ability_tiers=ability_tiers,
        )
        _validate_ability_symbols(
            row.skills,
            row.id,
            ability_symbols,
            expected_count=4,
            expected_tier="skill",
            ability_tiers=ability_tiers,
        )
        _validate_ability_symbols(
            row.ultimates,
            row.id,
            ability_symbols,
            expected_count=4,
            expected_tier="ultimate",
            ability_tiers=ability_tiers,
        )
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

        _validate_positive_int("max_health", row.max_health, row.id, minimum=1)


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
            )
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
        f"abilities: {ability_symbols_swift(row.abilities)}), "
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

    body = (
        "enum GameContentTraitsGenerated {\n"
        + list_catalog_property("definitions", "CombatantTraitDefinition", entries)
        + "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentTraits.generated.swift", body)


def generate_roster_catalog(rows: list[CombatantRow]) -> None:
    heroes = [row for row in rows if row.role == "hero"]
    companions = [row for row in rows if row.role == "companion"]
    body = (
        "enum GameContentRosterGenerated {\n"
        + list_catalog_property(
            "heroes", "Combatant", [render_party_combatant(row) for row in heroes]
        )
        + "\n"
        + list_catalog_property(
            "companions", "Combatant", [render_party_combatant(row) for row in companions]
        )
        + "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentRoster.generated.swift", body)


def generate_enemies_catalog(rows: list[EnemyRow]) -> None:
    body = (
        "enum GameContentEnemiesGenerated {\n"
        + list_catalog_property("enemies", "Enemy", [render_enemy(row) for row in rows])
        + "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentEnemies.generated.swift", body)


def _require_non_empty(label: str, value: str, row_id: str) -> None:
    if not value.strip():
        raise ValueError(f"{label} is required for {row_id}")


def _validate_swift_symbol(label: str, value: str, row_id: str) -> None:
    if not SWIFT_IDENTIFIER.match(value):
        raise ValueError(f"{label} '{value}' for {row_id} must be a valid Swift identifier")


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
        modifiers_swift(row.basic_modifiers, row.id)
        modifiers_swift(row.astral_modifiers, row.id)
        triggers_swift(row.basic_triggers, row.id)
        triggers_swift(row.astral_triggers, row.id)


def parse_item_templates(raw: str) -> str:
    if not raw.strip():
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f'"{swift_escape(part)}"' for part in parts) + "]"


def parse_material_tokens(raw: str) -> list[tuple[str, int]]:
    tokens: list[tuple[str, int]] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        if ":" not in token:
            raise ValueError(f"Cost entry {token!r} must be resource:amount")
        resource, quantity = token.split(":", 1)
        resource = resource.strip()
        if resource not in VALID_HOMESTEAD_RESOURCES:
            raise ValueError(f"Unknown homestead resource '{resource}'")
        try:
            amount = int(quantity.strip())
        except ValueError as error:
            raise ValueError(f"Cost quantity {quantity.strip()!r} must be an integer") from error
        tokens.append((resource, amount))
    return tokens


def parse_material_rewards(raw: str) -> str:
    if not raw.strip():
        return "[]"
    amounts = [
        f"ResourceAmount(.{resource}, {quantity})"
        for resource, quantity in parse_material_tokens(raw)
    ]
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


def validate_stage_rows(
    rows: list[StageRow],
    enemy_ids: set[str] | None = None,
    mystery_event_ids: set[str] | None = None,
    recruit_event_ids: set[str] | None = None,
    art_ids: set[str] | None = None,
) -> None:
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
        if (
            row.encounter == "mystery"
            and row.enemy_id.strip()
            and mystery_event_ids is not None
            and row.enemy_id not in mystery_event_ids
        ):
            raise ValueError(f"Stage {stage_id} references unknown mystery event '{row.enemy_id}'")
        if row.encounter == "recruit" and row.enemy_id.strip():
            if (
                row.enemy_id != RANDOM_COMPANION_RECRUIT_ID
                and recruit_event_ids is not None
                and row.enemy_id not in recruit_event_ids
            ):
                raise ValueError(
                    f"Stage {stage_id} references unknown recruit event '{row.enemy_id}'"
                )
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
        if (
            row.encounter_art_id.strip()
            and art_ids is not None
            and row.encounter_art_id not in art_ids
        ):
            raise ValueError(
                f"Stage {stage_id} references unknown encounter art '{row.encounter_art_id}'"
            )

        for field_name, value in (
            ("chapter_number", row.chapter_number),
            ("stage_number", row.stage_number),
        ):
            _validate_positive_int(field_name, value, stage_id, minimum=1)

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
        + list_catalog_property("chapters", "Chapter", chapter_blocks)
        + "}\n"
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
        "add_excess": lambda n: f"        {n} += other.{n} - 1",
        "or": lambda n: f"        {n} = {n} || other.{n}",
        "max": lambda n: f"        {n} = max({n}, other.{n})",
        "coalesce": lambda n: f"        {n} = other.{n} ?? {n}",
        "union": lambda n: (
            f"        if !other.{n}.isEmpty {{\n"
            f"            {n} = {n}.isEmpty ? other.{n}.sorted() : Array(Set({n}).union(other.{n})).sorted()\n"
            "        }"
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
        write_if_changed(out, text)


def generate_trigger_root() -> None:
    families = _trigger_families()
    pairs = [(family["family"], family["file_stem"]) for family in families]
    field_decls = "\n".join(f"        var {fid}: {tname}" for fid, tname in pairs)
    default_inits = ",\n".join(
        f"            {fid}: {tname}()" for fid, tname in pairs
    )
    init_params = ",\n".join(
        f"        {fid}: {tname} = {tname}()" for fid, tname in pairs
    )
    init_assigns = ",\n".join(f"            {fid}: {fid}" for fid, _ in pairs)
    subscripts = "\n\n".join(
        f"""    public subscript<T>(dynamicMember keyPath: KeyPath<{tname}, T>) -> T {{
        _read {{ yield storage.value.{fid}[keyPath: keyPath] }}
    }}

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<{tname}, T>) -> T {{
        _read {{ yield storage.value.{fid}[keyPath: keyPath] }}
        set {{
            fields.{fid}[keyPath: keyPath] = newValue
        }}
    }}"""
        for fid, tname in pairs
    )
    all_names = "\n            + ".join(f"{tname}.fieldNames" for _, tname in pairs)
    populated = "\n            + ".join(
        f"fields.{fid}.populatedFieldNames(comparedTo: {tname}())"
        for fid, tname in pairs
    )
    merges = "\n".join(
        f"        fields.{fid}.merge(other.fields.{fid})" for fid, _ in pairs
    )
    decode_args = ",\n".join(
        f"            {fid}: {tname}(from: values)" for fid, tname in pairs
    )
    encodes = "\n".join(
        f"        try fields.{fid}.encode(to: &container)" for fid, _ in pairs
    )
    text = f"""// Generated by Scripts/content_codegen.py — do not edit.
import Foundation
import TrinketCore

@dynamicMemberLookup
public struct CombatTraitTriggers: Codable, @unchecked Sendable, Equatable, Hashable {{
    struct Fields: Equatable, Hashable, Sendable {{
{field_decls}
    }}

    private final class Storage {{
        var value: Fields

        init(_ value: Fields) {{
            self.value = value
        }}
    }}

    private var storage: Storage

    var fields: Fields {{
        _read {{ yield storage.value }}
        _modify {{
            if !isKnownUniquelyReferenced(&storage) {{
                storage = Storage(storage.value)
            }}
            yield &storage.value
        }}
    }}

    public init() {{
        storage = Storage(Fields(
{default_inits}
        ))
    }}

    public init(
{init_params}
    ) {{
        storage = Storage(Fields(
{init_assigns}
        ))
    }}

    public static func == (lhs: Self, rhs: Self) -> Bool {{
        lhs.fields == rhs.fields
    }}

    public func hash(into hasher: inout Hasher) {{
        hasher.combine(fields)
    }}

{subscripts}

    public static var allFieldNames: [String] {{
        {all_names}
    }}

    public var populatedFieldNames: [String] {{
        {populated}
    }}

    public mutating func merge(_ other: Self) {{
{merges}
    }}

    public func merged(with other: Self) -> Self {{
        var copy = self
        copy.merge(other)
        return copy
    }}

    public init(from decoder: Decoder) throws {{
        let values = try DefaultingTriggerDecoder(decoder)
        try self.init(
{decode_args}
        )
    }}

    public func encode(to encoder: Encoder) throws {{
        var container = encoder.container(keyedBy: TriggerCodingKey.self)
{encodes}
    }}
}}
"""
    out = GENERATED_DIR / "CombatTraitTriggers.generated.swift"
    write_if_changed(out, text)


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
    seen: dict[tuple[str, str | None], str] = {}
    for token in parse_modifier_tokens(raw):
        if token.startswith("astral_chance:") or token.startswith("gold_find:"):
            name, _, amount = token.partition(":")
            if name in seen:
                raise ValueError(
                    f"Duplicate homestead bonus {name!r}: {token!r} repeats {seen[name]!r}"
                )
            seen[name] = token
            try:
                number = int(amount.strip())
            except ValueError as error:
                raise ValueError(
                    f"Homestead bonus {name!r} must be an integer, got {amount!r}"
                ) from error
            if name == "astral_chance":
                astral = number
            else:
                gold = number
            continue
        scope = "both"
        body = token
        if token.startswith("hero."):
            scope = "hero"
            body = token.removeprefix("hero.")
        elif token.startswith("companion."):
            scope = "companion"
            body = token.removeprefix("companion.")
        key = (scope, *modifier_field_key(body))
        if key in seen:
            raise ValueError(
                f"Duplicate homestead bonus for {key[0]!r} scope: "
                f"{token!r} repeats {seen[key]!r}; merge into one token"
            )
        seen[key] = token
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


def parse_homestead_prereq_tokens(raw: str) -> list[tuple[str, int | None]]:
    requirements: list[tuple[str, int | None]] = []
    for token in raw.split("|"):
        token = token.strip()
        if not token:
            continue
        if ":" in token:
            node_id, tier = token.split(":", 1)
            try:
                tier_value: int | None = int(tier.strip())
            except ValueError as error:
                raise ValueError(
                    f"Prerequisite tier {tier.strip()!r} must be an integer"
                ) from error
            requirements.append((node_id.strip(), tier_value))
        else:
            requirements.append((token, None))
    return requirements


def parse_homestead_prerequisites(raw: str) -> str:
    if not raw.strip():
        return "[]"
    requirements = []
    for node_id, tier in parse_homestead_prereq_tokens(raw):
        if tier is None:
            requirements.append(f"HomesteadNodeRequirement(.{node_id})")
        else:
            requirements.append(f"HomesteadNodeRequirement(.{node_id}, tier: {tier})")
    return "[" + ", ".join(requirements) + "]"


def render_homestead_tier(row: HomesteadNodeRow) -> str:
    production = parse_homestead_production(row.production)
    production_line = f",\n                    production: {production}" if production else ""
    return f"""                HomesteadNodeTier(
                    tier: {row.tier},
                    stageName: "{swift_escape(row.stage_name)}",
                    cost: {parse_material_rewards(row.cost)},
                    bonus: HomesteadBonus(
                        title: "{swift_escape(row.bonus_title)}",
                        description: "{swift_escape(row.bonus_description)}"
                    ),
                    combatBonus: {render_homestead_combat_bonus(row.modifiers)}{production_line}
                )"""


def parse_homestead_production_value(raw: str) -> tuple[str, int] | None:
    if not raw.strip():
        return None
    if ":" not in raw:
        raise ValueError(f"Production entry {raw.strip()!r} must be resource:quantity")
    resource, quantity = raw.split(":", 1)
    resource = resource.strip()
    if resource not in VALID_HOMESTEAD_RESOURCES:
        raise ValueError(f"Unknown production resource '{resource}'")
    try:
        amount = int(quantity.strip())
    except ValueError as error:
        raise ValueError(f"Production quantity {quantity.strip()!r} must be an integer") from error
    if amount <= 0:
        raise ValueError("Production quantity must be positive")
    return resource, amount


def parse_homestead_production(raw: str) -> str | None:
    parsed = parse_homestead_production_value(raw)
    if parsed is None:
        return None
    resource, quantity = parsed
    return f"ResourceAmount(.{resource}, {quantity})"


def render_homestead_node(node_id: str, rows: list[HomesteadNodeRow]) -> str:
    meta = rows[0]
    tier_blocks = ",\n".join(render_homestead_tier(row) for row in sorted(rows, key=lambda row: int(row.tier)))
    return f"""        HomesteadNodeDefinition(
            id: .{node_id},
            title: "{swift_escape(meta.title)}",
            summary: "{swift_escape(meta.summary)}",
            iconID: "{swift_escape(meta.icon_id)}",
            category: .{meta.category},
            prerequisites: {parse_homestead_prerequisites(meta.prerequisites)},
            tiers: [
{tier_blocks}
            ]
        )"""


def validate_homestead_cost(raw: str, row_id: str) -> None:
    if not raw.strip():
        raise ValueError(f"cost is required for {row_id}")
    try:
        parse_material_tokens(raw)
    except ValueError as error:
        raise ValueError(f"{error} for {row_id}") from error


def validate_homestead_prerequisites(
    raw: str, row_id: str, node_tiers: dict[str, set[int]]
) -> None:
    if not raw.strip():
        return
    try:
        requirements = parse_homestead_prereq_tokens(raw)
    except ValueError as error:
        raise ValueError(f"{error} for {row_id}") from error
    for node_id, tier_value in requirements:
        if tier_value is not None and tier_value <= 0:
            raise ValueError(f"Prerequisite tier for {row_id} must be positive")
        if node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node '{node_id}' in prerequisites for {row_id}")
        if node_id not in node_tiers:
            raise ValueError(f"Prerequisite node '{node_id}' for {row_id} is not defined in manifest")
        if tier_value is not None and tier_value not in node_tiers[node_id]:
            raise ValueError(
                f"Prerequisite tier {tier_value} for {row_id} is not defined on node '{node_id}'"
            )


def _validate_game_icon(icon_id: str, row_id: str) -> None:
    if not re.fullmatch(rf"(?:lucide:{_KEBAB_BODY}|sf:[a-z0-9]+(?:\.[a-z0-9]+)*)", icon_id):
        raise ValueError(f"Invalid icon_id '{icon_id}' for {row_id}; use lucide:name or sf:name")
    if icon_id.startswith("lucide:"):
        name = icon_id.removeprefix("lucide:")
        asset = ROOT / "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Resources/GameIcons.xcassets" / f"lucide-{name}.imageset" / "Contents.json"
        if not asset.is_file():
            raise ValueError(f"Missing bundled Lucide icon '{name}' for {row_id}")


def validate_homestead_node_rows(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    seen_tiers: set[tuple[str, int]] = set()

    for row in rows:
        row_id = f"{row.node_id}-tier-{row.tier}"
        if row.node_id not in VALID_HOMESTEAD_NODE_IDS:
            raise ValueError(f"Unknown homestead node id '{row.node_id}'")
        if row.category not in VALID_HOMESTEAD_CATEGORIES:
            raise ValueError(f"Unknown homestead category '{row.category}' for {row_id}")
        _validate_positive_int("tier", row.tier, row_id, minimum=1)
        tier_value = int(row.tier)
        if (row.node_id, tier_value) in seen_tiers:
            raise ValueError(f"Duplicate homestead tier: {row_id}")
        seen_tiers.add((row.node_id, tier_value))

        _require_non_empty("title", row.title, row_id)
        _require_non_empty("summary", row.summary, row_id)
        _validate_game_icon(row.icon_id, row_id)
        _require_non_empty("stage_name", row.stage_name, row_id)
        if len(row.stage_name.split()) > 3:
            raise ValueError(f"stage_name for {row_id} must be three words or fewer")
        _require_non_empty("bonus_title", row.bonus_title, row_id)
        _require_non_empty("bonus_description", row.bonus_description, row_id)
        _require_non_empty("modifiers", row.modifiers, row_id)
        parse_homestead_combat_tokens(row.modifiers)
        validate_homestead_cost(row.cost, row_id)
        if row.production.strip():
            if ":" not in row.production:
                raise ValueError(
                    f"Production entry {row.production!r} for {row_id} must be resource:quantity"
                )
            resource, quantity = row.production.split(":", 1)
            if resource.strip() not in VALID_HOMESTEAD_RESOURCES:
                raise ValueError(f"Unknown production resource '{resource}' for {row_id}")
            _validate_positive_int("Production quantity", quantity.strip(), row_id, minimum=1)
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
        symbols = {row.icon_id for row in node_rows}
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


def generate_homestead_catalog(rows: list[HomesteadNodeRow]) -> None:
    nodes: dict[str, list[HomesteadNodeRow]] = {}
    for row in rows:
        nodes.setdefault(row.node_id, []).append(row)

    body = (
        "enum GameContentHomesteadGenerated {\n"
        + list_catalog_property(
            "homesteadNodes",
            "HomesteadNodeDefinition",
            [render_homestead_node(node_id, nodes[node_id]) for node_id in HOMESTEAD_NODE_ORDER],
        )
        + "}\n"
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
        _validate_keywords(row.keywords, f"item base {row.id}")


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
    body = (
        "enum GameContentItemBasesGenerated {\n"
        + list_catalog_property("itemBaseTypes", "ItemBaseType", entries)
        + "}\n"
    )
    write_generated_file(GENERATED_DIR / "GameContentItemBases.generated.swift", body)


def generate_encounter_art_catalog(rows: list[StageRow]) -> None:
    entries: list[tuple[str, str, str]] = []
    for row in rows:
        if not row.encounter_art_id.strip():
            continue
        stage_id = f"{row.chapter_id}-stage-{row.stage_number}"
        entries.append((stage_id, row.encounter_art_id, row.encounter_art_title))
    capacity = len(entries)
    appends = "\n".join(
        f'        dict["{swift_escape(stage_id)}"] = (id: "{swift_escape(art_id)}", '
        f'title: "{swift_escape(art_title)}")'
        for stage_id, art_id, art_title in entries
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
    icon_id: str
    description: str
    modifiers: str
    triggers: str


@functools.cache
def parse_talent_rows() -> list[TalentRow]:
    return _parse_tsv_rows(
        MANIFEST_DIR / "talents.tsv",
        ["id", "name", "icon_id", "description", "modifiers", "triggers"],
        TalentRow,
        min_columns=TALENT_REQUIRED_COLUMNS,
    )


def combatant_id_for_talent(talent_id: str, sorted_combatant_ids: list[str]) -> str:
    for combatant_id in sorted_combatant_ids:
        if talent_id.startswith(f"{combatant_id}_"):
            return combatant_id
    raise ValueError(f"Talent {talent_id} does not match a combatant id")


def generate_talent_catalog(rows: list[TalentRow], combatant_ids: list[str]) -> None:
    sorted_cids = sorted(combatant_ids, key=len, reverse=True)
    grouped: dict[str, list[TalentRow]] = {combatant_id: [] for combatant_id in combatant_ids}
    for row in rows:
        grouped[combatant_id_for_talent(row.id, sorted_cids)].append(row)

    def render_entry(row: TalentRow) -> str:
        return (
            f'            "{swift_escape(row.id)}": CombatantTalentEffect(\n'
            f'                name: "{swift_escape(row.name)}",\n'
            f'                iconID: "{swift_escape(row.icon_id)}",\n'
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
        "public extension CombatantTalentCatalog {\n"
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


def validate_talent_rows(rows: list[TalentRow], combatant_ids: list[str] | None = None) -> None:
    seen: set[str] = set()
    sorted_cids = sorted(combatant_ids, key=len, reverse=True) if combatant_ids is not None else None
    for row in rows:
        if row.id in seen:
            raise ValueError(f"Duplicate talent id: {row.id}")
        seen.add(row.id)

        _validate_snake_id("talent id", row.id, row.id)
        if sorted_cids is not None:
            combatant_id_for_talent(row.id, sorted_cids)
        _require_non_empty("talent name", row.name, row.id)
        _validate_game_icon(row.icon_id, row.id)
        _require_non_empty("talent description", row.description, row.id)

        modifiers_swift(row.modifiers, row.id)
        triggers_swift(row.triggers, row.id)


def validate_manifests() -> tuple[
    list[AffixRow],
    list[TraitRow],
    list[StageRow],
    list[CombatantRow],
    list[EnemyRow],
    list[HomesteadNodeRow],
    list[ItemBaseRow],
    list[TalentRow],
]:
    affix_rows = parse_affix_rows()
    trait_rows = parse_trait_rows()
    combatant_rows = parse_combatant_rows()
    enemy_rows = parse_enemy_rows()
    stage_rows = parse_stage_rows()
    homestead_rows = parse_homestead_node_rows()
    item_base_rows = parse_item_base_rows()
    talent_rows = parse_talent_rows()
    ability_tiers = collect_ability_tiers()
    ability_symbols = set(ability_tiers)
    combatant_ids = [row.id for row in combatant_rows]

    validate_affix_rows(affix_rows)
    validate_trait_rows(trait_rows)
    validate_talent_rows(talent_rows, combatant_ids)
    validate_combatant_rows(combatant_rows, ability_symbols, ability_tiers)
    validate_enemy_rows(
        enemy_rows,
        ability_symbols,
        set(combatant_ids),
        {row.id for row in trait_rows},
    )
    validate_stage_rows(
        stage_rows,
        enemy_ids={row.id for row in enemy_rows},
        mystery_event_ids=collect_mystery_event_ids(),
        recruit_event_ids=collect_recruit_event_ids(),
        art_ids=collect_art_ids(),
    )
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
        talent_rows,
    )



def generate_ability_shorthand() -> None:
    entries: list[tuple[str, str]] = []
    for tier in ("Basic", "Skill", "Ultimate"):
        for symbol in ability_symbols_in_source(_read_ability_source(tier)):
            entries.append((symbol, f"AbilityCatalog{tier}.{symbol}"))

    entries.sort(key=lambda item: item[0])
    lines = [f"    static let {symbol} = {target}" for symbol, target in entries]
    body = "public extension Ability {\n" + "\n".join(lines) + "\n}\n"
    write_generated_file(GENERATED_DIR / "AbilityShorthand.generated.swift", body)


def parse_authored_ability_inventory_rows() -> list[tuple[str, str, str]]:
    """Regex-extract id/name/tier from hand ability catalogs (cross-check only)."""
    rows: list[tuple[str, str, str]] = []
    for tier_label, tier_enum in (
        ("basic", "Basic"),
        ("skill", "Skill"),
        ("ultimate", "Ultimate"),
    ):
        source = _read_ability_source(tier_enum)
        for match in re.finditer(
            rf"static let \w+ = {ABILITY_DECL_BUILDERS}\s*"
            r'id: "([^"]+)",\s*name: "([^"]+)",\s*tier: \.(\w+)',
            source,
        ):
            ability_id, name, tier = match.groups()
            if tier != tier_label:
                raise ValueError(
                    f"Ability {ability_id} tier .{tier} does not match file AbilityCatalog{tier_enum}"
                )
            rows.append((ability_id, name, tier))
    tier_rank = {"basic": 0, "skill": 1, "ultimate": 2}
    rows.sort(key=lambda item: (tier_rank[item[2]], item[1].lower()))
    return rows


def _ability_inventory_digest() -> str:
    import hashlib

    # Every input that can change dump output: catalog data plus the
    # Ability.summary implementation and the dump helper itself.
    inputs = [
        CONTENT_DIR / "AbilityCatalogBasic.swift",
        CONTENT_DIR / "AbilityCatalogSkill.swift",
        CONTENT_DIR / "AbilityCatalogUltimate.swift",
        TRINKET_CONTENT_PACKAGE / "Sources" / "TrinketContent" / "Ability.swift",
        TRINKET_CONTENT_PACKAGE / "Sources" / "AbilityInventoryDump" / "AbilityInventoryDumpMain.swift",
    ]
    hasher = hashlib.sha256()
    for p in inputs:
        if p.is_file():
            hasher.update(p.read_bytes())
    return hasher.hexdigest()


def generate_ability_inventory() -> None:
    """Dump id/name/tier/summary from Swift Ability.summary for humans/agents."""
    out = GENERATED_DIR / "AbilityInventory.generated.tsv"
    expected = parse_authored_ability_inventory_rows()
    expected_ids = {ability_id for ability_id, _, _ in expected}

    force = os.environ.get("TRINKET_FORCE_ABILITY_DUMP") == "1"
    current_digest = _ability_inventory_digest()
    if not force and out.is_file() and ABILITY_INVENTORY_STAMP.is_file():
        if ABILITY_INVENTORY_STAMP.read_text(encoding="utf-8").strip() == current_digest:
            return

    import tempfile

    with tempfile.TemporaryDirectory() as directory:
        dump_path = Path(directory) / "AbilityInventory.tsv"
        completed = subprocess.run(
            [
                "swift",
                "run",
                "--package-path",
                str(TRINKET_CONTENT_PACKAGE),
                "AbilityInventoryDump",
                str(dump_path),
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
        if not dump_path.is_file():
            raise RuntimeError(
                "AbilityInventoryDump did not write its output file. "
                f"stderr={completed.stderr!r}"
            )
        tsv = dump_path.read_text(encoding="utf-8")

    header = "id\tname\ttier\tsummary"
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

    # Skip rewrite when unchanged so generate no-ops do not bump mtimes under
    # Packages/TrinketContent (Xcode watches the package tree).
    write_if_changed(out, tsv)

    ABILITY_INVENTORY_STAMP.parent.mkdir(parents=True, exist_ok=True)
    ABILITY_INVENTORY_STAMP.write_text(current_digest, encoding="utf-8")


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
            talent_rows,
        ) = validate_manifests()
        ability_count = len(collect_ability_symbols())
        print(
            f"Validated {len(affix_rows)} affixes, "
            f"{len(trait_rows)} traits, "
            f"{ability_count} abilities, "
            f"{len(stage_rows)} stages, "
            f"{len(combatant_rows)} combatants, "
            f"{len(enemy_rows)} enemies, "
            f"{len(homestead_rows)} homestead tiers, "
            f"{len(item_base_rows)} item bases, and "
            f"{len(talent_rows)} talents"
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
        talent_rows,
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
    generate_trigger_root()
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
