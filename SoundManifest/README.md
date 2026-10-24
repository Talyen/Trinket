# Sound Effects Pipeline

Trinket keeps source sound effects separate from app-ready audio, matching the music pipeline.

## Folders

- `AssetSources/Sounds/Game Sources/`: tracked source `.wav` / `.ogg` files;
  [media assets](../Docs/AgentContext/content-and-manifests.md#media-assets) owns preparation.
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
- `source_path`: path to the raw source file relative to repository `AssetSources/`.
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
and outcome/Mystery stingers. Direct Bleed and Poison hits share `hit_piercing`; periodic ticks have distinct cues. Homestead,
battle, and Mystery collection share `loot_collect`. The single-cue selection and
outcome timing policy lives in [audio.md](../Docs/AgentContext/audio.md#action-sound-selection).

The selected feedback sources come from the library's `Sounds/` tree. Import
FLAC inputs as lossless PCM WAV; retain original WAV/OGG inputs. The Homestead
hammer source `hammer_multiple_exterior_fienup_013` uses 0.82–1.65 seconds with
10 ms entry and 60 ms exit fades. Selected source clips default to gain `1.0`; `block_absorb` uses `0.97` for
AAC decoding headroom. Direct-hit and periodic mappings follow the
[action sound selection contract](../Docs/AgentContext/audio.md#action-sound-selection).

## Game-feel variants

The six `hit_*critical` selections are separate lossless PCM WAV revisions derived
from their manifest-selected ordinary recordings. They preserve the original
attack timing and channels, apply a linearly declining transient emphasis of up
to 2 dB over the opening 60 ms, truncate duration to 85%, and fade the final 30 ms.
RMS over the retained source window is matched where peak headroom allows;
source peaks are capped at -2 dBFS before AAC preparation. The Physical revision now derives from the compact body impact. The Stun
revision retains its existing headroom adjustment. Perceptual balance still requires listening on hardware.

`loot_exceptional` uses the full 1.07-second harpsichord quick chime, preserving
its natural decay with only 5 ms of end smoothing. Its level matches the approved
harpsichord audition. The source revision is `loot_exceptional_harpsichord_01.wav`,
derived from `harpsichord_chime_quick__existing_library_unattributed__d4797e91fa2b61fd.flac`.
The original talent-unlock cue and earlier loot revision are preserved. The paths of the selected sources are recorded in the manifest.

## Shared sound-fit selections

The 2026-10-15 Trinket/Alchemy comparison selects existing authored sources from
both games, plus shared revisions under
`Sounds/Game Sources/Sound Effects/Shared Revisions/sound_fit_20261015/`.
The library's `sources.json` records each revision's inputs and processing.
The compact body hit replaces generic Swish Hit; Slash and Stab have separate
weapon cues. Their critical sources use the critical treatment above.

Astral Arrow uses one baked bow/element recording: bow at 0 seconds with gain
0.8, and the resolved Burn, Freeze or Piercing recording at 0.12 seconds with
gain 0.35. Its critical variants use the same transient/duration treatment.
The rock impact for Meteor/Earthquake selects 0–1.2 seconds with 5 ms entry and
60 ms exit fades. All shared revisions are 48 kHz stereo 24-bit PCM with a
-2 dBFS source peak ceiling. Buff and standalone Mana restore use fixed +7.8 dB
revisions of the shared Buff Pickup source; Coin Gathering replaces the quiet
collection source and the longer buy/sell cue. Musical and perceptual balance
still require hardware listening. These source changes do not alter user volume,
AVAudioSession behavior, overlap policy, or haptics.
