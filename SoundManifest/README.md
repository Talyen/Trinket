# Sound Effects Pipeline

Trinket keeps source sound effects separate from app-ready audio, matching the music pipeline.

## Folders

- `Raw Assets/Sound Effects/`: source `.wav` / `.ogg` files. Do not add this folder to the Xcode target.
- `SoundManifest/sfx.tsv`: editable source of truth for curated SFX.
- `Trinket/Media/SFX/`: generated app-ready AAC `.m4a` files.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift`: generated Swift lookup table for runtime routing.

## Manifest Format

`SoundManifest/sfx.tsv` is tab-separated:

```text
id	asset_name	source_path	volume_gain
```

- `id`: stable clip ID used by Swift (snake_case).
- `asset_name`: bundle-safe generated resource name (`sfx_*` prefix).
- `source_path`: path to the raw source file from the repo root.
- `volume_gain`: per-clip multiplier applied after the user sound-effects volume.

Comment lines start with `#`. Generated outputs are always AAC `.m4a`.

## Generate SFX Assets

Entry point and verification routing: [content-and-manifests.md](../Docs/AgentContext/content-and-manifests.md); `prepare-sfx-assets.sh` is the focused debugging entry point.

The script validates manifest rows, converts source files with macOS `afconvert`, writes AAC `.m4a` files, prunes orphans, and regenerates the Swift catalog. The default AAC bitrate is `64000`; override with:

```sh
SFX_AAC_BITRATE=96000 ./Scripts/prepare-sfx-assets.sh
```

## Runtime Routing

`SFXCatalog.clipsByID` looks up clips by stable `id`. Playback is owned by `Packages/TrinketAppState/.../Audio/SFXPlayer.swift`, which applies `OptionsStore.effectsVolume` × `volumeGain`.

Stable IDs cover UI chrome, ability draw/play, keyword-typed combat feedback, and outcome / mystery stingers — not per-ability, enemy, hero, or companion content.
