"""Homestead content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass
import functools

from internal.content.common import (
    GENERATED_DIR,
    MANIFEST_DIR,
    VALID_HOMESTEAD_RESOURCES,
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
    prerequisites: str
    tier: str
    stage_name: str
    cost: str
    bonus_title: str
    bonus_description: str
    modifiers: str
    production: str


@functools.cache
def parse_homestead_node_rows() -> list[HomesteadNodeRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'homestead_nodes.tsv',
        ['node_id', 'title', 'summary', 'icon_id', 'category', 'prerequisites', 'tier', 'stage_name', 'cost', 'bonus_title', 'bonus_description', 'modifiers', 'production'], HomesteadNodeRow, min_columns=None)


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
                parse_homestead_production_value(row.production)
            except ValueError as error:
                raise ValueError(f"{error} for {row_id}") from error
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
