#!/usr/bin/env python3
from __future__ import annotations

SCRIPT_INPUTS = (
    'Scripts/check-unused-assets.py',
    'Scripts/config/full-only-art-kinds.txt',
    'Scripts/internal/content/common.py',
)


import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from script_test_support import load_script


class CheckUnusedAssetsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.checker = load_script("check_unused_assets", "check-unused-assets.py")

    def test_live_repository_assets_have_no_missing_or_orphans(self) -> None:
        missing, orphans = self.checker.check_assets()
        self.assertEqual(missing, [])
        self.assertEqual(orphans, [])

    def test_missing_thumbnails_and_media_and_orphans_are_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            assets = root / "Assets.xcassets"
            assets.mkdir()
            manifest = root / "art.tsv"
            manifest.write_text("# id\tasset_name\tkind\nhero\thero\tcombatant\nresource\twood\tresource\n")
            for name in ("hero", "wood", "orphan"):
                folder = assets / f"{name}.imageset"
                folder.mkdir()
                (folder / f"{name}.heic").write_bytes(b"image")
            media = root / "media"
            media.mkdir()
            music = root / "music.tsv"
            music.write_text("# asset_name\nmissing-track\n")
            (media / "orphan.m4a").write_bytes(b"audio")
            with patch.multiple(self.checker, ROOT=root, ASSETS_XCASSETS=assets, ART_MANIFEST=manifest,
                                MUSIC_MANIFEST=music, MUSIC_DIR=media, SFX_MANIFEST=root / "absent-sfx.tsv",
                                CINEMATICS_MANIFEST=root / "absent-video.tsv", SFX_DIR=root / "sfx",
                                CINEMATICS_DIR=root / "video"):
                missing, orphans = self.checker.check_assets()
            self.assertEqual(len(missing), 2, missing)
            self.assertTrue(any("hero_thumb.heic" in item for item in missing))
            self.assertTrue(any("missing-track.m4a" in item for item in missing))
            self.assertEqual(len(orphans), 2, orphans)
            self.assertTrue(any("orphan.imageset" in item for item in orphans))
            self.assertTrue(any("orphan.m4a" in item for item in orphans))


if __name__ == "__main__":
    unittest.main()
