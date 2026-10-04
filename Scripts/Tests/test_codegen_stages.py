from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/stages.py',
    'Scripts/internal/content/trigger_families/*.json',
)


from script_test_support import ScriptRegressionTestCase
from pathlib import Path
import tempfile
from unittest.mock import patch
from internal.content import stages


class CodegenStagesTests(ScriptRegressionTestCase):
    def _stage_row(self, **overrides: str) -> object:
        fields = {
            "chapter_id": "chapter-1",
            "chapter_number": "1",
            "chapter_title": "First",
            "theme": "forest",
            "stage_number": "1",
            "encounter": "battle",
            "enemy_id": "goblin",
            "encounter_art_id": "",
            "encounter_art_title": "",
        }
        fields.update(overrides)
        return stages.StageRow(**fields)

    def test_stage_rows_validate_ids_numbering_and_art(self) -> None:
        catalog = dict(enemy_ids={"goblin"}, mystery_event_ids={"mana-berries"},
                       recruit_event_ids={"recruit-knight"}, art_ids={"destination-merchant-shop"})
        for row in (self._stage_row(), self._stage_row(encounter="recruit", enemy_id="random-companion")):
            stages.validate_stage_rows([row], **catalog)
        bad_rows = (
            ("Duplicate stage id", [self._stage_row(), self._stage_row()]),
            ("Duplicate chapter number", [self._stage_row(), self._stage_row(chapter_id="chapter-2")]),
            ("requires enemy_id", [self._stage_row(enemy_id="")]),
            ("numbered 1...N contiguously", [self._stage_row(), self._stage_row(stage_number="3")]),
            ("unknown mystery event", [self._stage_row(encounter="mystery", enemy_id="bogus-event")]),
            ("unknown recruit event", [self._stage_row(encounter="recruit", enemy_id="bogus-event")]),
            ("unknown encounter art", [self._stage_row(encounter="shop", enemy_id="",
                                                       encounter_art_id="bogus-art", encounter_art_title="Bogus")]),
        )
        for cause, rows in bad_rows:
            with self.subTest(cause=cause), self.assertRaisesRegex(ValueError, cause):
                stages.validate_stage_rows(rows, **catalog)

    def test_encounter_and_art_validation_observes_edits_without_cache_reset(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mystery = root / "Mystery"
            mystery.mkdir()
            art = root / "art.tsv"
            with patch.object(stages, "ART_MANIFEST", art), patch.object(stages, "ENCOUNTER_DIR", root):
                for identity in ("first", "edited"):
                    art.write_text(f"# id\tasset_name\n{identity}\timage\n")
                    (mystery / "MysteryEventPool+Events.swift").write_text(f'makeEvent(id: "{identity}")')
                    (mystery / "RecruitEventPool.swift").write_text(f'recruit(id: "{identity}")')
                    for collect in (stages.collect_art_ids, stages.collect_mystery_event_ids, stages.collect_recruit_event_ids):
                        self.assertEqual(collect(), {identity})
                        collect().clear()
                        self.assertEqual(collect(), {identity})
