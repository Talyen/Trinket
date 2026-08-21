# Battle context

Route metadata only: do not read this card by default when `agent-context.sh`
provides a focused subcard. Use it to resolve ownership when the path is unclear.

Use for card rules, effects, decks/hands, turn flow, battle lifecycle, and battle presentation. This is the routing card; load one focused subcard for the changed owner:

- [Engine rules](battle-engine.md) — `BattleEngine`, effect handlers, damage and trigger cadence.
- [Runtime and app launch](battle-runtime.md) — `BattleRuntime`, `BattleSession` lifecycle, prepared activation, and `AppState` orchestration.
- [Presentation](battle-presentation.md) — BattleFeature feedback, spectacle, outcomes, and SwiftUI ownership.
- [Balance and content rules](battle-balance.md) — scaling, pacing, rounding, talents, and combatant balance.

| Concern | Owner / entry point |
|---|---|
| Domain primitives | `Packages/TrinketCore` |
| Authored combatants, abilities, stages | `Packages/TrinketContent` and `ContentManifest/` |
| Rules, effect handlers, deck/hand | `Packages/BattleEngine` |
| Battle lifecycle contract | `Packages/TrinketBattleRuntime` (`BattleRuntime`, launch DTOs) |
| Battle lifecycle, outcome, and SwiftUI | `Packages/TrinketBattleFeature` (`BattleSession` implements the lifecycle contract and owns presentation) |
| Shared battle presentation DTO | `Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts` (`BattlePresentationContext`) |
| Play-mode origin + launch/reward bake | `Packages/TrinketAppState` (`PlayBattleOrigin`, launch assembly, run registration, completion, and mode owners) |

Keep the package boundary intact: the engine does not call feature or app code, BattleFeature does not import AppState, and app orchestration receives the live fight through the SwiftUI-free runtime contract.

Use the closest semantic package test. Do not load the balance or presentation subcards for an engine-only change, and do not recursively follow linked platform policy unless the task reaches that concern.
