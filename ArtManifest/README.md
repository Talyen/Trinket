# Art Pipeline

Trinket keeps raw art and app-ready art separate.

## Folders

- `Raw Assets/`: unoptimized source library copied from Alchemy. Do not add this folder to Xcode target membership on purpose.
- `ArtManifest/curated-assets.tsv`: source-of-truth manifest for selected art.
- `Trinket/Assets.xcassets`: generated app-ready image assets.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/ArtCatalog.generated.swift`: generated Swift lookup table for curated assets.

## Manifest Format

`ArtManifest/curated-assets.tsv` is tab-separated:

```text
kind	id	asset_name	source_path	focal_x	focal_y	accessibility_label
```

- `kind`: `combatant`, `ability`, `item`, `slot_background`, `background`, `encounter`, or `resource`.
- `id`: game model ID, such as `mage` or `training-slime`.
- `asset_name`: stable asset catalog name used by SwiftUI `Image`.
- `source_path`: path to the raw source file from the repo root.
- `focal_x` and `focal_y`: normalized focal point from `0.0` to `1.0`.
- `accessibility_label`: human-readable description for VoiceOver.

For combatants, the raw art filename should match the game entity name exactly, ignoring the file extension. Do not map near-synonyms or temporary stand-ins such as `Knight` art to `Paladin`, `Wizard` art to `Mage`, or a different enemy to `Training Slime`; leave the entity unmapped until matching art exists or the game entity is renamed.

Focal points are intentionally lightweight. They let hero headers bias a 3:4 portrait image toward the face or upper body when the layout crops the image with `scaledToFill`.
Background focal points are also emitted into `BackgroundArtReference` so cinematic landscape headers and thumbnails can share a curated crop anchor. Resource entries use the same seven-column row shape for pipeline consistency; their focal point should normally be `0.50, 0.50`.

## Output Format: HEIC + Thumbnail Variants

The pipeline outputs two **HEIC** (HEVC-based) images per manifest row:

- **Full-size** — `max_dimension` px (default `1600`) for hero header / detail views. Named `<asset_name>.heic`.
- **Thumbnail** — `thumb_dimension` px (default `480`) for card grids, battle status cards, and any `CombatantArtwork` rendered with `variant: .card`. Named `<asset_name>_thumb.heic`.

HEIC is Apple's native image format, ~30–50% smaller than JPEG at the same perceptual quality, with hardware-accelerated decode on iOS. Each output is stripped of EXIF/XMP/ICC metadata.

The generated Swift struct `CombatantArtReference` includes both `imageName` (full) and `thumbnailImageName` (card-safe). Callers select the right variant at the call site (see `CombatantArtwork.Variant` in `Trinket/Shared/Cards/CombatantArtwork.swift`).

## Generate Curated Assets

Run:

```sh
./Scripts/prepare-art-assets.sh
```

The script validates manifest rows, verifies source files, converts selected images through macOS `sips` (HEIC with quality 80), writes two `.imageset` folders per asset, strips metadata, and regenerates the Swift art catalog.

### Environment Overrides

| Variable | Default | Description |
|----------|---------|-------------|
| `ART_HEIC_QUALITY` | `80` | Lossy quality 0–100 |
| `ART_MAX_DIMENSION` | `1600` | Full-image max dimension |
| `ART_THUMB_DIMENSION` | `480` | Thumbnail max dimension |

After changing `ArtManifest/curated-assets.tsv`, run the script, then run:

```sh
./Scripts/generate.sh
./Scripts/build.sh
```

## Agent Workflow

1. Choose a raw asset.
2. Add one manifest row with a stable `asset_name`.
3. Pick a starting focal point. For portrait combatant art, `0.50	0.34` is a good first pass.
4. Run `./Scripts/prepare-art-assets.sh`.
5. Build and visually inspect the detail page.
6. Adjust `focal_x`/`focal_y` and rerun the script if the hero header crop misses the important subject.

Generated files are committed so the app can build without rerunning the pipeline, but the manifest remains the editable source of truth.
