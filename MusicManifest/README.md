# Music Pipeline

Trinket keeps source music separate from app-ready audio, matching the art pipeline.

## Folders

- `Raw Assets/Music/`: source MP3 files. Do not add this folder to the Xcode target.
- `MusicManifest/music.tsv`: editable source of truth for curated music.
- `Trinket/Resources/Music/`: generated app-ready AAC `.m4a` files.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/MusicCatalog.generated.swift`: generated Swift lookup table for runtime routing.

## Manifest Format

`MusicManifest/music.tsv` is tab-separated:

```text
kind	id	asset_name	source_path	boss_enemy_id	looping	volume_gain
```

- `kind`: `menu`, `battle`, or `boss`.
- `id`: stable track ID used by Swift.
- `asset_name`: bundle-safe generated resource name.
- `source_path`: path to the raw source file from the repo root.
- `boss_enemy_id`: matching boss enemy ID for boss tracks, or `none`.
- `looping`: `true` or `false`.
- `volume_gain`: per-track multiplier applied after the user music volume.

Boss rows are validated against `GameContent.enemies` and must point at an enemy marked `isBoss`.

## Generate Music Assets

Run:

```sh
./Scripts/prepare-music-assets.sh
```

The script validates manifest rows, converts source files with macOS `afconvert`, writes AAC `.m4a` files, and regenerates the Swift catalog. The default AAC bitrate is `96000`; override with:

```sh
MUSIC_AAC_BITRATE=128000 ./Scripts/prepare-music-assets.sh
```

`./Scripts/generate.sh --assets` runs both the art and music pipelines so all app assets can be refreshed together.

## Runtime Routing

Music is state-driven:

- Menu music plays outside battle contexts.
- Opening a battle stage preview starts the battle or boss track.
- Starting battle from that preview keeps the same track.
- Leaving the Play tab while battle is active returns to menu music and stores the battle track position.
- Returning to the same battle resumes the saved position.
- Ending battle clears saved battle and boss positions.

The runtime uses `AVAudioSession.Category.ambient`, so game music respects the Ring/Silent switch and mixes politely with other audio.
