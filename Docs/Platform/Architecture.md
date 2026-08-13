# Architecture

High-level structure for Trinket.

## Repository layout

```text
Trinket/                    Thin app target — entry, roots, non-Battle product screens
  App/                      TrinketApp, ContentView, launch/error presentation
  Features/                 Play, Collection, Homestead, and Options screens
  Assets.xcassets           Processed art (HEIC) from ArtManifest
  Media/Music               AAC tracks from MusicManifest
  Media/SFX                 AAC clips from SoundManifest
  Media/Cinematics          Ultimate cinematic MP4s from CinematicManifest

Packages/
  TrinketCore/              Domain primitives (effects, stats, enums, progression)
  TrinketContent/           Catalogs + Generated/ content, encounter-level resolution, art, music, SFX, and cinematic catalogs
  BattleEngine/             Card combat rules, effect handlers, decks/hand
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      App chrome, surfaces, typography, Keyword visuals, ExperienceBar (TrinketCore only)
  TrinketFeatureSupport/    Package hosting shared UI and contract/adapter products
    Sources/TrinketFeatureSupport/    Shared game UI, presentation models, artwork/frame support
    Sources/TrinketFeatureContracts/ Pure navigation/deep-link values, battle presentation/reward DTOs (SwiftUI-free)
    Sources/TrinketFeatureAdapters/  Save-backed map/detail adapters and combat build resolution
  TrinketBattleRuntime/     SwiftUI-free battle lifecycle contract and launch DTOs
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

## Module ownership

| Concern | Owner | Notes |
|---------|-------|-------|
| Effects, keywords, stats, progression | [TrinketCore](../../Packages/TrinketCore/README.md) | `CombatantProgression`, `Effect`, `Keyword`, `PrimaryStats` |
| Heroes, companions, enemies, abilities, affixes, stages, item bases | [TrinketContent](../../Packages/TrinketContent/README.md) | Manifest-generated catalogs + art/music/SFX runtime metadata |
| Combat rules and card combat | [BattleEngine](../../Packages/BattleEngine/README.md) | `BattleState`, effect handlers, decks/hand, `playCard` / `endTurn` |
| Player save, stores, CloudKit sync, domain write policies | [TrinketPersistence](../../Packages/TrinketPersistence/README.md) | `PlayerSaveStore`, `Player*Store`; campaign reward/completion appliers mutate the save graph — app sessions decide *when*, Persistence owns *what write* |
| Shared UI chrome | [TrinketDesignSystem](../../Packages/TrinketDesignSystem/README.md) | Backgrounds, surfaces, typography, Keyword and Homestead resource visuals, `ExperienceBar`, motion primitives |
| Shared feature support | [TrinketFeatureSupport](../../Packages/TrinketFeatureSupport/README.md) | Game-specific cards/detail panes, presentation models, `AccessibilityID`, prepared artwork, frame-pacing contracts |
| Feature contracts | [TrinketFeatureContracts](../../Packages/TrinketFeatureSupport/README.md) | SwiftUI-free `CombatantDetailContext`, `StageMapMessage`, and `BattlePresentationContext`; no save or view adapters |
| Battle runtime contract | [TrinketBattleRuntime](../../Packages/TrinketBattleRuntime/README.md) | SwiftUI-free `BattleRuntime`, launch DTOs, and performance scenario contracts. Immutable simulation inputs and lifecycle only. |
| Battle presentation | [TrinketBattleFeature](../../Packages/TrinketBattleFeature/README.md) | `BattleSession` implements the runtime contract and owns lifecycle/simulation plus combat projection, feedback/spectacle lanes, and Battle UI. Must not branch on play-mode identity or assemble from live save slices. |
| App and Play orchestration | [TrinketAppState](../../Packages/TrinketAppState/README.md) | Composition/wiring, Play shell and mode owners, battle launch/completion, encounter sessions, preferences, and audio routing. |
| App entry and non-Battle screens | `Trinket` | SwiftUI roots plus Play, Collection, Homestead, and Options views |
| Processed bundle assets | `Trinket/Assets.xcassets`, `Trinket/Media/` | Binary art/music committed after `--assets` codegen |

Battle launch/DTO contract: [battle.md](../AgentContext/battle.md). Persistence graph: [TrinketPersistence README](../../Packages/TrinketPersistence/README.md). UIKit feedback island: [TrinketBattleFeature README](../../Packages/TrinketBattleFeature/README.md). SwiftUI standing rules: [swiftui-features.md](../AgentContext/swiftui-features.md) and [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md). Shared fixtures: [TrinketTestSupport README](../../Packages/TrinketTestSupport/README.md).

## Product tabs vs code

```text
Play → Collection → Homestead → Options
```

| UI label | `AppTab` | Feature owner |
|----------|----------|----------------|
| Play | `.play` | `Trinket/Features/Play` |
| Collection | `.collection` | `Trinket/Features/Collection` — Heroes, Companions, and Inventory |
| Homestead | `.homestead` | `Trinket/Features/Homestead` |
| Options | `.options` | `Trinket/Features/Options` |

## Generate

Single entry point: `./Scripts/generate.sh` (add `--assets` for art, music, SFX, and cinematics). Operational steps, authored vs generated inputs, and ability catalogs: [content-and-manifests.md](../AgentContext/content-and-manifests.md). CI/pre-push asserts generated output matches HEAD; local `handoff` uses `--idempotent`.

## Dependency rules

This is the enforced package-policy graph, not an exhaustive list of every direct app
target dependency. Arrows mean “may depend on.” Every edge points downward; reverse
edges are forbidden. `project.yml` and each `Package.swift` remain the executable
dependency sources of truth.
`TrinketFeatureSupport`, `TrinketFeatureContracts`, and
`TrinketFeatureAdapters` below are products/targets hosted by the single
`Packages/TrinketFeatureSupport` package.

```text
Trinket app
  ├── TrinketAppState
  │     ├── TrinketBattleRuntime
  │     └── TrinketFeatureContracts
  ├── TrinketBattleFeature
  ├── TrinketFeatureSupport
  └── TrinketFeatureAdapters

