"""Homestead content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass

from internal.content.common import (
    GENERATED_DIR,
    MANIFEST_DIR,
    _parse_tsv_rows,
    _require_non_empty,
    _validate_positive_int,
    _validate_game_icon,
    list_catalog_property,
    parse_material_rewards,
    parse_material_tokens,
    swift_escape,
    write_generated_file,
)
from internal.content.content_codegen_modifiers import modifier_field_key
from internal.content.content_codegen_modifiers import modifier_token_to_swift
from internal.content.content_codegen_modifiers import parse_modifier_tokens


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
    "runesmithWorkshop",
    "alchemyLab",
    "crystalGarden",
    "transmutationCrucible",
    "mycologyCellar",
    "hunterLodge",
    "agilityTraining",
    "sparringGrounds",
    "archeryRange",
    "moonlitSanctum",
    "wishingWell",
    "library",
    "leylineEnergy",
)


VALID_HOMESTEAD_NODE_IDS = frozenset(HOMESTEAD_NODE_ORDER)


@dataclass
class HomesteadNodeRow:
    node_id: str
    title: str
    summary: str
    icon_id: str
    category: str
    tier: str
    stage_name: str
    cost: str
    bonus_title: str
    bonus_description: str
    modifiers: str
    production: str


def parse_homestead_node_rows() -> list[HomesteadNodeRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'homestead_nodes.tsv', HomesteadNodeRow)


def parse_homestead_combat_tokens(
    raw: str,
) -> tuple[list[str], list[str], dict[str, int]]:
    hero: list[str] = []
    companion: list[str] = []
    bonuses: dict[str, int] = {"astral_chance": 0, "gold_find": 0}
    seen: dict[tuple | str, str] = {}
    for token in parse_modifier_tokens(raw):
        name, _, amount = token.partition(":")
        if name in HOMESTEAD_BONUS_FIELDS:
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
            if name not in {"astral_chance", "gold_find"} and number <= 0:
                raise ValueError(f"Homestead bonus {name} must be positive")
            bonuses[name] = number
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
    if not hero and not companion and not any(bonuses.values()):
        raise ValueError("homestead modifiers must declare combat bonuses")
    return hero, companion, bonuses


HOMESTEAD_BONUS_FIELDS = {
    "astral_chance": "astralChanceBonusPercent",
    "gold_find": "goldFindPercent",
    "gold_find_flat": "goldFindFlat",
    "experience": "experienceBonus",
    "gems_find": "gemsFindBonus",
    "gems_find_percent": "gemsFindPercent",
    "experience_percent": "experienceBonusPercent",
}


def render_homestead_combat_bonus(raw: str) -> str:
    hero, companion, bonuses = parse_homestead_combat_tokens(raw)
    parts: list[str] = []
    if hero:
        parts.append(f"heroModifiers: [{', '.join(hero)}]")
    if companion:
        parts.append(f"companionModifiers: [{', '.join(companion)}]")
    parts.extend(f"{HOMESTEAD_BONUS_FIELDS[name]}: {value}" for name, value in bonuses.items() if value)
    return "HomesteadTierCombatBonus(" + ", ".join(parts) + ")"


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


def parse_homestead_production(raw: str) -> str | None:
    if not raw.strip():
        return None
    if any(not token.strip() for token in raw.split("|")):
        raise ValueError("Production entries must not be empty")
    entries = parse_material_tokens(raw)
    if any(quantity <= 0 for _, quantity in entries):
        raise ValueError("Production quantity must be positive")
    resources = [resource for resource, _ in entries]
    if len(set(resources)) != len(resources):
        raise ValueError("Duplicate production resource")
    return "[" + ", ".join(f"ResourceAmount(.{resource}, {quantity})" for resource, quantity in entries) + "]"


def render_homestead_node(node_id: str, rows: list[HomesteadNodeRow]) -> str:
    meta = rows[0]
    tier_blocks = ",\n".join(render_homestead_tier(row) for row in sorted(rows, key=lambda row: int(row.tier)))
    return f"""        HomesteadNodeDefinition(
            id: .{node_id},
            title: "{swift_escape(meta.title)}",
            summary: "{swift_escape(meta.summary)}",
            iconID: "{swift_escape(meta.icon_id)}",
            category: .{meta.category},
            tiers: [
{tier_blocks}
            ]
        )"""


def validate_homestead_cost(raw: str, row_id: str) -> None:
    if not raw.strip():
        raise ValueError(f"cost is required for {row_id}")
    try:
        entries = parse_material_tokens(raw)
        if not entries:
            raise ValueError("Cost must declare at least one resource")
        if any(quantity < 0 for _, quantity in entries):
            raise ValueError("Cost quantities must be non-negative")
    except ValueError as error:
        raise ValueError(f"{error} for {row_id}") from error


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
            try:
                parse_homestead_production(row.production)
            except ValueError as error:
                raise ValueError(f"{error} for {row_id}") from error
        nodes.setdefault(row.node_id, []).append(row)

    for node_id, node_rows in nodes.items():
        if len({(row.title, row.summary, row.icon_id, row.category) for row in node_rows}) != 1:
            raise ValueError(f"Homestead node metadata must be consistent for {node_id}")

        tiers = sorted(int(row.tier) for row in node_rows)
        expected = list(range(1, len(tiers) + 1))
        if tiers != expected:
            raise ValueError(f"Homestead node {node_id} tiers must be numbered 1...N contiguously")

    if set(nodes) != VALID_HOMESTEAD_NODE_IDS:
        missing = VALID_HOMESTEAD_NODE_IDS - set(nodes)
        if missing:
            raise ValueError(f"Homestead manifest missing nodes: {sorted(missing)}")


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
