#!/usr/bin/env python3
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/check-unused-assets.py',
    'Scripts/config/full-only-art-kinds.txt',
    'Scripts/internal/content/common.py',
)


import tempfile
import unittest
from pathlib import Path

from script_test_support import ROOT, load_script


class CheckUnusedAssetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.checker = load_script("check_unused_assets", "check-unused-assets.py")

    def test_live_repository_assets_have_no_missing_or_orphans(self) -> None:
        missing, orphans = self.checker.check_assets()
        self.assertEqual(missing, [])
        self.assertEqual(orphans, [])

    def test_read_tsv_rows_parses_headers_and_skips_comments(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".tsv", delete=False) as f:
            f.write("# id\tasset_name\tkind\n")
            f.write("test_1\tsfx_test_1\tsfx\n")
            f.write("# commented line\n")
            f.write("test_2\tsfx_test_2\tsfx\n")
            temp_path = Path(f.name)
        try:
            rows = self.checker.read_tsv_rows(temp_path)
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[0]["id"], "test_1")
            self.assertEqual(rows[0]["asset_name"], "sfx_test_1")
            self.assertEqual(rows[1]["id"], "test_2")
        finally:
            temp_path.unlink(missing_ok=True)


    def test_asset_needs_thumb_and_full_only_kinds(self) -> None:
        full_only = self.checker.full_only_art_kinds()
        self.assertIn("resource", full_only)
        self.assertIn("slot_background", full_only)
        self.assertFalse(self.checker.asset_needs_thumb("resource"))
        self.assertFalse(self.checker.asset_needs_thumb("slot_background"))
        self.assertTrue(self.checker.asset_needs_thumb("combatant"))
        self.assertTrue(self.checker.asset_needs_thumb("ability"))
        self.assertTrue(self.checker.asset_needs_thumb("item"))


if __name__ == "__main__":
    unittest.main()
