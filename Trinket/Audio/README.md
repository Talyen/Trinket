# Audio

Looping menu and encounter music via `MusicPlayer`, plus one-shot battle/UI clips via `SFXPlayer`.

## Stack choice

`AVAudioPlayer` + `AVAudioSession` category `.ambient` with `.mixWithOthers` is intentional:

- Ambient audio ducks under other apps and respects the Silent switch.
- Simple looping BGM and short SFX do not need `AVAudioEngine` graph complexity.
- Crossfades use structured `Task` cancellation on the main actor.

Do not migrate to AudioEngine unless product needs spatial audio, real-time effects, or sample-accurate scheduling.

## Sound effects

- Catalog: `SFXCatalog` from `SoundManifest/sfx.tsv` (AAC in `Trinket/Resources/SFX`).
- Playback: `SFXPlayer.play(_:volume:)` applies `OptionsStore.effectsVolume` × clip `volumeGain`.
- Battle routing: `CombatSFXMapper` maps feedback chips to stable IDs; ability play/draw and victory/defeat play from `BattleSession`.
- Wire additional UI cues (confirm/cancel/tap) as surfaces adopt them; prefer catalog IDs over raw URLs.
