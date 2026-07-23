#!/usr/bin/env python3
"""Focused regressions for script safety checks."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "Scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class ScriptRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.codegen = load_script("content_codegen", "content_codegen.py")
        cls.sync = load_script("sync_xcodeproj_sources", "sync-xcodeproj-sources.py")

    def test_publicize_ignores_braces_in_string_literals(self) -> None:
        source = 'struct Thing {\n    let brace = "}"\n    let value = 1\n}\n'
        output = self.codegen.publicize(source)
        self.assertIn("public let value = 1", output)

    def test_homestead_prerequisite_tier_must_exist(self) -> None:
        with self.assertRaises(ValueError):
            self.codegen.validate_homestead_prerequisites(
                "wheatField:9", "orchard-tier-1", {"wheatField": {1, 2}}
            )

    def test_content_codegen_rejects_unknown_command(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "Scripts" / "content_codegen.py"), "typo"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown command", result.stderr)

    def test_prepare_asset_scripts_use_c_locale_header_preserving_sort(self) -> None:
        scripts = (
            "prepare-app-icon.sh",
            "prepare-music-assets.sh",
            "prepare-sfx-assets.sh",
            "prepare-cinematic-assets.sh",
            "prepare-art-assets.sh",
        )
        for name in scripts:
            text = (ROOT / "Scripts" / name).read_text(encoding="utf-8")
            self.assertIn("LC_ALL=C sort", text, name)
            self.assertTrue(
                ("head -n 2" in text and "tail -n +3" in text) or ("tail -n +3" in text),
                f"{name} should preserve hash TSV headers before sorting",
            )

    def test_generate_pins_c_locale(self) -> None:
        text = (ROOT / "Scripts" / "generate.sh").read_text(encoding="utf-8")
        self.assertIn("export LC_ALL=C", text)
        self.assertIn("export LANG=C", text)

    def test_legacy_sync_fails_closed_on_duplicate_basenames(self) -> None:
        duplicate_paths = [
            ROOT / "TrinketTests" / "Shared.swift",
            ROOT / "TrinketTests" / "Nested" / "Shared.swift",
        ]
        with patch.object(self.sync, "discover_swift_files", return_value=duplicate_paths):
            with self.assertRaises(SystemExit):
                self.sync.sync_target("", "TrinketTests", "phase")


if __name__ == "__main__":
    unittest.main()
