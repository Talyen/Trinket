from __future__ import annotations

from script_test_support import ScriptRegressionTestCase
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
        good = [self._stage_row()]
        stages.validate_stage_rows(
            good,
            enemy_ids={"goblin"},
            mystery_event_ids={"mana-berries"},
            recruit_event_ids={"recruit-knight"},
            art_ids={"destination-merchant-shop"},
        )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [self._stage_row(), self._stage_row()],
                enemy_ids={"goblin"},
            )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [self._stage_row(encounter="battle", enemy_id="")],
                enemy_ids={"goblin"},
            )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [
                    self._stage_row(stage_number="1"),
                    self._stage_row(stage_number="3"),
                ],
                enemy_ids={"goblin"},
            )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [self._stage_row(encounter="mystery", enemy_id="bogus-event")],
                enemy_ids={"goblin"},
                mystery_event_ids={"mana-berries"},
            )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [self._stage_row(encounter="recruit", enemy_id="bogus-event")],
                enemy_ids={"goblin"},
                recruit_event_ids={"recruit-knight"},
            )
        stages.validate_stage_rows(
            [self._stage_row(encounter="recruit", enemy_id="random-companion")],
            enemy_ids={"goblin"},
            recruit_event_ids={"recruit-knight"},
        )
        with self.assertRaises(ValueError):
            stages.validate_stage_rows(
                [
                    self._stage_row(
                        encounter="shop",
                        enemy_id="",
                        encounter_art_id="bogus-art",
                        encounter_art_title="Bogus",
                    )
                ],
                enemy_ids={"goblin"},
                art_ids={"destination-merchant-shop"},
            )

    def test_live_manifest_event_and_art_ids_resolve(self) -> None:
        self.assertIn("mana-berries", stages.collect_mystery_event_ids())
        self.assertIn("recruit-knight", stages.collect_recruit_event_ids())
        self.assertIn("destination-merchant-shop", stages.collect_art_ids())
