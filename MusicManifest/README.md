# Music Pipeline

Trinket keeps source music separate from app-ready audio, matching the art pipeline.

## Folders

- External Asset Library, `Sounds/Game Sources/`: source MP3 files. This path is
  relative to the library root, not the checkout; [media assets](../Docs/AgentContext/content-and-manifests.md#media-assets)
  owns root selection and overrides.
- `MusicManifest/music.tsv`: editable source of truth for curated music.
- `Trinket/Media/Music/`: generated app-ready AAC `.m4a` files.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/MusicCatalog.generated.swift`: generated Swift lookup table for runtime routing.

## Manifest Format

`MusicManifest/music.tsv` is tab-separated:

```text
kind	id	asset_name	source_path	boss_enemy_id	looping	volume_gain
```

- `kind`: `menu`, `battle`, or `boss`.
- `id`: stable track ID used by Swift.
- `asset_name`: bundle-safe generated resource name.
- `source_path`: library-relative path to the raw source file.
- `boss_enemy_id`: matching boss enemy ID for boss tracks, or `none`.
- `looping`: `true` or `false`.
- `volume_gain`: per-track multiplier applied after the user music volume.

Boss rows are validated against `GameContent.enemies` and must point at an enemy marked `isBoss`.

## Generate Music Assets

Entry point and verification routing: [content-and-manifests.md](../Docs/AgentContext/content-and-manifests.md); `prepare-audio-assets.sh music` is the focused debugging entry point.

The script validates manifest rows, converts source files with macOS `afconvert`, writes AAC `.m4a` files, prunes orphans, and regenerates the Swift catalog. Source bytes and the complete encode profile both participate in cache invalidation. The default AAC bitrate is `96000`; override with:

```sh
MUSIC_AAC_BITRATE=128000 ./Scripts/prepare-audio-assets.sh music
```

Set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

## Runtime Routing

Playback, route selection, and pause/resume behavior belong to
[TrinketAppState](../Packages/TrinketAppState/README.md#music-routing).

## Boss lyrics

Authored `lyrics/<track_id>.json` snapshots contain original-language phrase text,
paired word start/end times in seconds, and the selected source recording's
`audioSha256`. The Blight Treant, Forge Golem, Frostwarden, Iron Bear, Seraph, and
Stone Titan snapshots are imported unchanged from Alchemy. Seraph uses “Be Not
Afraid”; Stone Titan uses “Stone Reclaims”. Their timing snapshots retain the
recordings' phrase order, repeated lines, and instrumental gaps. The Blood Countess snapshot aligns the supplied “One More
Heartbeat” lyrics to its selected recording using the same offline phrase-matching
and bounded word-alignment workflow. Section directions are excluded.
Add a snapshot for an existing boss track to enable another boss;
unsupported tracks have no lyric presentation.

Music preparation validates word counts, finite ordered positive intervals, boss
track identity and the recording hash before changing outputs. It generates
`MusicCatalog.lyrics(for:)`; timing inputs participate in freshness checks.
Source-free output checks validate the snapshot against the receipt's recording
hash. Lyrics remain verbatim words from the recording in every app language.
Nonverbal `[chants]`, `[growls]`, and `[vocalizing]` cues use localized captions.
