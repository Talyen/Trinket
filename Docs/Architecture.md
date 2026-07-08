# Architecture

High-level structure for Trinket after the Swift package migration.

## Repository layout

```text
Trinket/                    App target — shell, features, presentation glue
  App/                      Entry, environment, tab routing
  Features/                 SwiftUI product surfaces (Play, Collection, Battle UI, …)
  BattleShell/              ActiveBattleConfiguration, EncounterLevelResolver, victory orchestration
  State/                    AppState, BattleSession, OptionsStore
  Models/                   SwiftUI presentation extensions (map, homestead UI, keyword colors)
  Shared/                   Reusable SwiftUI (cards, detail panes, layout, AccessibilityID)
  Audio/                    Music director and AVFoundation glue
  Assets.xcassets           Processed art (HEIC) from ArtManifest
  Resources/Music           AAC tracks from MusicManifest

Packages/
  TrinketCore/              Domain primitives (effects, stats, enums, progression)
  TrinketContent/           Catalogs + Generated/ content, art, music, and SFX catalogs
  BattleEngine/             Combat simulation, effect handlers, simulator
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      App chrome, surfaces, typography, Keyword visuals, ExperienceBar (TrinketCore only)

ContentManifest/            abilities.tsv, affixes.tsv, item_bases.tsv, stages.tsv, …
ArtManifest/                curated-assets.tsv
MusicManifest/              music.tsv
SoundManifest/              sfx.tsv
Raw Assets/                 Source art/music/SFX (not in Xcode target)
Scripts/                    generate, build, test, CI helpers
```

Manifests and pipelines live outside the app folder:

- `ContentManifest/*.tsv` → `Scripts/content_codegen.py` → `Packages/TrinketContent/Sources/TrinketContent/Generated/`
- `ArtManifest/curated-assets.tsv` → `Scripts/prepare-art-assets.sh` → `Packages/TrinketContent/.../Generated/ArtCatalog.generated.swift` + `Trinket/Assets.xcassets`
- `MusicManifest/music.tsv` → `Scripts/prepare-music-assets.sh` → `Packages/TrinketContent/.../Generated/MusicCatalog.generated.swift` + `Trinket/Resources/Music`
- `SoundManifest/sfx.tsv` → `Scripts/prepare-sfx-assets.sh` → `Packages/TrinketContent/.../Generated/SFXCatalog.generated.swift`

## Module ownership

| Concern | Owner | Notes |
|---------|-------|-------|
| Effects, keywords, stats, progression | `TrinketCore` | `CombatantProgression`, `Effect`, `Keyword`, `PrimaryStats` |
| Heroes, pets, enemies, abilities, affixes, stages, item bases | `TrinketContent` | Manifest-generated catalogs + art/music/SFX runtime metadata |
| Combat rules and simulation | `BattleEngine` | `BattleState`, effect handlers, `BattleSimulator` |
| Player save, stores, CloudKit sync | `TrinketPersistence` | `PlayerSaveStore`, `Player*Store` |
| Shared UI chrome | `TrinketDesignSystem` | Backgrounds, surfaces, typography, Keyword visuals, `ExperienceBar`, `HomesteadTint` colors |
| Tab shell, orchestration | `Trinket/App`, `Trinket/State` | `AppState`, `BattleSession`, launch args |
| Product screens | `Trinket/Features` | One folder per tab or major flow |
| Game-specific shared UI | `Trinket/Shared` | Cards, detail panes, keyword text; `AccessibilityID` shared with UI tests |
| Processed bundle assets | `Trinket/Assets.xcassets`, `Trinket/Resources/` | Binary art/music committed after `--assets` codegen |

## Product tabs vs code

Persistent player-facing tabs (`Docs/Design/CoreDesignConcepts.md`):

```text
Play → Collection → Homestead → Search → Options
```

Code mapping:

| UI label | `AppTab` | Feature folder |
|----------|----------|----------------|
| Play | `.play` | `Features/Play` |
| Collection | `.collection` | `Features/Collection` — Heroes, Pets, and Inventory |
| Homestead | `.homestead` | `Features/Homestead` |
| Options | `.options` | `Features/Options` |
| Search | `.search` | `Features/Search` — **inventory search utility**; not a primary product tab |

## Generate workflow

**Single entry point:** `./Scripts/generate.sh`

1. Validate `ContentManifest` TSV files
2. Regenerate content catalogs (emits `public` directly from `content_codegen.py`)
3. Optionally prepare art, music, and SFX catalogs (`--assets`)
4. Run XcodeGen

