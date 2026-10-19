"""Prevent unrecoverable release/profile evidence and missing upload symbols."""

from __future__ import annotations

import json
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest import mock
import zipfile

from script_test_support import ROOT
from internal import build_symbols as symbols

UUID = "95584951-8E3B-3108-AF34-7D2DC5417DFB"
OTHER = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"


class BuildSymbolTests(unittest.TestCase):
    def fixture(self, root):
        archive = root / "Trinket.xcarchive"
        app = archive / "Products/Applications/Trinket.app"
        app.mkdir(parents=True)
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "com.example.Trinket",
            "CFBundleShortVersionString": "1.0", "CFBundleVersion": "7", "CFBundleExecutable": "Trinket"}))
        (app / "Trinket").write_text(UUID)
        dwarf = archive / "dSYMs/Trinket.app.dSYM/Contents/Resources/DWARF/Trinket"
        dwarf.parent.mkdir(parents=True)
        dwarf.write_text(UUID)
        ipa = root / "Trinket.ipa"
        with zipfile.ZipFile(ipa, "w") as zipped:
            zipped.write(app / "Info.plist", "Payload/Trinket.app/Info.plist")
            zipped.write(app / "Trinket", "Payload/Trinket.app/Trinket")
            zipped.writestr(f"Symbols/{UUID}.symbols", "symbol payload")
        return archive, app, dwarf, ipa

    def identities(self, path):
        return {(Path(path).read_text(), "arm64")}

    def test_mismatch_and_missing_nested_framework_symbols_block_release(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(symbols, "uuids", self.identities):
            archive, app, dwarf, _ = self.fixture(Path(directory))
            dwarf.write_text(OTHER)
            with self.assertRaisesRegex(ValueError, "Missing matching dSYM"):
                symbols.app_manifest(app, archive / "dSYMs")
            dwarf.write_text(UUID)
            framework = app / "Frameworks/Engine.framework"
            framework.mkdir(parents=True)
            (framework / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "Engine"}))
            (framework / "Engine").write_text(OTHER)
            with self.assertRaisesRegex(ValueError, "Missing matching dSYM"):
                symbols.app_manifest(app, archive / "dSYMs")

    def test_missing_upload_payload_cannot_be_mistaken_for_archive_symbols(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(symbols, "uuids", self.identities):
            archive, app, _, ipa = self.fixture(Path(directory))
            manifest = symbols.app_manifest(app, archive / "dSYMs")
            symbols.validate_ipa(ipa, manifest)
            with zipfile.ZipFile(ipa, "w") as zipped:
                zipped.write(app / "Info.plist", "Payload/Trinket.app/Info.plist")
                zipped.write(app / "Trinket", "Payload/Trinket.app/Trinket")
                zipped.writestr(f"Symbols/{OTHER}.symbols", "different build")
            with self.assertRaisesRegex(ValueError, "lacks Apple's symbol payload"):
                symbols.validate_ipa(ipa, manifest)
            with zipfile.ZipFile(ipa, "w") as zipped:
                zipped.write(app / "Info.plist", "Payload/Trinket.app/Info.plist")
                zipped.writestr("Payload/Trinket.app/Trinket", OTHER)
                zipped.writestr(f"Symbols/{UUID}.symbols", "symbol payload")
            with self.assertRaisesRegex(ValueError, "executable UUIDs differ"):
                symbols.validate_ipa(ipa, manifest)

    def test_verified_backup_survives_source_removal_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(symbols, "uuids", self.identities):
            root = Path(directory)
            archive, _, _, ipa = self.fixture(root)
            receipt = {"bundle_id": "com.example.Trinket", "version": "1.0", "build": 7, "commit": "commit"}
            saved = symbols.backup_archive(archive, ipa, receipt, root / "durable")
            destination = Path(saved["path"])
            self.assertEqual(symbols.backup_archive(archive, ipa, receipt, root / "durable"), saved)
            bad = destination / "Trinket.xcarchive/Products/Applications/Trinket.app/Trinket"
            bad.write_text("damaged")
            with self.assertRaisesRegex(ValueError, "damaged"):
                symbols.backup_archive(archive, ipa, receipt, root / "durable")
            self.assertEqual(bad.read_text(), "damaged", "existing evidence must never be overwritten")
            bad.write_text(UUID)
            shutil.rmtree(archive)
            ipa.unlink()
            restored = destination / "Trinket.xcarchive"
            self.assertEqual(symbols.app_manifest(restored / "Products/Applications/Trinket.app", restored / "dSYMs")["build"], "7")
            self.assertEqual(json.loads((destination / "receipt.json").read_text())["commit"], "commit")

    def test_profile_matches_recorded_uuid_and_preserves_original_dsym(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(symbols, "uuids", self.identities):
            root = Path(directory)
            archive, _, dwarf, _ = self.fixture(root)
            samples = root / "samples.xml"
            samples.write_text(f'<root><binary name="Trinket" UUID="{OTHER}" arch="arm64"/></root>')
            with self.assertRaisesRegex(ValueError, "No dSYM matches"):
                symbols.preserve_profile_symbols(samples, [archive / "dSYMs"], root / "wrong", {})
            samples.write_text(f'<root><binary name="Trinket" UUID="{UUID}" arch="arm64"/></root>')
            preserved = symbols.preserve_profile_symbols(samples, [archive / "dSYMs"], root / "capture/symbols", {})
            dwarf.unlink()
            self.assertEqual(preserved["binaryUUIDs"], [[UUID, "arm64"]])
            self.assertIn((UUID, "arm64"), symbols.symbol_index([root / "capture/symbols"]))

    def test_exit_zero_symbolicator_with_only_addresses_is_not_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "samples.xml"
            path.write_text('<root><frame name="0x123"><binary id="4" name="Trinket"/></frame>'
                            '<frame name="system_function"><binary id="5" name="UIKit"/></frame></root>')
            with self.assertRaisesRegex(ValueError, "no named Trinket frames"):
                symbols.symbolicated_app_frames(path)
            path.write_text('<root><frame name="0x123"><binary id="4" name="Trinket"/></frame>'
                            '<frame name="app_function"><binary ref="4"/></frame></root>')
            self.assertEqual(symbols.symbolicated_app_frames(path), 1)


if __name__ == "__main__":
    unittest.main()
