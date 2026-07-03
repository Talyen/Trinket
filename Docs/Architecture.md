# Architecture

High-level structure for Trinket after the Swift package migration.

## Repository layout

```text
Trinket/                    App target — shell, features, presentation glue
  App/                      Entry, environment, tab routing, package re-exports
  Features/                 SwiftUI product surfaces (Play, Collection, Battle UI, …)
  Battle/                   BattleRun, ActiveBattleConfiguration, victory UI wiring
  State/                    AppState, BattleSession, OptionsStore
  Models/                   SwiftUI presentation extensions (map, homestead UI, keyword colors)
  Content/                  App-only content extensions (encounter art overrides)
  Generated/                Art/music codegen output (do not edit)
  Shared/                   Reusable SwiftUI (cards, detail panes, layout)
  Audio/                    Music director

Packages/
  TrinketCore/              Domain primitives (effects, stats, enums, progression)
  TrinketContent/           Catalogs + Generated/ ability and affix catalogs
  BattleEngine/             Combat simulation, effect handlers, simulator
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      TrinketDesign chrome + ExperienceBar

ContentManifest/            abilities.tsv, affixes.tsv
ArtManifest/                curated-assets.tsv
MusicManifest/              music.tsv
Raw Assets/                 Source art/music/SFX (not in Xcode target)
Scripts/                    generate, build, test, CI helpers
```

Manifests and pipelines live outside the app folder:

- `ContentManifest/*.tsv` → `Scripts/content_codegen.py` → `Packages/TrinketContent/Sources/TrinketContent/Generated/`
- `ArtManifest/curated-assets.tsv` → `Scripts/prepare-art-assets.sh` → `Trinket/Generated/ArtCatalog.generated.swift`
- `MusicManifest/music.tsv` → `Scripts/prepare-music-assets.sh`

## Module ownership

| Concern | Owner | Notes |
|---------|-------|-------|
| Effects, keywords, stats, progression | `TrinketCore` | `CombatantProgression`, `Effect`, `Keyword`, `PrimaryStats` |
| Heroes, pets, enemies, abilities, affixes, stages | `TrinketContent` | Roster + enemies manifest-generated; abilities/affixes/stages manifest-generated |
| Combat rules and simulation | `BattleEngine` | `BattleState`, effect handlers, `BattleSimulator` |
| Player save, stores, CloudKit sync | `TrinketPersistence` | `PlayerSaveStore`, `Player*Store`, reconciler |
| Shared UI chrome | `TrinketDesignSystem` | `TrinketDesign`, `ExperienceBar` |
| Tab shell, orchestration | `Trinket/App`, `Trinket/State` | `AppState`, `BattleSession`, launch args |
| Product screens | `Trinket/Features` | One folder per tab or major flow |
| Game-specific shared UI | `Trinket/Shared` | Cards, detail panes, keyword text |
| Art/music runtime catalogs | `Trinket/Generated` | Generated from manifests |
| Encounter art overrides | `Trinket/Content` | Thin app extensions until manifest-driven |

## Product tabs vs code

Persistent player-facing tabs (`Docs/CoreDesignConcepts.md`):

```text
Play → Heroes → Inventory → Homestead → Options
```

Code mapping:

| UI label | `AppTab` | Feature folder |
|----------|----------|----------------|
| Play | `.play` | `Features/Play` |
| Heroes / Pets / Inventory | `.collection` | `Features/Collection` |
| Homestead | `.homestead` | `Features/Homestead` |
| Options | `.options` | `Features/Options` |
| Search | `.search` | `Features/Search` — **inventory search utility**; not a primary product tab |

## Generate workflow

**Single entry point:** `./Scripts/generate.sh`

1. Validate `ContentManifest` TSV files
2. Regenerate content catalogs and ability shorthand
3. Run `publicize_trinket_core.py` on generated Swift (adds `public` to generated types)
4. Optionally prepare art/music (`--assets`)
5. Run XcodeGen

**Drift check:** `./Scripts/assert-generated-output.sh` (CI runs this after `generate.sh`).

After editing `ContentManifest/` or custom ability catalog files under `Packages/TrinketContent/Sources/TrinketContent/Content/`:

```sh
./Scripts/generate.sh
git add Packages/TrinketContent/Sources/TrinketContent/Generated/
```

After editing art or music manifests:

```sh
./Scripts/generate.sh --assets
```

## Dependency rules

### Package graph

```text
TrinketCore
  ↑
TrinketContent          (Combatant, AbilityLoadout, roster + journey catalogs)
  ↑
BattleEngine
  ↑
TrinketPersistence      (depends on TrinketCore + TrinketContent only)
  ↑
TrinketDesignSystem     (depends on TrinketCore; Keyword visual styles)
  ↑
Trinket app
```

Packages must not import `Trinket` app code or SwiftUI feature views.

### App target layers

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `Battle/` | packages, `Models/`, `Content/` | `Features/` |
| `Features/` | packages, `State/`, `Shared/`, `Models/` | — |
| `State/` | packages, `Models/`, `Content/` | feature views |
| `Models/` | packages, SwiftUI | `State/`, `Features/` |

`Trinket/App/ExportedDependencies.swift` re-exports all packages into the app module for ergonomics. Prefer explicit `import` in new files when dependencies are narrow.

## Persistence overview

- **Canonical save:** `PlayerSave` encoded by `TrinketPersistence`; `PlayerSaveStore` is the write-through hub.
- **Domain stores:** `PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore` observe/mutate slices of the save.
- **Sync:** `PlayerSaveSyncCoordinator` debounces local writes and reconciles by `modifiedAt`; disabled in tests via `-disable-cloud-sync`.
- **App glue:** `Trinket/State/Persistence/PlayerSaveSyncFactory.swift` wires CloudKit vs local-only sync at launch.
- **Pre-ship:** `Docs/CloudKitPreShipChecklist.md`

## Tech stack

- iOS 26.0, Swift 6.0, SwiftUI shell
- Local packages use `swift-tools-version: 6.2` so `Package.swift` can declare `.iOS(.v26)`
- XCTest unit + XCUITest UI (tiered via `.xctestplan` files)
- XcodeGen (`project.yml`), SwiftLint, SwiftFormat
- No third-party Swift dependencies
- Battle presentation is SwiftUI; SpriteKit is not in use yet
- Package tests run via `./Scripts/test.sh unit` in addition to `TrinketTests`

## Migration status

Swift package extraction (phases 0–6) is **complete**. Remaining work is boundary tightening, content-pipeline expansion, and documentation — not another target split.

### Follow-up improvements (not yet done)

- SFX pipeline for `Raw Assets/Sound Effects/`
- Incremental Swift 6 strict concurrency per package
- Narrow `ExportedDependencies.swift` re-exports
