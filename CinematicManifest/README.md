# Cinematic Pipeline

Trinket keeps source Ultimate cinematic videos separate from app-ready HEVC bundle encodes.

## Folders

- `Raw Assets/Animations/`: source MP4 files (SDR masters). Do not add this folder to the Xcode target.
- `CinematicManifest/cinematics.tsv`: editable source of truth for Hero/Companion Ultimate cinematics.
- `Trinket/Media/Cinematics/`: generated app-ready HEVC `.mp4` encodes.
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

## Encode

`./Scripts/prepare-cinematic-assets.sh` validates manifest rows, encodes each source to
SDR HEVC + AAC via system `avconvert`, writes `Trinket/Media/Cinematics/`, and
regenerates the Swift catalog.

Default preset: `PresetHEVCHighestQuality` (override with `CINEMATIC_HEVC_PRESET`).
`avconvert` never upscales; output resolution matches the source (or is smaller if a
dimension-capped preset is chosen). Changing the preset invalidates generated hashes
and re-encodes. Force a rebuild with `FORCE_ASSET_REENCODE=1`.

Delivery is **SDR only**. Battle overlays do not need HDR. If a master is HDR
(PQ / HLG / Dolby Vision, or Transfer Function tagged as such), export an SDR Rec.709
master into `Raw Assets/Animations/` before listing it in the manifest.

Quick check on a candidate source:

```sh
mdls -name kMDItemCodecs -name kMDItemProfileName "Raw Assets/Animations/YourFile.mp4"
```

Look for PQ, HLG, or HDR in the profile/codecs — those need an SDR re-export first.

## Generate Cinematic Assets

Run:

```sh
./Scripts/prepare-cinematic-assets.sh
```

Or via the full asset pipeline:

```sh
./Scripts/generate.sh --assets
```

After changing `CinematicManifest/cinematics.tsv`, verify with path-scoped handoff
(`./Scripts/handoff.sh --isolate --paths CinematicManifest/cinematics.tsv`). Agent workflow:
[content-and-manifests.md](../Docs/AgentContext/content-and-manifests.md).

Battle presentation fills the screen with aspect-fill (crop, no stretch); missing rows fall back to ability art.
