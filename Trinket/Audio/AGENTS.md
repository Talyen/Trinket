# Audio-local guide

Read `Docs/AgentContext/audio.md` before editing. Keep source metadata in manifests/catalogs and playback routing in this directory. Do not test live AVFoundation playback; test deterministic routing or mapping behavior.

Use the root task-scoped workflow for style and focused tests. When a player-facing flow changes, also run the affected smoke class (`./Scripts/test.sh smoke <Class>`); bare `./Scripts/test.sh smoke` is only the local Homestead canary.
