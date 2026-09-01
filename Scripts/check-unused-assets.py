#!/usr/bin/env python3
"""Bi-directional integrity check for Trinket game assets and manifests.

Validates that:
1. Every asset declared in ArtManifest, MusicManifest, SoundManifest, and CinematicManifest
   exists on disk in Trinket/Assets.xcassets or Trinket/Media.
2. Every asset file in Trinket/Assets.xcassets and Trinket/Media is registered in a manifest
   (detects orphaned / dead assets consuming bundle space).
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ART_MANIFEST = ROOT / "ArtManifest" / "curated-assets.tsv"
MUSIC_MANIFEST = ROOT / "MusicManifest" / "music.tsv"
SFX_MANIFEST = ROOT / "SoundManifest" / "sfx.tsv"
CINEMATICS_MANIFEST = ROOT / "CinematicManifest" / "cinematics.tsv"

ASSETS_XCASSETS = ROOT / "Trinket" / "Assets.xcassets"
MEDIA_DIR = ROOT / "Trinket" / "Media"
MUSIC_DIR = MEDIA_DIR / "Music"
SFX_DIR = MEDIA_DIR / "SFX"
CINEMATICS_DIR = MEDIA_DIR / "Cinematics"

KINDS_REQUIRING_THUMB = {
    "combatant",
    "ability",
    "item",
    "talent",
    "encounter",
    "background",
}


def read_tsv_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with open(path, "r", encoding="utf-8") as f:
        reader = csv.reader(f, delimiter="\t")
        rows = [r for r in reader if r and not r[0].startswith("#")]
    if not rows:
        return []

    # Read header from line 1
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("#"):
                header = [c.strip() for c in line.lstrip("#").strip().split("\t")]
                break
        else:
            return []

    result = []
    for r in rows:
        if len(r) >= len(header):
            result.append({k: v.strip() for k, v in zip(header, r)})
    return result


def check_assets(verbose: bool = False) -> tuple[list[str], list[str]]:
    missing: list[str] = []
    orphans: list[str] = []

    # 1. Art Manifest -> Assets.xcassets
    art_rows = read_tsv_rows(ART_MANIFEST)
    registered_imagesets: set[str] = set()

    for row in art_rows:
        asset_name = row.get("asset_name")
        kind = row.get("kind", "")
        if not asset_name:
            continue

        # Full variant
        full_set = f"{asset_name}.imageset"
        registered_imagesets.add(full_set)
        full_path = ASSETS_XCASSETS / full_set / f"{asset_name}.heic"
        if not full_path.is_file():
            missing.append(f"ArtManifest: missing full image file for '{asset_name}' ({full_path.relative_to(ROOT)})")

        # Thumb variant if applicable
        if kind in KINDS_REQUIRING_THUMB:
            thumb_set = f"{asset_name}_thumb.imageset"
            registered_imagesets.add(thumb_set)
            thumb_path = ASSETS_XCASSETS / thumb_set / f"{asset_name}_thumb.heic"
            if not thumb_path.is_file():
                missing.append(f"ArtManifest: missing thumbnail image file for '{asset_name}' ({thumb_path.relative_to(ROOT)})")

    # Reverse Art Check: Check for orphaned .imageset directories in Assets.xcassets
    if ASSETS_XCASSETS.is_dir():
        for item in sorted(ASSETS_XCASSETS.iterdir()):
            if item.name.endswith(".imageset"):
                if item.name not in registered_imagesets:
                    orphans.append(f"Assets.xcassets: orphaned image set '{item.name}' not found in ArtManifest")
            elif item.name != "Contents.json" and not item.name.startswith("."):
                # Non-imageset unknown folder
                if item.is_dir() and item.name not in {"AccentColor.colorset", "AppIcon.appiconset"}:
                    orphans.append(f"Assets.xcassets: unmanaged asset folder '{item.name}'")

    # 2. Sound Manifest -> Media/SFX
    sfx_rows = read_tsv_rows(SFX_MANIFEST)
    registered_sfx: set[str] = set()

    for row in sfx_rows:
        asset_name = row.get("asset_name")
        if not asset_name:
            continue
        filename = f"{asset_name}.m4a"
        registered_sfx.add(filename)
        sfx_path = SFX_DIR / filename
        if not sfx_path.is_file():
            missing.append(f"SoundManifest: missing SFX audio file '{filename}' ({sfx_path.relative_to(ROOT)})")

    if SFX_DIR.is_dir():
        for item in sorted(SFX_DIR.iterdir()):
            if item.is_file() and not item.name.startswith(".") and item.name.endswith(".m4a"):
                if item.name not in registered_sfx:
                    orphans.append(f"Media/SFX: orphaned SFX file '{item.name}' not found in SoundManifest")

    # 3. Music Manifest -> Media/Music
    music_rows = read_tsv_rows(MUSIC_MANIFEST)
    registered_music: set[str] = set()

    for row in music_rows:
        asset_name = row.get("asset_name")
        if not asset_name:
            continue
        filename = f"{asset_name}.m4a"
        registered_music.add(filename)
        music_path = MUSIC_DIR / filename
        if not music_path.is_file():
            missing.append(f"MusicManifest: missing music audio file '{filename}' ({music_path.relative_to(ROOT)})")

    if MUSIC_DIR.is_dir():
        for item in sorted(MUSIC_DIR.iterdir()):
            if item.is_file() and not item.name.startswith(".") and item.name.endswith(".m4a"):
                if item.name not in registered_music:
                    orphans.append(f"Media/Music: orphaned music file '{item.name}' not found in MusicManifest")

    # 4. Cinematic Manifest -> Media/Cinematics
    cinematic_rows = read_tsv_rows(CINEMATICS_MANIFEST)
    registered_cinematics: set[str] = set()

    for row in cinematic_rows:
        asset_name = row.get("asset_name")
        if not asset_name:
            continue
        filename = f"{asset_name}.mp4"
        registered_cinematics.add(filename)
        cinematic_path = CINEMATICS_DIR / filename
        if not cinematic_path.is_file():
            missing.append(f"CinematicManifest: missing cinematic video file '{filename}' ({cinematic_path.relative_to(ROOT)})")

    if CINEMATICS_DIR.is_dir():
        for item in sorted(CINEMATICS_DIR.iterdir()):
            if item.is_file() and not item.name.startswith(".") and item.name.endswith(".mp4"):
                if item.name not in registered_cinematics:
                    orphans.append(f"Media/Cinematics: orphaned cinematic file '{item.name}' not found in CinematicManifest")

    return missing, orphans


def main() -> int:
    parser = argparse.ArgumentParser(description="Check bi-directional asset and manifest integrity.")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    missing, orphans = check_assets(verbose=args.verbose)

    if missing:
        print(f"Error: Found {len(missing)} missing required asset(s):", file=sys.stderr)
        for m in missing:
            print(f"  [MISSING] {m}", file=sys.stderr)

    if orphans:
        print(f"Error: Found {len(orphans)} orphaned asset(s) not declared in any manifest:", file=sys.stderr)
        for o in orphans:
            print(f"  [ORPHAN]  {o}", file=sys.stderr)

    if missing or orphans:
        return 1

    print("=== Asset and manifest integrity check passed: 0 missing, 0 orphans ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
