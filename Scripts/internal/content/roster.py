"""Roster content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass
import functools

from internal.content.abilities import (
    ability_symbols_swift,
    collect_ability_tiers,
    parse_ability_symbol_list,
)
from internal.content.common import (
    GENERATED_DIR,
    MANIFEST_DIR,
    _ensure_unique,
    _parse_tsv_rows,
    _require_non_empty,
    _validate_positive_int,
    _validate_snake_id,
    _validate_swift_symbol,
    list_catalog_property,
    swift_escape,
    write_generated_file,
)
from internal.content.content_codegen_modifiers import modifiers_swift
from internal.content.content_codegen_triggers import triggers_swift


VALID_ROLES = frozenset({"hero", "companion"})


VALID_GROWTH_ARCHETYPES = frozenset({"tank", "assassin", "mage", "support", "bruiser"})


VALID_ENEMY_FACTIONS = frozenset(
    {"mortal", "beast", "elemental", "construct", "undead", "corrupted"}
)


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


@functools.cache
def parse_trait_rows() -> list[TraitRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'traits.tsv',
        ['id', 'name', 'description', 'modifiers', 'triggers'], TraitRow, min_columns=None)


@functools.cache
def parse_combatant_rows() -> list[CombatantRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'combatants.tsv',
        ['id', 'name', 'role', 'max_health', 'max_mana', 'basics', 'skills', 'ultimates'], CombatantRow, min_columns=None)


@functools.cache
def parse_enemy_rows() -> list[EnemyRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'enemies.tsv',
        ['id', 'name', 'max_health', 'is_boss', 'abilities', 'trait_id', 'faction'], EnemyRow, min_columns=None)


def primary_stats_swift(row: CombatantRow) -> str:
    return "PrimaryStats()"


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
        _ensure_unique(seen, row.id, "trait id")

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
        _ensure_unique(seen, row.id, "combatant id")

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
        _ensure_unique(seen, row.id, "enemy id")
        if row.id in combatant_ids:
            raise ValueError(f"Enemy id '{row.id}' conflicts with a hero/companion combatant id")

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
