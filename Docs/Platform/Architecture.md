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
  BattleEngine/             Card combat rules, effect handlers, decks/hand, `CombatBuildResolver` (app-unlinked `BattleBalanceTools`)
  TrinketPersistence/       Save model, stores, migration, CloudKit sync
  TrinketDesignSystem/      App chrome, surfaces, typography, Keyword visuals, ExperienceBar (TrinketCore only)
  TrinketFeatureSupport/    Package hosting shared UI and contract/adapter products
    Sources/TrinketFeatureSupport/    Shared game UI, presentation models, artwork/frame support
    Sources/TrinketFeatureContracts/ Pure navigation/deep-link values, battle presentation/reward DTOs (SwiftUI-free)
    Sources/TrinketFeatureAdapters/  Save-backed map/detail adapters
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
| Effects, keywords, stats, progression | [TrinketCore](../../Packages/TrinketCore/README.md) | Domain primitives; no UI or app dependencies |
| Catalogs and authored content | [TrinketContent](../../Packages/TrinketContent/README.md) | Manifest/codegen boundary and runtime catalog |
| Combat rules and card combat | [BattleEngine](../../Packages/BattleEngine/README.md) | Simulation owner |
| Player save, stores, and sync wiring | [TrinketPersistence](../../Packages/TrinketPersistence/README.md) | Canonical save graph and write policy |
| Shared UI chrome | [TrinketDesignSystem](../../Packages/TrinketDesignSystem/README.md) | Product colors, materials, typography, and reusable chrome |
| Shared feature support | [TrinketFeatureSupport](../../Packages/TrinketFeatureSupport/README.md) | Game-specific presentation support and contracts |
| Feature contracts | [TrinketFeatureContracts](../../Packages/TrinketFeatureSupport/README.md) | SwiftUI-free contract values; no save or view adapters |
| Battle presentation | [TrinketBattleFeature](../../Packages/TrinketBattleFeature/README.md) | Battle lifecycle, projection, feedback, spectacle, and UI |
| App and Play orchestration | [TrinketAppState](../../Packages/TrinketAppState/README.md) | Composition, shell navigation, mode owners, and audio |
| App entry and non-Battle screens | `Trinket` | SwiftUI roots and product screens |
| Processed bundle assets | `Trinket/Assets.xcassets`, `Trinket/Media/` | Generated app resources |

Battle launch/DTO contract: [battle-runtime.md](../AgentContext/battle-runtime.md). Persistence graph: [TrinketPersistence README](../../Packages/TrinketPersistence/README.md). UIKit feedback island: [TrinketBattleFeature README](../../Packages/TrinketBattleFeature/README.md). SwiftUI standing rules: [swiftui-features.md](../AgentContext/swiftui-features.md) and [TrinketDesignSystem README](../../Packages/TrinketDesignSystem/README.md). Shared fixtures: [TrinketTestSupport README](../../Packages/TrinketTestSupport/README.md).

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

Single entry point: `./Scripts/generate.sh` (add `--assets` for art, music, SFX, and cinematics). Operational steps, authored vs generated inputs, and ability catalogs: [content-and-manifests.md](../AgentContext/content-and-manifests.md). CI/pre-push asserts generated output matches HEAD. Path-scoped `handoff` runs `assert-generated-output.sh --idempotent` when generation inputs change; use `./Scripts/assert-generated-output.sh --idempotent` for a standalone check.

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
  │     ├── BattleEngine (BattleRuntime contract)
  │     └── TrinketFeatureContracts
  ├── TrinketBattleFeature
  ├── TrinketFeatureSupport
  └── TrinketFeatureAdapters

TrinketBattleFeature ───→ TrinketFeatureSupport
TrinketBattleFeature ───→ BattleEngine

BattleEngine ───────────→ TrinketContent ──→ TrinketCore

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
`TrinketFeatureAdapters` owns save-backed map/detail adapters;
it cannot be imported by `TrinketBattleFeature`. Neither support target may depend on
`TrinketBattleFeature` or `TrinketAppState`.
`TrinketBattleFeature` cannot depend on `TrinketAppState`. `TrinketAppState` depends on
`BattleEngine` (for `BattleRuntime`), never the presentation feature. No package may import the `Trinket`
app module. `./Scripts/check-module-boundaries.sh` enforces these rules in source imports
and package manifests.

The app target is a composition root. `TrinketAppState` production code depends on
`BattleEngine` and `TrinketFeatureContracts`, never concrete BattleFeature or
save-backed adapters. Views take the narrowest owner. Launch/DTO details:
[battle-runtime.md](../AgentContext/battle-runtime.md).

## Cross-cutting ownership pointers

The canonical persistence graph, local-only CloudKit posture, and options split
live in [persistence context](../AgentContext/persistence.md) and
[Identity.md](../Product/Identity.md). Audio ownership is in
[audio context](../AgentContext/audio.md). Do not copy those mutable details into
the architecture map.

## Extension policy (hub containment)

Keep `BattleState` and `PlayerSaveStore` as thin facades. Keep `AppState` as composition/wiring.

| Hub | Put new code here | Not here |
|-----|-------------------|----------|
| `BattleState` | `EffectHandlers/`, `*Engine`, `DamagePipeline`, or `BattleState+*.swift` for shared mutation plumbing | Catalog-specific branches; app/feature call sites for engine mutations |
| `PlayerSaveStore` | Value-type rules in `Models/`; cross-slice actions in `PlayerSaveStore+Homestead.swift` / `PlayerSaveStore+Roster.swift`; open/config in `PlayerSaveStoreConfiguration` | Feature-specific methods on the hub class; empty pass-through facades |
| `AppState` / `PlaySession` | Bootstrap/wiring; shell navigation via `play.battle`; `PlayModeGraph` assembly; forwarders to `PlayBattleLaunch` / `PlayBattleCompletion` | Mode-specific prepare/start/complete bodies on `PlaySession`; Persistence write policy; a parallel `AppState.battle` handle |
| Combat triggers | Authored `CombatTraitTriggers` (Content + codegen); nested on `CombatModifierProfile.triggers` | Parallel flat fields on `CombatModifierProfile` |

`BattleState` public API is reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package` in `BattleState+*.swift`.

## Deferred architecture seams

Do not begin a deferred split or platform expansion without the concrete forcing
function recorded in the [architecture deferrals knowledge pattern](../../.agents/knowledge/patterns/architecture-deferred-seams.md).
