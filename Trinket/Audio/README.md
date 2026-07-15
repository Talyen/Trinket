# Audio

Looping menu and encounter music via `MusicPlayer`, plus one-shot battle/UI clips via `SFXPlayer`.

## Stack choice

Music uses `AVAudioPlayer`. SFX use a prestarted `AVAudioEngine` with decoded PCM buffers.
Both share an `AVAudioSession` category of `.ambient` with `.mixWithOthers`:

- Ambient audio ducks under other apps and respects the Silent switch.
- Looping BGM remains simple and independent from the low-latency SFX graph.
- Battle SFX avoid decoder, seek, and player-start work on the frame that presents feedback.
- Crossfades use structured `Task` cancellation on the main actor.

## Sound effects

- Catalog: `SFXCatalog` from `SoundManifest/sfx.tsv` (AAC in `Trinket/Resources/SFX`).
- Playback: `SFXPlayer.play(_:volume:)` applies `OptionsStore.effectsVolume` × clip `volumeGain`.
- Battle routing: `CombatSFXMapper` maps feedback chips to stable IDs (deduped per presentation batch); `ability_draw` plays on opening hand / next-turn draw, and victory/defeat play from `BattleSession`.
- Wire additional UI cues (confirm/cancel/tap) as surfaces adopt them; prefer catalog IDs over raw URLs.
