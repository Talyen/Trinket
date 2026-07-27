# Audio-local guide

Audio routing and catalog structure must conform to `Docs/AgentContext/audio.md`. Keep source metadata in manifests/catalogs and playback routing in this directory. Do not test live AVFoundation playback; test deterministic routing or mapping behavior.

Audio-only changes need unit-level verification; smoke is required only when a player-flow Feature path also changes. Path-scoped verification must pass before handoff. Policy: `Docs/Platform/Testing.md`.
