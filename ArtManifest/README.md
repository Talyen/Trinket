# Art Pipeline

Trinket keeps raw art and app-ready art separate.

## Folders

- `Raw Assets/`: unoptimized source library copied from Alchemy. Do not add this folder to Xcode target membership on purpose.
- `ArtManifest/curated-assets.tsv`: source-of-truth manifest for selected art.
- Art direction: [Docs/Product/ArtworkStyleGuide.md](../Docs/Product/ArtworkStyleGuide.md).
- `Trinket/Assets.xcassets`: generated app-ready image assets.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift`: generated Swift lookup table for curated assets.

## Manifest Format

`ArtManifest/curated-assets.tsv` is tab-separated:

```text
kind	id	asset_name	source_path	focal_x	focal_y
```

- `kind`: `combatant`, `ability`, `item`, `slot_background`, `background`, `encounter`, or `resource`.
- `id`: game model ID, such as `knight` or `fire_elemental`.
- `asset_name`: stable asset catalog name used by SwiftUI `Image`.
- `source_path`: path to the raw source file from the repo root.
- `focal_x` and `focal_y`: normalized focal point from `0.0` to `1.0`.

For combatants, the raw art filename should match the game entity name exactly,
ignoring the file extension. Do not map near-synonyms or temporary stand-ins; leave
the entity unmapped until matching art exists or the game entity is renamed.

Focal points are intentionally lightweight. They let hero headers bias a 3:4 portrait image toward the face or upper body when the layout crops the image with `scaledToFill`.
Background focal points are also emitted into `BackgroundArtReference` so cinematic landscape headers and thumbnails can share a curated crop anchor. Resource entries use the same six-column row shape for pipeline consistency; their focal point should normally be `0.50, 0.50`.

## Output Format: HEIC + Kind-Aware Variants

The pipeline writes **HEIC** (HEVC-based) images per manifest row. Which variants ship depends on `kind`:

| Kind | Full (`<asset_name>`) | Thumb (`<asset_name>_thumb`) |
|------|-----------------------|------------------------------|
| `combatant` | yes (default `1320`) | yes (`thumb_dimension`, default `480`) |
| `ability`, `item` | yes (default `960`) | yes (`thumb_dimension`, default `480`) |
| `encounter` | yes (default `1320`) | yes (`thumb_dimension`, default `480`) |
| `background` | yes (default `1600`) | yes (`thumb_dimension`, default `480`) |
| `resource` | yes (default `256`) | no |
| `slot_background` | yes (default `720`) | no |

HEIC is Apple's native image format, ~30–50% smaller than JPEG at the same perceptual quality, with hardware-accelerated decode on iOS. Each output is stripped of EXIF/XMP/ICC metadata.

`CombatantArtReference`, `AbilityArtReference`, `ItemArtReference`, `EncounterArtReference`, and `BackgroundArtReference` expose both `imageName` (full) and `thumbnailImageName`. Callers select the right variant at the call site (see `CombatantArtwork.Variant` in `Packages/TrinketFeatureSupport/.../Shared/Cards/CombatantArtwork.swift`): large surfaces (battle hand, detail heroes, stage/spire encounter art, cinematic backgrounds) use `imageName`; grid and mode cards use `thumbnailImageName`. Resource callers always use the full `imageName`.

## Generate Curated Assets

Normal authored workflow:

```sh
./Scripts/generate.sh --assets
```

The orchestrator validates all manifests and runs the art preparation script, which
verifies source files, converts selected images through macOS `sips` (HEIC with
quality 80), writes the kind-appropriate `.imageset` folders, strips unused variants,
and regenerates the Swift art catalog. Run `./Scripts/prepare-art-assets.sh` directly
only when debugging the art pipeline. Full-size defaults match their largest shipping
presentation: backgrounds retain the 1600-pixel cap, full-width combatant/encounter
heroes use 1320 pixels, card/detail art uses 960 pixels, and small resource/slot
chrome uses compact dedicated caps. Encoding settings participate in the generated
digest, so dimension or quality changes automatically regenerate affected assets
without `FORCE_ASSET_REENCODE`.

Reconvert is **content-and-output-settings-hash based** (not mtime). Digests live in `Packages/TrinketContent/Sources/TrinketContent/Generated/ArtSourceHashes.generated.tsv`. Exporters that preserve stale timestamps (for example Darkroom) still invalidate when pixel bytes change. Set `FORCE_ASSET_REENCODE=1` to rebuild every curated asset regardless of hash.

### Environment Overrides

| Variable | Default | Description |
|----------|---------|-------------|
| `ART_HEIC_QUALITY` | `80` | Lossy quality 0–100 |
| `ART_MAX_DIMENSION` | kind default | Override every full-image max dimension |
| `ART_<KIND>_DIMENSION` | table above | Override one full-image category, such as `ART_ABILITY_DIMENSION` |
| `ART_THUMB_DIMENSION` | `480` | Thumbnail max dimension |
| `FORCE_ASSET_REENCODE` | `0` | When `1`, re-encode all curated art even when source hashes match |

After changing `ArtManifest/curated-assets.tsv`, verify the generated result with:

```sh
./Scripts/handoff.sh --isolate --paths ArtManifest/curated-assets.tsv
```

## Decoded Memory Report

Compressed HEIC file size does not describe runtime bitmap residency. Report the
catalog's estimated RGBA footprint, grouped by art kind and variant, with:

```sh
./Scripts/report-art-memory.sh
```

The default full-catalog ceiling is 1024 MiB. Override it while investigating with
`ART_CATALOG_DECODED_MEMORY_BUDGET_MIB=<MiB>`. Pass `--enforce` to return a failure
when the generated catalog exceeds the configured ceiling. This bounds centralized
launch decode work; runtime diagnostics separately report against the 240 MiB
resident-artwork and 400 MiB process-memory targets. Threshold rationale and device
verification: `Docs/Platform/MemoryAndEnergyInvestigation.md`.

## Agent Workflow

1. Choose a raw asset.
2. Add one manifest row with a stable `asset_name`.
3. Pick a starting focal point. For portrait combatant art, `0.50	0.34` is a good first pass.
4. Run `./Scripts/generate.sh --assets`.
5. Build and visually inspect the detail page.
6. Adjust `focal_x`/`focal_y` and regenerate if the crop misses the important subject.

Generated files are committed so the app can build without rerunning the pipeline, but the manifest remains the editable source of truth.
