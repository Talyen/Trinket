# Architecture

High-level structure for Trinket.

## Repository layout

```text
Trinket/                    App target — shell, features, presentation glue
  App/                      Entry, environment, tab routing
  Features/                 SwiftUI product surfaces (Play, Collection, Battle UI, …)
  BattleShell/              ActiveBattleConfiguration, EncounterLevelResolver, victory orchestration
  State/                    AppState, BattleSession, OptionsStore
  Models/                   SwiftUI presentation extensions (map, homestead UI, keyword colors)
  Shared/                   Reusable SwiftUI (cards, detail panes, layout, AccessibilityID)
  Audio/                    MusicPlayer, SFXPlayer, and AVFoundation glue
  Assets.xcassets           Processed art (HEIC) from ArtManifest
  Resources/Music           AAC tracks from MusicManifest
  Resources/SFX             AAC clips from SoundManifest
  Resources/Cinematics      Ultimate cinematic MP4s from CinematicManifest

Packages/
  TrinketCore/              Domain primitives (effects, stats, enums, progression)
  TrinketContent/           Catalogs + Generated/ content, art, music, SFX, and cinematic catalogs
  BattleEngine/             Card combat rules, effect handlers, decks/hand
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      App chrome, surfaces, typography, Keyword visuals, ExperienceBar (TrinketCore only)
  TrinketTestSupport/       Shared unit-test fixtures (CombatantFixtures, SaveTestSupport, battle parties)

ContentManifest/            affixes.tsv, item_bases.tsv, stages.tsv, combatants.tsv, …
ArtManifest/                curated-assets.tsv
MusicManifest/              music.tsv
SoundManifest/              sfx.tsv
CinematicManifest/          cinematics.tsv
Raw Assets/                 Source art/music/SFX/animations (not in Xcode target)
Scripts/                    generate, build, test, CI helpers
```

Manifests and pipelines live outside the app folder:

- `ContentManifest/*.tsv` → `Scripts/content_codegen.py` → `Packages/TrinketContent/Sources/TrinketContent/Generated/`
- `ArtManifest/curated-assets.tsv` → `Scripts/prepare-art-assets.sh` → `Packages/TrinketContent/.../Generated/ArtCatalog.generated.swift` + `Trinket/Assets.xcassets`
- `MusicManifest/music.tsv` → `Scripts/prepare-music-assets.sh` → `Packages/TrinketContent/.../Generated/MusicCatalog.generated.swift` + `Trinket/Resources/Music`
- `SoundManifest/sfx.tsv` → `Scripts/prepare-sfx-assets.sh` → `Packages/TrinketContent/.../Generated/SFXCatalog.generated.swift` + `Trinket/Resources/SFX`
- `CinematicManifest/cinematics.tsv` → `Scripts/prepare-cinematic-assets.sh` → `Packages/TrinketContent/.../Generated/UltimateCinematicCatalog.generated.swift` + `Trinket/Resources/Cinematics`

## Module ownership

| Concern | Owner | Notes |
|---------|-------|-------|
| Effects, keywords, stats, progression | `TrinketCore` | `CombatantProgression`, `Effect`, `Keyword`, `PrimaryStats` |
| Heroes, companions, enemies, abilities, affixes, stages, item bases | `TrinketContent` | Manifest-generated catalogs + art/music/SFX runtime metadata |
| Combat rules and card combat | `BattleEngine` | `BattleState`, effect handlers, decks/hand, `playCard` / `endTurn` |
| Player save, stores, CloudKit sync | `TrinketPersistence` | `PlayerSaveStore`, `Player*Store` |
| Shared UI chrome | `TrinketDesignSystem` | Backgrounds, surfaces, typography, Keyword visuals, `ExperienceBar`, `HomesteadTint` colors |
| Tab shell, orchestration | `Trinket/App`, `Trinket/State` | `AppState`, `BattleSession`, launch args |
| Product screens | `Trinket/Features` | One folder per tab or major flow |
| Game-specific shared UI | `Trinket/Shared` | Cards, detail panes, keyword text; `AccessibilityID` shared with UI tests |
| Processed bundle assets | `Trinket/Assets.xcassets`, `Trinket/Resources/` | Binary art/music committed after `--assets` codegen |

## Product tabs vs code

Persistent player-facing tabs:

```text
Play → Collection → Homestead → Options
```

Code mapping:

| UI label | `AppTab` | Feature folder |
|----------|----------|----------------|
| Play | `.play` | `Features/Play` |
| Collection | `.collection` | `Features/Collection` — Heroes, Companions, and Inventory |
| Homestead | `.homestead` | `Features/Homestead` |
| Options | `.options` | `Features/Options` |

## Generate workflow

**Single entry point:** `./Scripts/generate.sh`

1. Validate `ContentManifest` TSV files
2. Regenerate content catalogs (emits `public` directly from `content_codegen.py`)
3. Optionally prepare art, music, SFX, and cinematic catalogs (`--assets`)
4. Run XcodeGen

**Drift check:** `./Scripts/assert-generated-output.sh` after `generate.sh` (CI / pre-push: must match HEAD). Local `verify-changed` uses `--idempotent` instead so intentional uncommitted regeneration is allowed mid-task.

**Boundary check:** `./Scripts/check-module-boundaries.sh` (CI gate + `ci-locally.sh`).

After editing `ContentManifest/` or custom ability catalog files under `Packages/TrinketContent/Sources/TrinketContent/Content/`:

```sh
./Scripts/generate.sh
git add Packages/TrinketContent/Sources/TrinketContent/Generated/
```

