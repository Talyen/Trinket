# Sound Effects Pipeline

Trinket keeps source sound effects separate from app-ready audio, matching the music pipeline.

## Folders

- `Sounds/Game Sources`: source `.wav` / `.ogg` files.
- `SoundManifest/sfx.tsv`: editable source of truth for curated SFX.
- `Trinket/Media/SFX/`: generated app-ready AAC `.m4a` files.
- `Packages/TrinketContent/Sources/TrinketContent/Generated/SFXCatalog.generated.swift`: generated Swift lookup table for runtime routing.

## Manifest Format

`SoundManifest/sfx.tsv` is tab-separated:

```text
id	swift_symbol	asset_name	source_path	volume_gain
```

- `id`: stable clip ID used by Swift (snake_case).
- `swift_symbol`: unique public `SFXID` constant generated for the clip.
- `asset_name`: bundle-safe generated resource name (`sfx_*` prefix).
- `source_path`: library-relative path to the raw source file.
- `volume_gain`: per-clip multiplier applied after the user sound-effects volume.

Comment lines start with `#`. Generated outputs are always AAC `.m4a`.

## Generate SFX Assets

Entry point and verification routing: [content-and-manifests.md](../Docs/AgentContext/content-and-manifests.md); `prepare-audio-assets.sh sfx` is the focused debugging entry point.

The script validates manifest rows, converts source files with macOS `afconvert`, writes AAC `.m4a` files, prunes orphans, and regenerates `SFXID` plus the Swift catalog. Source bytes and the complete encode profile both participate in cache invalidation. The default AAC bitrate is `64000`; override with:

```sh
SFX_AAC_BITRATE=96000 ./Scripts/prepare-audio-assets.sh sfx
```

Set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

## Runtime Routing

`SFXCatalog.clipsByID` looks up clips by stable `id`. Playback is owned by [SFXPlayer.swift](../Packages/TrinketAppState/Sources/TrinketAppState/Audio/SFXPlayer.swift), which applies `OptionsStore.effectsVolume` × `volumeGain`.

Stable IDs cover UI chrome, card draws, typed combat feedback, progression outcomes,
and outcome/Mystery stingers. Bleed and Poison share `hit_piercing`; Homestead,
battle, and Mystery collection share `loot_collect`. The single-cue selection and
outcome timing policy lives in [audio.md](../Docs/AgentContext/audio.md#action-sound-selection).

The selected feedback sources come from `Documents/Asset Library/Sounds`. Import
FLAC inputs as lossless PCM WAV; retain original WAV/OGG inputs. The Homestead
hammer source `hammer_multiple_exterior_fienup_013` uses 0.82–1.65 seconds with
10 ms entry and 60 ms exit fades. Selected source clips default to gain `1.0`; `block_absorb` uses `0.97` for
AAC decoding headroom. Attacks and ticks share their clip and gain.

## Game-feel variants

The six `hit_*critical` selections are separate lossless PCM WAV revisions derived
from their manifest-selected ordinary recordings. They preserve the original
attack timing and channels, apply a linearly declining transient emphasis of up
to 2 dB over the opening 60 ms, truncate duration to 85%, and fade the final 30 ms.
RMS over the retained source window is matched where peak headroom allows;
source peaks are capped at -2 dBFS before AAC preparation. The Physical and Stun
variants require approximately 0.42 and 0.19 dB lower RMS respectively to retain
that headroom. Perceptual balance still requires listening on hardware.

`loot_exceptional` uses the full 1.07-second harpsichord quick chime, preserving
its natural decay with only 5 ms of end smoothing. Its level matches the approved
harpsichord audition. The source revision is `loot_exceptional_harpsichord_01.wav`,
derived from `harpsichord_chime_quick__existing_library_unattributed__d4797e91fa2b61fd.flac`.
The original talent-unlock cue and earlier loot revision are preserved. All seven
selected sources live under the external library's
`Sounds/Game Sources/Projects/Trinket/Sound Effects/` folders; their paths are
recorded in the manifest.