**Drift check:** `./Scripts/assert-generated-output.sh` (CI runs this after `generate.sh`).

**Boundary check:** `./Scripts/check-module-boundaries.sh` (CI gate + `ci-locally.sh`).

After editing `ContentManifest/` or custom ability catalog files under `Packages/TrinketContent/Sources/TrinketContent/Content/`:

```sh
./Scripts/generate.sh
git add Packages/TrinketContent/Sources/TrinketContent/Generated/
```

After editing art, music, or SFX manifests:

```sh
./Scripts/generate.sh --assets
```

## Dependency rules

### Package graph

Arrows point upward to the dependency: `A ↑ B` means B depends on A.

```text
TrinketCore
  ↑
TrinketContent
  ↑
  ├── BattleEngine
  ├── TrinketPersistence
  └── Trinket app

TrinketCore
  ↑
TrinketDesignSystem
  ↑
Trinket app
```

`BattleEngine` and `TrinketPersistence` are siblings under `TrinketContent` (both depend on `TrinketContent` and transitively on `TrinketCore`, but not on each other). `Trinket app` also directly imports `BattleEngine`, `TrinketPersistence`, and `TrinketContent` as needed — the diagram highlights the two main dependency chains. `TrinketDesignSystem` depends on `TrinketCore` only so shared chrome can use domain primitives such as `Keyword` and `ItemSlot` without importing feature or content catalogs. Homestead node tint mapping for feature views lives in `Trinket/Models/Homestead.swift`.

Packages must not import `Trinket` app code or SwiftUI feature views.

### App target layers

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `BattleShell/` | packages, `Models/` | `Features/` |
| `Features/` | packages, `State/`, `Shared/`, `Models/` | — |
| `State/` | packages, `Models/` | feature views |
| `Models/` | packages, SwiftUI | `State/`, `Features/` |

App sources use **explicit** `import` per package. `./Scripts/apply-explicit-imports.py` can bootstrap imports after refactors.

## Persistence overview

- **Canonical save:** SwiftData models in `TrinketPersistence` form the player database object graph. `PlayerSaveRoot` owns optional CloudKit-compatible relationships to journey, roster, inventory, and homestead records; child rows hold per-stage progress, combatant progression/loadouts, inventory items/affixes, and homestead balances/tiers.
- **Save hub:** `PlayerSaveStore` owns a `ModelContainer` / `ModelContext`, creates the singleton root idempotently, and mutates model objects directly. Value types such as `PlayerSave`, `PlayerRosterState`, and `StageCompletionContext` are calculation snapshots, not the canonical persisted form.
- **Domain stores:** `PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore`, and homestead APIs observe/mutate slices through `PlayerSaveStore`.
- **Options/preferences:** `OptionsStore` (appearance, volumes) and `AppState` session keys (tab/battle restoration via `UserDefaults`) intentionally — not part of `PlayerSave` unless product requires cloud-synced settings.
- **Sync:** OS-managed SwiftData + CloudKit sync, configured with container `iCloud.com.ryanmcintire.Trinket`. Tests and local tools pass `-disable-cloud-sync` or use explicit local/in-memory containers to avoid CloudKit network access.
- **Pre-ship:** `Docs/Audits/CloudKitPreShipChecklist.md`

## Tech stack

Platform adoption notes and a point-in-time iOS 26 audit: `Docs/Platform/` ([README](Platform/README.md)).

- iOS 26.0, Swift 6.0, SwiftUI shell
- Local packages use `swift-tools-version: 6.2` so `Package.swift` can declare `.iOS(.v26)`
- Swift 6 strict concurrency enabled on all package targets
- Swift Testing unit + XCTest UI (tiered via `.xctestplan` files)
- XcodeGen (`project.yml`), SwiftLint, SwiftFormat
- No third-party Swift dependencies
- Battle presentation is SwiftUI; SpriteKit is not in use yet
- Package tests run via `./Scripts/test.sh unit` in addition to `TrinketTests`

## Migration status

Swift package extraction (phases 0–6) is **complete**. Boundary tightening and content-pipeline expansion are in progress:

- ✅ Explicit package imports in the app (no blanket re-exports)
- ✅ Manifest-driven item bases and encounter art
- ✅ Art/music/SFX catalogs owned by `TrinketContent`
- ✅ CI module-boundary enforcement
- 🔜 Populate `SoundManifest/sfx.tsv` when `Raw Assets/Sound Effects/` sources land
