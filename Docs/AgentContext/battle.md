# Battle context

Use for card rules, effects, decks/hands, turn flow, and battle presentation.

| Concern | Owner / entry point |
|---|---|
| Domain primitives | `Packages/TrinketCore` |
| Authored combatants, abilities, stages | `Packages/TrinketContent` and `ContentManifest/` |
| Rules, effect handlers, deck/hand | `Packages/BattleEngine` |
| Battle lifecycle contract | `Packages/TrinketBattleRuntime` (`BattleRuntime`, launch DTOs) |
| Battle lifecycle, outcome, and SwiftUI | `Packages/TrinketBattleFeature` (`BattleSession` implements the lifecycle-only runtime contract); DTO and launch ownership is canonical in [Architecture → Module ownership](../Platform/Architecture.md#module-ownership). |
| Play-mode origin + launch/reward bake | `Packages/TrinketAppState` (`PlayBattleOrigin`, `PlayBattleLaunch.assembleLaunch`, `PlayBattlePresentationContext`, `PlayBattleCompletion`, mode owners) |

For rules, start with `BattleState`, the matching `EffectHandlers/` type, and the
closest test in `Packages/BattleEngine/Tests/`. `BattleState` is a facade: add shared
mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or
engines. Do not put feature calls in the engine.

For presentation, `BattleSession` is the lifecycle/command facade and
`BattleSimulationStore` is the only BattleFeature owner of mutable `BattleState`.
`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns
bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns
cinematics and outcome timing. Views observe the narrow lane they render. App-level
options and audio enter through `BattlePresentationEnvironment`; Battle never imports
`TrinketAppState`. Victory chrome uses launch-baked awards — do not re-derive
`StageCompletion` policy inside BattleFeature outcome math.

Global cinematic warmup and launch-preview victory presentation are app-composition
responsibilities. Keep them on the concrete `BattleSession` at the app root (or behind
an app-owned callback); do not add presentation-only methods to `BattleRuntime`.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Use `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` and `EffectHandlers.all`. Do not assert full log prose.

The root task-scoped workflow selects style and package checks. For a narrow rules
iteration, run `./Scripts/test-package.sh BattleEngine`; for Battle presentation, run
`./Scripts/test-package.sh TrinketBattleFeature`. For UI-only battle changes, run
`./Scripts/test.sh smoke SmokeBattleTests` (or the closest focused smoke class /
method). Bare `./Scripts/test.sh smoke` is only the Homestead canary. Read the owning
package README for its test boundary.

Headless balance sweeps: `Packages/BattleEngine/README.md` and `./Scripts/balance-sweep.sh`. Battle layout contracts (three-card hand, art ratios, no top chrome) live in that README.

Enemy scaling uses `EnemyPowerCurve` (smoothstep stat anchors at L1/L20/L40) applied after archetype growth. The same multiplier scales enemy HP and stats. Tune encounter level first, then curve anchors, then per-enemy stat shape. Progression hotspot reports include average enemy power rating.

Hidden fight pacing (`FightPacing`) band-scales authored combat magnitudes (damage, heals, block, DoT, control, ability mana) via comeback (losing side) and a progress-based clock (both sides). Passive turn-start mana drip is excluded.

Percentage multipliers on combat integers (damage, healing, control buildup, mana/gold bonuses) round via `CombatRounding` in `TrinketCore` (nearest integer, ties to even). Integer division semantics (half Block, gold-per-Block, half mana) stay as truncating division.
