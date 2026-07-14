# Audio context

Use for music routing, SFX mapping, playback behavior, and audio content.

Authored track and SFX metadata belongs in `MusicManifest/` and `SoundManifest/`; run the asset-generation workflow in `content-and-manifests.md` for input changes. Playback glue lives in `Trinket/Audio/`; the current music player intentionally uses ambient `AVAudioPlayer`. Battle feedback mappings are feature glue, not content catalogs.

Keep audio ownership layered: catalog metadata in `TrinketContent`, player state/preferences in `OptionsStore`, routing/playback in `Trinket/Audio/`, and battle event interpretation at the feature/battle boundary. Do not unit-test AVFoundation playback or real device audio output; test deterministic routing/mapping logic instead.

Use the root task-scoped workflow for style and focused unit coverage of app-level logic. When an audible user flow changes, also run the affected smoke class (`./Scripts/test.sh smoke <SmokeClass>`); bare `./Scripts/test.sh smoke` is only the Homestead canary. Read `Trinket/Audio/README.md` for current playback behavior.
