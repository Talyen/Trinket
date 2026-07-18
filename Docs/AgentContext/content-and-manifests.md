# Content and manifest context

Use for abilities, item bases, stages, art, music, SFX, cinematics, and project generation.

| Input | Run | Review |
|---|---|---|
| `ContentManifest/` or custom source in `TrinketContent/Content/` | `./Scripts/generate.sh` | Expected catalog diff |
| `ArtManifest/`, `MusicManifest/`, `SoundManifest/`, `CinematicManifest/`, or matching raw inputs | `./Scripts/generate.sh --assets` | Generated catalog plus expected processed files |
| `project.yml` | `./Scripts/generate.sh` | Regenerated project diff |

Read and edit the source manifest only. Do not use generated catalogs to understand content and never hand-edit generated Swift, processed assets/resources, or the Xcode project. After generation, `./Scripts/verify-changed.sh` uses `assert-generated-output.sh --idempotent` (regenerate must be a no-op). Before push/CI, the default assert checks generated paths match HEAD — stage only outputs caused by the changed input.

For content invariants, use `TrinketContentTests` and run `./Scripts/test.sh style` plus `./Scripts/test-package.sh TrinketContent`. Pipeline formats live in each manifest directory's README; open only the one you are changing.
