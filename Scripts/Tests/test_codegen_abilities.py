from __future__ import annotations

from pathlib import Path
from unittest.mock import patch
import os
import subprocess
import tempfile

from script_test_support import ScriptRegressionTestCase
from internal.content import abilities


class CodegenAbilitiesTests(ScriptRegressionTestCase):
    def test_inventory_digest_tracks_formatter_and_dependency_changes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = ["Scripts/content_codegen.py", "Scripts/tool-versions.env",
                     "Packages/TrinketContent/Package.swift", "Packages/TrinketCore/Package.swift",
                     "Packages/TrinketContent/Sources/TrinketContent/Abilities/AbilityDescriptionFormatter.swift",
                     "Packages/TrinketCore/Sources/TrinketCore/Keyword.swift",
                     "Scripts/internal/content/abilities.py"]
            for name in files:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("initial")
            with patch.object(abilities, "ROOT", root), patch.object(
                abilities, "TRINKET_CONTENT_PACKAGE", root / "Packages/TrinketContent"
            ):
                previous = abilities._ability_inventory_digest()
                self.assertEqual(previous, abilities._ability_inventory_digest())
                for name in files[-3:]:
                    path = root / name
                    path.write_text("changed")
                    current = abilities._ability_inventory_digest()
                    self.assertNotEqual(previous, current)
                    previous = current
                path.unlink()
                self.assertNotEqual(previous, abilities._ability_inventory_digest())

    def test_inventory_failures_retain_complete_logs_with_bounded_exceptions(self) -> None:
        for returncode in (65, 0):
            with self.subTest(returncode=returncode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                payload = b"error: Swift fixture failure " + b"x" * 1000 + b"\n"
                def run(command, **kwargs):
                    kwargs["stdout"].write(payload * 1000)
                    return subprocess.CompletedProcess(command, returncode)
                with patch.object(abilities, "GENERATED_DIR", root), \
                     patch.object(abilities, "ABILITY_INVENTORY_STAMP", root / "stamp"), \
                     patch.object(abilities, "parse_authored_ability_inventory_rows", return_value=[]), \
                     patch.object(abilities, "_ability_inventory_digest", return_value="digest"), \
                     patch.object(abilities.subprocess, "run", side_effect=run), \
                     patch.dict(os.environ, {"RESULTS_DIR": str(root / "logs")}):
                    with self.assertRaises(RuntimeError) as failure:
                        abilities.generate_ability_inventory()
                message = str(failure.exception)
                self.assertLess(len(message), 16000)
                self.assertIn("Full log:", message)
                self.assertIn("Swift fixture failure", message)
                self.assertIn("exit 65" if returncode else "did not write", message)
                logs = list((root / "logs").glob("*.log"))
                self.assertEqual(len(logs), 1)
                self.assertEqual(logs[0].read_bytes(), payload * 1000)
                self.assertFalse((root / "stamp").exists())

    def test_successful_inventory_keeps_bytes_and_cleans_subprocess_log(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = "id\tname\ttier\tsummary\nslash\tSlash\tbasic\tDeal damage\n"
            def run(command, **kwargs):
                Path(command[-1]).write_text(payload)
                return subprocess.CompletedProcess(command, 0)
            with patch.object(abilities, "GENERATED_DIR", root), \
                 patch.object(abilities, "ABILITY_INVENTORY_STAMP", root / "stamp"), \
                 patch.object(abilities, "parse_authored_ability_inventory_rows", return_value=[("slash", "Slash", "basic")]), \
                 patch.object(abilities, "_ability_inventory_digest", return_value="digest"), \
                 patch.object(abilities.subprocess, "run", side_effect=run), \
                 patch.dict(os.environ, {"RESULTS_DIR": str(root / "logs")}):
                abilities.generate_ability_inventory()
            self.assertEqual((root / "AbilityInventory.generated.tsv").read_text(), payload)
            self.assertEqual((root / "stamp").read_text(), "digest")
            self.assertEqual(list((root / "logs").iterdir()), [])
