"""Items content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass
import functools

from internal.content.common import (
    AFFIX_REQUIRED_COLUMNS,
    GENERATED_DIR,
    KEBAB_IDENTIFIER,
    MANIFEST_DIR,
    SNAKE_IDENTIFIER,
    _ensure_unique,
    _parse_tsv_rows,
    _require_non_empty,
    list_catalog_property,
    parse_keywords,
    swift_escape,
    write_generated_file,
)
from internal.content.content_codegen_modifiers import VALID_KEYWORDS
from internal.content.content_codegen_modifiers import modifiers_swift
from internal.content.content_codegen_triggers import triggers_swift
from internal.content.affix_rolling import validate_affix_rolling


VALID_SLOTS = frozenset({"weapon", "armor", "accessory", "trinket"})


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
class ItemBaseRow:
    id: str
    name: str
    slot: str
    weapon_kind: str
    keywords: str


@functools.cache
def parse_affix_rows() -> list[AffixRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'affixes.tsv',
        ['id', 'title', 'slot', 'keywords', 'weight', 'basic_description', 'astral_description', 'basic_modifiers', 'astral_modifiers', 'basic_triggers', 'astral_triggers'], AffixRow, min_columns=AFFIX_REQUIRED_COLUMNS)


@functools.cache
def parse_item_base_rows() -> list[ItemBaseRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'item_bases.tsv',
        ['id', 'name', 'slot', 'weapon_kind', 'keywords'], ItemBaseRow, min_columns=None)


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
        _ensure_unique(seen, row.id, "affix id")

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
        validate_affix_rolling(row.basic_triggers, row.id)
        validate_affix_rolling(row.astral_triggers, row.id)


def validate_item_base_rows(rows: list[ItemBaseRow]) -> None:
    seen_ids: set[str] = set()
    for row in rows:
        _ensure_unique(seen_ids, row.id, "item base id")
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