After editing art, music, SFX, or cinematic manifests:

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

- **Canonical save:** SwiftData models in `TrinketPersistence` form the player database object graph, split across `PlayerSaveGraph/` (journey, roster, inventory, homestead, aspects, labyrinth). `PlayerSaveRoot` owns optional CloudKit-compatible relationships to journey, roster, inventory, homestead, aspects, and labyrinth records; child rows hold per-stage progress, combatant progression/loadouts, inventory items/affixes, homestead balances/tiers, and mode progress.
- **Save hub:** `PlayerSaveStore` opens the `ModelContainer` via `ModelContainerBootstrap` + `PlayerSaveStoreConfiguration` (disk → delete corrupt store → in-memory fallback). Value types such as `PlayerSave` remain calculation snapshots, not the canonical persisted form. The hub owns write-through, deferred save/rollback, and reset/seed only.
- **Domain actions:** Single-slice reads/writes go through `PlayerSaveStore` properties (`journey`, `roster`, `inventory`, `homestead`, `aspects`, `labyrinth`). Cross-slice player actions live on `PlayerHomesteadStore` (e.g. `buildOrUpgradeNode`); access via `playerSave.homesteadStore`.
- **Options/preferences:** `OptionsStore` persists volumes and haptics via `AppStorage`-compatible keys on a local `UserDefaults` suite — intentionally **not** part of `PlayerSave` / CloudKit. Session keys (tab/battle restoration) remain on the shell session store. The app is always dark mode (no appearance preference).
- **Sync:** SwiftData is CloudKit-ready (`iCloud.com.ryanmcintire.Trinket`) but **local-only until** Apple Developer Program enrollment fills entitlements. Simulator/tests keep CloudKit off unless `-enable-cloud-sync`. See `Docs/Platform/CloudKitPreShipChecklist.md`.
- **Identity:** No in-app login. Cross-device progress **is** iCloud private CloudKit sync (system Apple Account). Play always works local-only. No Sign in with Apple, Google, or hosted accounts — see `Docs/Platform/IdentityPlan.md`.
- **Pre-ship:** `Docs/Platform/CloudKitPreShipChecklist.md`, `Docs/Platform/IdentityPlan.md`
- **Audio:** `Trinket/Audio/MusicPlayer` uses ambient `AVAudioPlayer` by design — see `Trinket/Audio/README.md`.

## Extension policy (hub containment)

Keep `BattleState` and `PlayerSaveStore` as thin facades. Do not grow their type bodies with feature-specific logic.

| Hub | Put new code here | Not here |
|-----|-------------------|----------|
| `BattleState` | `EffectHandlers/`, `*Engine`, `DamagePipeline`, or `BattleState+*.swift` for shared mutation plumbing | Catalog-specific branches; app/feature call sites for engine mutations |
| `PlayerSaveStore` | Value-type rules in `Models/`; cross-slice actions on `PlayerHomesteadStore`; open/config in `PlayerSaveStoreConfiguration` | Feature-specific methods on the hub class; empty pass-through facades |

`BattleState` public API is reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package` in `BattleState+*.swift`.

## Tech stack

Apple API notes: [iOS26AppleReference.md](iOS26AppleReference.md). Platform index: [README.md](README.md).

- iOS 26.0, Swift 6.0, SwiftUI shell
- Local packages use `swift-tools-version: 6.2` so `Package.swift` can declare `.iOS(.v26)`
- Swift 6 strict concurrency enabled on all package targets
- Swift Testing unit + XCTest UI (tiered via `.xctestplan` files)
- XcodeGen (`project.yml`), SwiftLint, SwiftFormat
- No third-party Swift dependencies
- Battle presentation is SwiftUI; SpriteKit is not in use
- Battle simulation and fine-grained observable projections remain in `BattleSession`. `playCard` mutates
  the stored state, publishes one presentation snapshot plus feedback/outcome work, and returns a typed
  rejection/commit result. `BattleView` then publishes the owner swing and release-time cast in causal order.
- Card casts use one SwiftUI presentation lane. Feedback uses an always-mounted, preallocated raster host.
- Headless simulation, balance policies, sweeps, and reporting live in the app-unlinked
  `BattleBalanceTools` target; runtime mechanics remain in `BattleEngine`.
- Package tests run via `./Scripts/test.sh unit` in addition to `TrinketTests`

### Standing platform rules

- Use modern SwiftUI only: `NavigationStack`, modern `Tab`, `@Observable` / `@Environment` / `@Bindable`, two-parameter `onChange`. Do not reintroduce `NavigationView`, `ObservableObject` / `@Published`, or single-parameter `onChange`.
- Route custom glass and prominent buttons through `TrinketDesignSystem`; feature views must not call raw `.glassEffect` / `.buttonStyle(.glass*)`. Glass belongs on functional chrome; dense Collection / Inventory / Options content stays on solid themed surfaces.
- Keep the root tab bar fully expanded (do not adopt tab-bar minimize-on-scroll). Hidden toolbar chrome on Battle and detail-hero screens is an intentional art-forward choice.
- Options/haptics stay on `AppStorage`-compatible local keys — not part of `PlayerSave` / CloudKit. Gate sensory feedback with `.trinketSensoryFeedback`.
- Accessibility stays visual-first per PD-007: stable UI-test identifiers and native controls; no custom VoiceOver semantics or accessibility-setting branches without an explicit product decision.
- When adopting new frameworks later: StoreKit 2, modern GameKit, RealityKit — not StoreKit 1, legacy GameKit, or SceneKit.
