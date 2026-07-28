# Audio context

Use for music routing, SFX mapping, playback behavior, and audio content.

Authored track and SFX metadata belongs in `MusicManifest/` and `SoundManifest/`; run
the asset-generation workflow in `content-and-manifests.md` for input changes.
Playback and routing live in `Packages/TrinketAppState/Audio`; the current music
player intentionally uses ambient `AVAudioPlayer`. Battle feedback mappings live in
`TrinketBattleFeature`, not content catalogs.

Keep audio ownership layered: catalog metadata in `TrinketContent`, player
state/preferences and routing/playback in `TrinketAppState`, and battle event
interpretation in `TrinketBattleFeature`. Do not unit-test AVFoundation playback or
real device audio output; test deterministic routing/mapping logic instead.

Verify with path-scoped `./Scripts/verify-changed.sh --isolate --paths …` (routes the
`TrinketAppState` package suite). Policy and path-scoped tiers:
`Docs/Platform/Testing.md` and
`Docs/AgentContext/ci-and-project-generation.md`. Smoke only when a player-flow view
also changes. Current playback behavior is documented in
`Packages/TrinketAppState/README.md`.
