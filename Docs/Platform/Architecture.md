# Architecture

High-level structure for Trinket.

## Repository layout

```text
Trinket/                    Thin app target — entry, roots, non-Battle product screens
  App/                      TrinketApp, ContentView, launch/error presentation
  Features/                 Play, Collection, Homestead, and Options screens
  Assets.xcassets           Processed art (HEIC) from ArtManifest
  Resources/Music           AAC tracks from MusicManifest
  Resources/SFX             AAC clips from SoundManifest
  Resources/Cinematics      Ultimate cinematic MP4s from CinematicManifest

Packages/
  TrinketCore/              Domain primitives (effects, stats, enums, progression)
  TrinketContent/           Catalogs + Generated/ content, encounter-level resolution, art, music, SFX, and cinematic catalogs
  BattleEngine/             Card combat rules, effect handlers, decks/hand
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      App chrome, surfaces, typography, Keyword visuals, ExperienceBar (TrinketCore only)
  TrinketFeatureSupport/    Shared game UI, presentation models, IDs, artwork/frame support
  TrinketBattleFeature/     Battle facade, read lanes, presentation, outcome, and Battle UI
  TrinketAppState/          App/Play orchestration, encounter sessions, options, and audio
  TrinketTestSupport/       Shared combat/content fixtures (CombatantFixtures, battle parties)

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
| Player save, stores, CloudKit sync, domain write policies | `TrinketPersistence` | `PlayerSaveStore`, `Player*Store`; campaign reward/completion appliers (`BattleLoot`, `StageCompletion`, `LabyrinthCompletion`, `SpireCompletion`, `ShopPurchaseApplier`, `MysteryEffectApplier`) mutate the save graph — app sessions decide *when*, Persistence owns *what write* |
| Shared UI chrome | `TrinketDesignSystem` | Backgrounds, surfaces, typography, Keyword visuals, `ExperienceBar`, `HomesteadTint` colors, motion primitives |
| Shared feature support | `TrinketFeatureSupport` | Game-specific cards/detail panes, presentation models, `AccessibilityID`, prepared artwork, frame-pacing contracts |
| Battle presentation | `TrinketBattleFeature` | `BattleSession`, combat projection, feedback/spectacle lanes, Battle UI; `ActiveBattleConfiguration` is a pure DTO of pre-resolved party/enemy/reward inputs (opaque `BattleRunKey`, defeat action, progression flag, music stage id, claimed-stage policy, gold-find percent, baked XP/material awards). BattleFeature must not branch on play-mode identity or assemble from live save slices. |
| App and Play orchestration | `TrinketAppState` | `AppState` composition/wiring only — battle handle lives on `PlaySession.battle`; `PlaySession` shell/registry via `PlayModeGraph`; `PlayBattleOrigin` (mode passport); `PlayBattleLaunch` (encounter/loot resolution + party/reward bake + configure/activate) + `PlayBattleCompletion` (origin resolve → mode write → dismiss); mode owners `JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`, `EncounterPlayMode` for navigation/session and mode-unique writes; encounter sessions; preferences; audio routing |
| App entry and non-Battle screens | `Trinket` | SwiftUI roots plus Play, Collection, Homestead, and Options views |
| Processed bundle assets | `Trinket/Assets.xcassets`, `Trinket/Resources/` | Binary art/music committed after `--assets` codegen |

## Product tabs vs code

Persistent player-facing tabs:

```text
Play → Collection → Homestead → Options
```

Code mapping:

| UI label | `AppTab` | Feature owner |
|----------|----------|----------------|
| Play | `.play` | `Trinket/Features/Play` |
| Collection | `.collection` | `Trinket/Features/Collection` — Heroes, Companions, and Inventory |
| Homestead | `.homestead` | `Trinket/Features/Homestead` |
| Options | `.options` | `Trinket/Features/Options` |

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

Arrows mean “may depend on.” Every edge points downward; reverse edges are forbidden.

```text
Trinket app
  ├── TrinketAppState
  │     ├── TrinketBattleFeature
  │     │     └── TrinketFeatureSupport
  │     ├──────── TrinketFeatureSupport
  │     └──────── TrinketFeatureAdapters
  ├── TrinketBattleFeature
  ├── TrinketFeatureSupport
  └── TrinketFeatureAdapters

TrinketBattleFeature ───→ TrinketFeatureSupport

TrinketFeatureAdapters ──→ TrinketFeatureSupport
        │                   BattleEngine
        │                   TrinketPersistence
        │                   TrinketContent
        │                   TrinketDesignSystem
        └─────────────────→ TrinketCore

TrinketFeatureSupport ───→ TrinketContent ──→ TrinketCore
        └───────────────→ TrinketDesignSystem ──→ TrinketCore

