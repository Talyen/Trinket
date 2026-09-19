"""Stages content parsing, validation, and generation."""

from __future__ import annotations

from dataclasses import dataclass
import functools
import re

from internal.cli import ROOT
from internal.content.common import (
    GENERATED_DIR,
    MANIFEST_DIR,
    _parse_tsv_rows,
    _validate_positive_int,
    list_catalog_property,
    read_manifest_table,
    swift_escape,
    write_generated_file,
)


ENCOUNTER_DIR = ROOT / "Packages" / "TrinketContent" / "Sources" / "TrinketContent" / "Encounters"


VALID_ENCOUNTERS = frozenset(
    {"battle", "shop", "mystery", "recruit", "random_battle"}
)


VALID_CHAPTER_THEMES = frozenset({"forest", "dungeon", "desert", "tundra"})


# Recruit sentinel: empty id = any eligible unlock; this id = companion-only pool.
RANDOM_COMPANION_RECRUIT_ID = "random-companion"


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


ART_MANIFEST = ROOT / "ArtManifest" / "curated-assets.tsv"


@functools.cache
def collect_art_ids() -> set[str]:
    header, rows = read_manifest_table(ART_MANIFEST)
    if "id" not in header:
        raise ValueError(f"{ART_MANIFEST} header must declare an id column")
    id_index = header.index("id")
    return {row[id_index] for row in rows}


@functools.cache
def _read_encounter_source(name: str) -> str:
    return (ENCOUNTER_DIR / name).read_text(encoding="utf-8")


@functools.cache
def collect_mystery_event_ids() -> set[str]:
    ids: set[str] = set()
    for name in ("MysteryEventPool+Events.swift",):
        ids.update(re.findall(r'makeEvent\(\s*id:\s*"([^"]+)"', _read_encounter_source(name)))
    if not ids:
        raise ValueError("mystery event id scrape found no ids; update collect_mystery_event_ids")
    return ids


@functools.cache
def collect_recruit_event_ids() -> set[str]:
    ids = set(re.findall(r'recruit\(\s*id:\s*"([^"]+)"', _read_encounter_source("RecruitEventPool.swift")))
    if not ids:
        raise ValueError("recruit event id scrape found no ids; update collect_recruit_event_ids")
    return ids


@functools.cache
def parse_stage_rows() -> list[StageRow]:
    return _parse_tsv_rows(MANIFEST_DIR / 'stages.tsv',
        ['chapter_id', 'chapter_number', 'chapter_title', 'theme', 'stage_number', 'encounter', 'enemy_id', 'encounter_art_id', 'encounter_art_title'], StageRow, min_columns=None)


def parse_item_templates(raw: str) -> str:
    if not raw.strip():
        return "[]"
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "[" + ", ".join(f'"{swift_escape(part)}"' for part in parts) + "]"


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
