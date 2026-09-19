"""Talents content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass
import functools

from internal.content.common import (
    GENERATED_DIR,
    MANIFEST_DIR,
    TALENT_REQUIRED_COLUMNS,
    _ensure_unique,
    _parse_tsv_rows,
    _require_non_empty,
    _validate_snake_id,
    _validate_game_icon,
    swift_escape,
    write_generated_file,
)
from internal.content.content_codegen_modifiers import modifiers_swift
from internal.content.content_codegen_triggers import triggers_swift


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
    return _parse_tsv_rows(MANIFEST_DIR / 'talents.tsv',
        ['id', 'name', 'icon_id', 'description', 'modifiers', 'triggers'], TalentRow, min_columns=TALENT_REQUIRED_COLUMNS)


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
        _ensure_unique(seen, row.id, "talent id")

        _validate_snake_id("talent id", row.id, row.id)
        if sorted_cids is not None:
            combatant_id_for_talent(row.id, sorted_cids)
        _require_non_empty("talent name", row.name, row.id)
        _validate_game_icon(row.icon_id, row.id)
        _require_non_empty("talent description", row.description, row.id)

        modifiers_swift(row.modifiers, row.id)
        triggers_swift(row.triggers, row.id)