BattleEngine ───────────→ TrinketContent ──→ TrinketCore
TrinketPersistence ─────→ TrinketContent ──→ TrinketCore
TrinketDesignSystem ───────────────────────→ TrinketCore
```

`BattleEngine` and `TrinketPersistence` remain siblings and never import one another.
`TrinketFeatureSupport` is persistence- and battle-engine-free reusable presentation.
`TrinketFeatureAdapters` owns save-backed map/detail adapters and combat build resolution;
it cannot be imported by `TrinketBattleFeature`. Neither support target may depend on
`TrinketBattleFeature` or `TrinketAppState`.
`TrinketBattleFeature` cannot depend on `TrinketAppState`. No package may import the
`Trinket` app module. `./Scripts/check-module-boundaries.sh` enforces these rules in
both source imports and package manifests.

The app target is a composition root and view host. App views receive the narrowest
available owner (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
`EncounterPlayMode`, an encounter session, `BattleSession`, or one of Battle’s read
lanes) instead of observing `AppState` or the full `PlaySession` for unrelated state.
Shell battle activation routes through `PlaySession.battle` (injected into the
environment from `appState.play.battle`). `PlaySession` remains in the environment for
shell concerns (pending destination, map scroll, battle victory routing via
`PlayBattleCompletion`). Play screens read save slices from `PlayerSaveStore` directly —
not through `PlaySession` facades. Mode types own map/node/floor selection and
mode-unique completion writes; they must not re-absorb the shared victory
persist→dismiss sequence. The battle launch and DTO contract is defined in the
Module ownership table above; package-specific routing is in
`Docs/AgentContext/battle.md`.

## Persistence overview

- **Canonical save:** SwiftData models in `TrinketPersistence` form the player database object graph, split across `PlayerSaveGraph/` (journey, roster, inventory, homestead, aspects, labyrinth). `PlayerSaveRoot` owns optional CloudKit-compatible relationships to journey, roster, inventory, homestead, aspects, and labyrinth records; child rows hold per-stage progress, combatant progression/loadouts, inventory items/affixes, homestead balances/tiers, and mode progress.
- **Save hub:** `PlayerSaveStore` opens the versioned `ModelContainer` via `PlayerSaveMigrationPlan`, `ModelContainerBootstrap`, and `PlayerSaveStoreConfiguration`. A failed canonical-store open preserves the on-disk files and uses an explicitly degraded in-memory fallback; only a player-requested reset deletes progress. Value types such as `PlayerSave` remain calculation snapshots, not the canonical persisted form. The hub owns write-through, deferred save/rollback, and reset/seed only.
- **Domain actions:** Single-slice reads/writes go through `PlayerSaveStore` properties (`journey`, `roster`, `inventory`, `homestead`, `aspects`, `labyrinth`). Cross-slice player actions live on `PlayerHomesteadStore` (e.g. `buildOrUpgradeNode`); access via `playerSave.homesteadStore`.
- **Write locality:** Every mutation computes a `PlayerSaveSlice` diff. Setters and batches reconcile and save only changed slices; rollback refreshes only touched slices. Stable child-row identities are preserved when values change.
- **Options/preferences:** `TrinketAppState.OptionsStore` persists volumes and haptics via `AppStorage`-compatible keys on a local `UserDefaults` suite — intentionally **not** part of `PlayerSave` / CloudKit. Best-effort shell session state (selected tab, map scroll, and last Play mode) remains on the local `PlayerShellSessionStore`; legacy battle-resume keys are discarded. The app is always dark mode (no appearance preference).
- **Sync:** SwiftData is CloudKit-ready (`iCloud.com.ryanmcintire.Trinket`) but **local-only until** Apple Developer Program enrollment fills entitlements. Simulator/tests keep CloudKit off unless `-enable-cloud-sync`. See `Docs/Platform/CloudKitPreShipChecklist.md`.
- **Identity:** No in-app login. Cross-device progress **is** iCloud private CloudKit sync (system Apple Account). Play always works local-only. No Sign in with Apple, Google, or hosted accounts — see `Docs/Platform/IdentityPlan.md`.
- **Pre-ship:** `Docs/Platform/CloudKitPreShipChecklist.md`, `Docs/Platform/IdentityPlan.md`
- **Audio:** `TrinketAppState.MusicPlayer` uses ambient `AVAudioPlayer` by design.

## Extension policy (hub containment)

Keep `BattleState` and `PlayerSaveStore` as thin facades. Do not grow their type bodies with feature-specific logic.
Keep `AppState` as composition/wiring — new Play feature methods belong on mode owners or on `PlayBattleLaunch` / `PlayBattleCompletion`, not on `AppState`.

| Hub | Put new code here | Not here |
|-----|-------------------|----------|
| `BattleState` | `EffectHandlers/`, `*Engine`, `DamagePipeline`, or `BattleState+*.swift` for shared mutation plumbing | Catalog-specific branches; app/feature call sites for engine mutations |
| `PlayerSaveStore` | Value-type rules in `Models/`; cross-slice actions on `PlayerHomesteadStore`; open/config in `PlayerSaveStoreConfiguration` | Feature-specific methods on the hub class; empty pass-through facades |
| `AppState` / `PlaySession` | Bootstrap/wiring; shell navigation via `play.battle`; `PlayModeGraph` assembly; forwarders to `PlayBattleLaunch` / `PlayBattleCompletion`; encounter/loot/claimed-stage resolve and party/reward bake on `PlayBattleLaunch`; `PlayBattleOrigin` encode/decode | Mode-specific prepare/start/complete bodies on `PlaySession`; Persistence write policy; mode-branching resolve or live journey/homestead reads on `ActiveBattleConfiguration` / Battle UI; a parallel `AppState.battle` handle |
| Combat triggers | Authored `CombatTraitTriggers` (Content + codegen); nested on `CombatModifierProfile.triggers` | Parallel flat fields on `CombatModifierProfile` |

`BattleState` public API is reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package` in `BattleState+*.swift`.

