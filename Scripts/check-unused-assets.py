#!/usr/bin/env python3
"""Bi-directional integrity check for Trinket game assets and manifests.

Validates that:
1. Every asset declared in ArtManifest, MusicManifest, SoundManifest, and CinematicManifest
   exists on disk in Trinket/Assets.xcassets or Trinket/Media.
2. Every asset file in Trinket/Assets.xcassets and Trinket/Media is registered in a manifest
   (detects orphaned / dead assets consuming bundle space).

Carve-outs: AccentColor/AppIcon entries and dotfiles are ignored, as are files
with extensions outside each pipeline's output (`.heic`, `.m4a`, `.mp4`).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from content_codegen import read_manifest_table

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
    # Must match trinket_asset_needs_thumb in Scripts/lib/media-assets.sh:
    # resource / slot_background ship full-only, every other art kind ships
    # full + thumb. Edit both places together.
    "combatant",
    "ability",
    "item",
    "talent",
    "encounter",
    "background",
    "portrait_background",
}


def read_tsv_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    header, rows = read_manifest_table(path)
    return [dict(zip(header, row)) for row in rows]


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

    # 2-4. Manifest-driven media pipelines share one shape: manifest
    # asset_name -> Trinket/Media/<dir>/<asset>.<ext>. Orphan pruning in the
    # prepare-*-assets.sh scripts must agree with this table.
    media_pipelines = (
        (SFX_MANIFEST, SFX_DIR, "m4a", "SoundManifest", "Media/SFX", "SFX audio file", "SFX file"),
        (MUSIC_MANIFEST, MUSIC_DIR, "m4a", "MusicManifest", "Media/Music", "music audio file", "music file"),
        (
            CINEMATICS_MANIFEST,
            CINEMATICS_DIR,
            "mp4",
            "CinematicManifest",
            "Media/Cinematics",
            "cinematic video file",
            "cinematic file",
        ),
    )

    for manifest_path, media_dir, extension, manifest_label, media_label, missing_label, orphan_label in media_pipelines:
        registered_media: set[str] = set()

        for row in read_tsv_rows(manifest_path):
            asset_name = row.get("asset_name")
            if not asset_name:
                continue
            filename = f"{asset_name}.{extension}"
            registered_media.add(filename)
            asset_path = media_dir / filename
            if not asset_path.is_file():
                missing.append(f"{manifest_label}: missing {missing_label} '{filename}' ({asset_path.relative_to(ROOT)})")

        if media_dir.is_dir():
            for item in sorted(media_dir.iterdir()):
                if item.is_file() and not item.name.startswith(".") and item.name.endswith(f".{extension}"):
                    if item.name not in registered_media:
                        orphans.append(f"{media_label}: orphaned {orphan_label} '{item.name}' not found in {manifest_label}")

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
