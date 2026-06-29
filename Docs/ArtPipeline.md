# Art Pipeline

Trinket keeps raw art and app-ready art separate.

## Folders

- `Raw Assets/`: unoptimized source library copied from Alchemy. Do not add this folder to Xcode target membership on purpose.
- `Art/curated-assets.tsv`: source-of-truth manifest for selected art.
- `Trinket/Assets.xcassets`: generated app-ready image assets.
- `Trinket/Generated/ArtCatalog.generated.swift`: generated Swift lookup table for curated assets.

## Manifest Format

`Art/curated-assets.tsv` is tab-separated:

```text
kind	id	asset_name	source_path	focal_x	focal_y	accessibility_label
```

- `kind`: currently `combatant`.
- `id`: game model ID, such as `mage` or `training-slime`.
- `asset_name`: stable asset catalog name used by SwiftUI `Image`.
- `source_path`: path to the raw source file from the repo root.
- `focal_x` and `focal_y`: normalized focal point from `0.0` to `1.0`.
- `accessibility_label`: human-readable description for VoiceOver.

For combatants, the raw art filename should match the game entity name exactly, ignoring the file extension. Do not map near-synonyms or temporary stand-ins such as `Knight` art to `Paladin`, `Wizard` art to `Mage`, or a different enemy to `Training Slime`; leave the entity unmapped until matching art exists or the game entity is renamed.

Focal points are intentionally lightweight. They let hero headers bias a 3:4 portrait image toward the face or upper body when the layout crops the image with `scaledToFill`.

## Generate Curated Assets

Run:

```sh
./Scripts/prepare-art-assets.sh
```

The script validates manifest rows, verifies source files, converts selected images through macOS `sips`, writes `.imageset` folders, and regenerates the Swift art catalog.

After changing `Art/curated-assets.tsv`, run the script, then run:

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