TrinketBattleFeature ───→ TrinketFeatureSupport
TrinketBattleFeature ───→ TrinketBattleRuntime

TrinketBattleRuntime ───→ BattleEngine ───→ TrinketContent ──→ TrinketCore

TrinketFeatureAdapters ──→ TrinketFeatureSupport
        │                   BattleEngine
        │                   TrinketPersistence
        │                   TrinketContent
        │                   TrinketDesignSystem
        └─────────────────→ TrinketCore

TrinketFeatureSupport ───→ TrinketContent ──→ TrinketCore
        └───────────────→ TrinketDesignSystem ──→ TrinketCore

TrinketFeatureContracts ──→ TrinketContent ──→ TrinketCore

BattleEngine ───────────→ TrinketContent ──→ TrinketCore
TrinketPersistence ─────→ TrinketContent ──→ TrinketCore
TrinketDesignSystem ───────────────────────→ TrinketCore
```

`BattleEngine` and `TrinketPersistence` remain siblings and never import one another.
`TrinketFeatureSupport` is persistence- and battle-engine-free reusable presentation.
`TrinketFeatureContracts` is the SwiftUI-free value layer for route and
`BattlePresentationContext`; it must not grow save-backed behavior.
`TrinketFeatureAdapters` owns save-backed map/detail adapters and combat build resolution;
it cannot be imported by `TrinketBattleFeature`. Neither support target may depend on
`TrinketBattleFeature` or `TrinketAppState`.
`TrinketBattleFeature` cannot depend on `TrinketAppState`. `TrinketAppState` depends on
`TrinketBattleRuntime`, never the presentation feature. No package may import the `Trinket`
app module. `./Scripts/check-module-boundaries.sh` enforces these rules in source imports
and package manifests.

The app target is a composition root. `TrinketAppState` production code depends on
`TrinketBattleRuntime` and `TrinketFeatureContracts`, never concrete BattleFeature or
save-backed adapters. Views take the narrowest owner. Launch/DTO details:
[battle.md](../AgentContext/battle.md).

## Persistence overview

- Canonical save is the SwiftData graph in `TrinketPersistence` (`PlayerSaveRoot` and slice stores). Value types such as `PlayerSave` are calculation snapshots.
- `PlayerSaveStore` is a thin hub: open/config, write-through, deferred save/rollback, reset/seed. Cross-slice homestead actions live on `PlayerHomesteadStore`.
- Options/haptics are `TrinketAppState.OptionsStore` on local `UserDefaults`, not `PlayerSave` / CloudKit. Shell tab selection is in-session only; cold launch lands on Play.
- Sync is CloudKit-ready (`iCloud.com.ryanmcintire.Trinket`) but local-only until [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md). Identity: [Identity.md](../Product/Identity.md).
- Audio playback lives in `TrinketAppState` (ambient `AVAudioPlayer` by design).

## Extension policy (hub containment)

Keep `BattleState` and `PlayerSaveStore` as thin facades. Keep `AppState` as composition/wiring.

| Hub | Put new code here | Not here |
|-----|-------------------|----------|
| `BattleState` | `EffectHandlers/`, `*Engine`, `DamagePipeline`, or `BattleState+*.swift` for shared mutation plumbing | Catalog-specific branches; app/feature call sites for engine mutations |
| `PlayerSaveStore` | Value-type rules in `Models/`; cross-slice actions on `PlayerHomesteadStore`; open/config in `PlayerSaveStoreConfiguration` | Feature-specific methods on the hub class; empty pass-through facades |
| `AppState` / `PlaySession` | Bootstrap/wiring; shell navigation via `play.battle`; `PlayModeGraph` assembly; forwarders to `PlayBattleLaunch` / `PlayBattleCompletion` | Mode-specific prepare/start/complete bodies on `PlaySession`; Persistence write policy; a parallel `AppState.battle` handle |
| Combat triggers | Authored `CombatTraitTriggers` (Content + codegen); nested on `CombatModifierProfile.triggers` | Parallel flat fields on `CombatModifierProfile` |

`BattleState` public API is reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package` in `BattleState+*.swift`.

## Deferred improvements

Do not start these without a concrete forcing function:

| Deferral | Why wait |
|----------|----------|
| Split `TrinketContent` into catalogs vs procedural systems | Same package is intentional until a third consumer forces the seam |
| Split `TrinketFeatureSupport` by product domain | Shared UI layer is intentional until a domain folder has an independent consumer |
| CloudKit enablement | Local-only until Developer Program + [CloudKitPreShipChecklist.md](CloudKitPreShipChecklist.md) |
| Further Battle presentation splitting | Simulation, projection, feedback, and spectacle already have distinct owners |
