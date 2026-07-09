# Cinematic Pipeline

Trinket keeps source Ultimate cinematic videos separate from app-ready bundle copies.

## Folders

- `Raw Assets/Animations/`: source MP4 files. Do not add this folder to the Xcode target.
- `CinematicManifest/cinematics.tsv`: editable source of truth for Ultimate cinematics.
- `Trinket/Resources/Cinematics/`: generated app-ready `.mp4` copies.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift`: generated Swift lookup keyed by ability ID.

## Manifest Format

`CinematicManifest/cinematics.tsv` is tab-separated:

```text
ability_id	asset_name	source_path	has_audio	display_aspect_w	display_aspect_h
```

- `ability_id`: ability catalog ID (e.g. `avatar-of-justice`).
- `asset_name`: bundle-safe resource name without extension.
- `source_path`: path to the raw source file from the repo root.
- `has_audio`: `true` or `false` — when true, playback respects Options effects volume.
- `display_aspect_w` / `display_aspect_h`: battle display crop hint (always `9` / `16` today).

## Generate Cinematic Assets

Run:

```sh
./Scripts/prepare-cinematic-assets.sh
```

Or via the full asset pipeline:

```sh
./Scripts/generate.sh --assets
```

The script validates manifest rows, copies source MP4s into `Trinket/Resources/Cinematics/`, and regenerates the Swift catalog. Battle presentation crops with aspect-fill; missing rows fall back to ability art.
