# Audio-local guide

Read `Docs/AgentContext/audio.md` before editing. Keep source metadata in manifests/catalogs and playback routing in this directory. Do not test live AVFoundation playback; test deterministic routing or mapping behavior.

Verify with path-scoped `./Scripts/verify-changed.sh --isolate --paths …` (routes unit for `Trinket/Audio/*`). Policy and path-scoped tiers: `Docs/Platform/Testing.md` and `Docs/AgentContext/ci-and-project-generation.md`. Smoke only when a player-flow Feature path also changes.
