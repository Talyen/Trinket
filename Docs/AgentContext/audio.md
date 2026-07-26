# Audio context

Use for music routing, SFX mapping, playback behavior, and audio content.

Authored track and SFX metadata belongs in `MusicManifest/` and `SoundManifest/`; run the asset-generation workflow in `content-and-manifests.md` for input changes. Playback glue lives in `Trinket/Audio/`; the current music player intentionally uses ambient `AVAudioPlayer`. Battle feedback mappings are feature glue, not content catalogs.

Keep audio ownership layered: catalog metadata in `TrinketContent`, player state/preferences in `OptionsStore`, routing/playback in `Trinket/Audio/`, and battle event interpretation at the feature/battle boundary. Do not unit-test AVFoundation playback or real device audio output; test deterministic routing/mapping logic instead.

Verify with path-scoped `./Scripts/verify-changed.sh --isolate --paths …` (routes unit for `Trinket/Audio/*`). Policy and path-scoped tiers: `Docs/Platform/Testing.md` and `Docs/AgentContext/ci-and-project-generation.md`. Smoke only when a player-flow Feature path also changes. Read `Trinket/Audio/README.md` for current playback behavior.