## Tech stack

Apple API notes: [iOS26AppleReference.md](iOS26AppleReference.md). Platform index: [README.md](README.md).

- iOS 26.0, Swift 6.0, SwiftUI shell
- Local packages use `swift-tools-version: 6.2` so `Package.swift` can declare `.iOS(.v26)`
- Swift 6 strict concurrency enabled on all package targets
- Swift Testing unit + XCTest UI (tiered via `.xctestplan` files)
- XcodeGen (`project.yml`), SwiftLint, SwiftFormat
- No third-party Swift dependencies
- Battle presentation is SwiftUI; SpriteKit is not in use.
- Battle simulation lives behind `BattleSimulationStore` and `BattleSimBridge`.
  `BattleSession` owns lifecycle and commands; `BattlePresentationState`, `BattleFeedbackLane`, and
  `BattleSpectacleState` are distinct observable read lanes. A committed engine
  transition publishes one combat snapshot before its feedback/outcome work.
- Card casts use one SwiftUI presentation lane. Feedback uses an always-mounted, preallocated UIKit raster host — a **bounded performance island** (see below), not a growth surface for new `UIViewRepresentable`s.
- Headless simulation, balance policies, sweeps, and reporting live in the app-unlinked
  `BattleBalanceTools` target; runtime mechanics remain in `BattleEngine`.
- Semantic tests live with their package owner. `./Scripts/test.sh unit` compiles the
  app unit target and runs all production package suites; focused iteration uses
  `./Scripts/test-package.sh <Package>`.

### Battle UIKit feedback island

Combat floating chips use always-mounted UIKit hosts (`CombatFeedbackRasterHost`, `CombatFeedbackChipBridge`, glyph atlas / composers) so chip publishes skip SwiftUI battle-chrome invalidation. This is an intentional performance exception to the root “prefer SwiftUI” guardrail.

| May enter the island | Must stay SwiftUI / State recipes |
|----------------------|-----------------------------------|
| New chip kinds via existing host + recipe/data APIs | New parallel `UIViewRepresentable` stacks |
| Raster/glyph cache tweaks measured against hitch budgets | Feature chrome, hand, battlefield layout |
| DEBUG MotionLabs that tune recipe/config values | Shipping MotionLab UI (labs stay `#if DEBUG` only) |

Do not rewrite the host for purity unless Instruments shows SwiftUI can match hitch budgets. Production motion constants live in recipe/config types (`BattleHandMotionConfiguration`, `CombatFeedback*Recipes`, DesignSystem motion); MotionLab files are DEBUG playgrounds and must not become production surface.

### Standing platform rules

- Use modern SwiftUI only: `NavigationStack`, modern `Tab`, `@Observable` / `@Environment` / `@Bindable`, two-parameter `onChange`. Do not reintroduce `NavigationView`, `ObservableObject` / `@Published`, or single-parameter `onChange`.
- Route custom glass and prominent buttons through `TrinketDesignSystem`; feature views must not call raw `.glassEffect` / `.buttonStyle(.glass*)`. Glass belongs on functional chrome; dense Collection / Inventory / Options content stays on solid themed surfaces.
- Keep the root tab bar fully expanded (do not adopt tab-bar minimize-on-scroll). Hidden toolbar chrome on Battle and detail-hero screens is an intentional art-forward choice.
- Options/haptics stay on `AppStorage`-compatible local keys — not part of `PlayerSave` / CloudKit. Gate sensory feedback with `.trinketSensoryFeedback`.
- Accessibility stays visual-first per PD-007: stable UI-test identifiers and native controls; no custom VoiceOver semantics or accessibility-setting branches without an explicit product decision.
- When adopting new frameworks later: StoreKit 2, modern GameKit, RealityKit — not StoreKit 1, legacy GameKit, or SceneKit.

## Deferred improvements

Do not start these without a concrete forcing function:

| Deferral | Why wait |
|----------|----------|
| Split `TrinketContent` into catalogs vs procedural systems | Same package is intentional until a third consumer forces the seam; keep new generators beside existing ones |
| Split `TrinketFeatureSupport` by product domain | Shared UI/presentation layer is intentional until a domain folder has an independent consumer or mixed-job hotspot that forces a carve-out; prefer collapsing duplicate shells in place first |
| CloudKit enablement | Local-only until Developer Program + [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) |
| Further Battle presentation splitting | Simulation, projection, feedback, and spectacle already have distinct owners; split again only when one lane has a concrete independent responsibility |
