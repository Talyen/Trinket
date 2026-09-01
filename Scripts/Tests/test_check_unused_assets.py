#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_checker():
    spec = importlib.util.spec_from_file_location(
        "check_unused_assets", ROOT / "Scripts" / "check-unused-assets.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load check-unused-assets.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_unused_assets"] = module
    spec.loader.exec_module(module)
    return module


class CheckUnusedAssetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.checker = load_checker()

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


if __name__ == "__main__":
    unittest.main()
