"""Items content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass

from internal.content.common import (
    AFFIX_REQUIRED_COLUMNS,
    GENERATED_DIR,
    KEBAB_IDENTIFIER,
    MANIFEST_DIR,
    SNAKE_IDENTIFIER,
    _ensure_unique,
    _parse_tsv_rows,
    _require_non_empty,
    _validate_positive_int,
    _validate_snake_id,
    list_catalog_property,
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


def parse_affix_rows() -> list[AffixRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'affixes.tsv', AffixRow, min_columns=AFFIX_REQUIRED_COLUMNS)


def parse_item_base_rows() -> list[ItemBaseRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'item_bases.tsv', ItemBaseRow)


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
    if KEBAB_IDENTIFIER.fullmatch(value) or SNAKE_IDENTIFIER.fullmatch(value):
        return
    raise ValueError(
        f"affix id '{value}' for {row_id} must use lowercase letters, numbers, hyphens, or underscores"
    )


def keyword_tokens(raw: str, row_id: str = "item keywords") -> list[str]:
    keywords = [part.strip() for part in raw.split(",")] if raw.strip() else []
    seen: set[str] = set()
    for keyword in keywords:
        if keyword not in VALID_KEYWORDS:
            raise ValueError(f"Unknown keyword '{keyword}' for {row_id}")
        _ensure_unique(seen, keyword, f"keyword for {row_id}")
    return keywords


def parse_keywords(raw: str) -> str:
    return "[" + ", ".join(f".{keyword}" for keyword in keyword_tokens(raw)) + "]"


def validate_affix_rows(rows: list[AffixRow]) -> None:
    seen: set[str] = set()
    for row in rows:
        _ensure_unique(seen, row.id, "affix id")

        _validate_affix_id(row.id, row.id)
        _require_non_empty("affix title", row.title, row.id)
        if row.slot not in VALID_SLOTS:
            raise ValueError(f"Invalid affix slot '{row.slot}' for {row.id}")
        keyword_tokens(row.keywords, row.id)
        _validate_positive_int("Affix weight", row.weight, row.id, minimum=1)
        for tier, description, modifiers, triggers in (
            ("basic", row.basic_description, row.basic_modifiers, row.basic_triggers),
            ("astral", row.astral_description, row.astral_modifiers, row.astral_triggers),
        ):
            _require_non_empty(f"{tier}_description", description, row.id)
            modifiers_swift(modifiers, row.id)
            # Rolling validation also parses and type-checks every trigger.
            validate_affix_rolling(triggers, row.id)


def validate_item_base_rows(rows: list[ItemBaseRow]) -> None:
    seen_ids: set[str] = set()
    for row in rows:
        _ensure_unique(seen_ids, row.id, "item base id")
        _validate_snake_id("item base id", row.id, row.id)
        _require_non_empty("item base name", row.name, row.id)
        if row.slot not in VALID_SLOTS:
            raise ValueError(f"Unknown item slot '{row.slot}' for {row.id}")
        valid_weapon_kinds = {"one_handed", "two_handed", "off_hand"}
        if row.slot == "weapon" and row.weapon_kind not in valid_weapon_kinds:
            raise ValueError(f"Unknown weapon kind '{row.weapon_kind}' for {row.id}")
        if row.slot != "weapon" and row.weapon_kind:
            raise ValueError(f"Non-weapon item base {row.id} cannot declare a weapon kind")
        keyword_tokens(row.keywords, f"item base {row.id}")


def validate_affix_reachability(affix_rows: list[AffixRow], item_base_rows: list[ItemBaseRow]) -> None:
    """Every affix must be rollable on at least one base of its slot.

    Eligibility is a slot match plus a shared keyword (`ItemAffixDefinition.
    isEligible`), so an affix no base can host never enters a roll pool and
    silently skews the weights of the affixes that remain.
    """
    affinities: dict[str, set[str]] = {}
    for row in item_base_rows:
        affinities.setdefault(row.slot, set()).update(keyword_tokens(row.keywords, row.id))
    for row in affix_rows:
        if set(keyword_tokens(row.keywords, row.id)) & affinities.get(row.slot, set()):
            continue
        raise ValueError(
            f"affix '{row.id}' ({row.slot}) shares no keyword with any {row.slot} item base"
        )


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
