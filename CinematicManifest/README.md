# Cinematic Pipeline

Trinket keeps source Ultimate cinematic videos separate from app-ready bundle copies.

## Folders

- `Raw Assets/Animations/`: source MP4 files. Do not add this folder to the Xcode target.
- `CinematicManifest/cinematics.tsv`: editable source of truth for Hero/Companion Ultimate cinematics.
- `Trinket/Media/Cinematics/`: generated app-ready `.mp4` copies.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/UltimateCinematicCatalog.generated.swift`: generated Swift lookup keyed by Hero/Companion + ability ID.

## Manifest Format

`CinematicManifest/cinematics.tsv` is tab-separated:

```text
actor_id	ability_id	asset_name	source_path	has_audio
```

- `actor_id`: Hero or Companion combatant id (e.g. `knight`, `rogue`) whose Ultimate plays this cinematic.
- `ability_id`: Ultimate catalog ability ID (e.g. `avatar-of-justice`). Must be one of that actor's authored Ultimates.
- `asset_name`: bundle-safe resource name without extension.
- `source_path`: path to the raw source file from the repo root.
- `has_audio`: `true` or `false` — when true, playback respects Options effects volume.

Cinematics are deliberately scoped to a specific Hero/Companion. A shared Ultimate
(e.g. `shadowstep`) only plays a video when the owning `actor_id` casts it; other
casters fall back to ability art.

## Generate Cinematic Assets

Run:

```sh
./Scripts/prepare-cinematic-assets.sh
```

Or via the full asset pipeline:

```sh
./Scripts/generate.sh --assets
```

The script validates manifest rows, copies source MP4s into `Trinket/Media/Cinematics/`, and regenerates the Swift catalog. Battle presentation fills the screen with aspect-fill (crop, no stretch); missing rows fall back to ability art.
