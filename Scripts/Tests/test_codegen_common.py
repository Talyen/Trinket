from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/content_codegen.py',
    'Scripts/internal/content/affix_rolling.py',
    'Scripts/internal/content/common.py',
    'Scripts/internal/content/content_codegen_modifiers.py',
    'Scripts/internal/content/content_codegen_triggers.py',
    'Scripts/internal/content/modifier_schema.py',
    'Scripts/internal/content/modifiers.json',
    'Scripts/internal/content/trigger_families/*.json',
)


from pathlib import Path
from unittest.mock import patch
import tempfile

from script_test_support import ScriptRegressionTestCase
from internal.content import common


class CodegenCommonTests(ScriptRegressionTestCase):
    def test_manifest_table_rejects_truncated_rows_and_quotes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "media.tsv"
            for row in ('only_one_column\n', 'image\t"unfinished\n', 'image\t"asset"junk\n'):
                path.write_text('# id\tasset_name\n' + row)
                with self.subTest(row=row), self.assertRaisesRegex(ValueError, r'media.tsv:2\b'):
                    common.read_manifest_table(path)

    def test_parse_tsv_rows_pads_optional_columns_and_enforces_min_columns(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tsv_path = Path(directory) / "test.tsv"
            tsv_path.write_text("id\tname\topt1\topt2\nitem1\tItem One\n", encoding="utf-8")
            from dataclasses import dataclass

            @dataclass
            class DummyRow:
                id: str
                name: str
                opt1: str
                opt2: str

            rows = common._parse_tsv_rows(tsv_path, DummyRow, min_columns=2)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0].id, "item1")
            self.assertEqual(rows[0].opt1, "")
            self.assertEqual(rows[0].opt2, "")

            with self.assertRaises(ValueError):
                common._parse_tsv_rows(tsv_path, DummyRow, min_columns=3)

    def test_swift_escape_handles_quotes_backslashes_and_newlines(self) -> None:
        self.assertEqual(common.swift_escape('say "hi"\r\n\t\0a\\b'), 'say \\"hi\\"\\r\\n\\t\\0a\\\\b')
        self.assertEqual(
            common.swift_escape("Increase X by 1\\nProduces 1 Hide per day"),
            "Increase X by 1\\nProduces 1 Hide per day",
        )

    def test_write_if_changed_skips_rewrite_when_identical(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Sample.generated.swift"
            common.write_if_changed(path, "content\n")
            self.assertEqual(path.read_text(encoding="utf-8"), "content\n")
            with patch.object(Path, "write_text") as writer:
                common.write_if_changed(path, "content\n")
        writer.assert_not_called()
