# Battle context

Use for card rules, effects, decks/hands, turn flow, and battle presentation.

| Concern | Owner / entry point |
|---|---|
| Domain primitives | `Packages/TrinketCore` |
| Authored combatants, abilities, stages | `Packages/TrinketContent` and `ContentManifest/` |
| Rules, effect handlers, deck/hand | `Packages/BattleEngine` |
| Battle lifecycle contract | `Packages/TrinketBattleRuntime` (`BattleRuntime`, launch DTOs) |
| Battle lifecycle, outcome, and SwiftUI | `Packages/TrinketBattleFeature` (`BattleSession` implements the lifecycle contract and owns presentation); DTO and launch ownership is canonical in [Architecture → Module ownership](../Platform/Architecture.md#module-ownership). |
| Shared battle presentation DTO | `Packages/TrinketFeatureSupport/Sources/TrinketFeatureContracts` (`BattlePresentationContext`) |
| Play-mode origin + launch/reward bake | `Packages/TrinketAppState` (`PlayBattleOrigin`, `PlayBattleLaunch.assembleLaunch`, atomic `PlayBattleRunRegistration`, `PlayBattleCompletion`, mode owners) |

For rules, start with `BattleState`, the matching `EffectHandlers/` type, or
`CombatTriggerEngine` (`CombatTriggerEngine+*.swift` by cadence: damage, defense,
mana, card play, enemy turn, turn start/end, cleanse including post-cleanse heal/draw,
resources, holy, leech, party auras) plus the
closest test in `Packages/BattleEngine/Tests/`. `BattleState` is a facade: add shared
mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or
engines. Do not put feature calls in the engine.

On-hit and reaction work is split on purpose:

- `DamagePipeline` applies talent on-hit **applications** during damage resolution
  (`applyTalentDamageApplications` plus defender wards in
  `DamagePipelinePostSteps+Reactive`). These fire as part of the hit that caused
  them, including first-hit bonuses and attacker-ward DoTs.
- `CombatTriggerEngine` owns **post-hit cadence** (after spend mana, after dodge,
  after cleanse, turn start/end, enemy turn, leech, party auras). Do not fold
  those cadences into the pipeline, and do not merge affix scalar fields on
  `CombatModifierProfile` with `triggers` — that dual channel is intentional.

For presentation, `BattleSession` implements `BattleRuntime` and is the lifecycle,
command, simulation, and presentation coordinator for mutable `BattleState`.
App orchestration receives it only through the SwiftUI-free lifecycle contract.
`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns
bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns
cinematics and outcome timing. Views observe the narrow lane they render. App-level
options and audio enter through `BattleRuntimeDependencies`; Battle never imports
`TrinketAppState`. Victory chrome uses launch-baked awards — do not re-derive
`StageCompletion` policy inside BattleFeature outcome math.

The app composition root supplies `BattleRuntimeDependencies` as closure-only
capabilities and builds one concrete `BattleSession`. `PlaySession.battle` receives
that object only through the runtime contract; the root retains it for
presentation-only work. `PlaySession` stays in the environment for shell concerns
(pending destination, victory routing via `PlayBattleCompletion`). Active battle
route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry.
Play screens read save slices from `PlayerSaveStore` directly. Mode types own
map/node/floor selection and mode-unique completion writes; they must not re-absorb
the shared victory persist→dismiss sequence. `AppState` prepares audio and requests
launch state; the app root warms BattleFeature caches. Play's battle overlay
installs presentation context and presents launch-victory chrome once on the
retained `BattleSession`. Do not add presentation-only methods to `BattleRuntime`.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Use `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` and `EffectHandlers.all`. Do not assert full log prose.

Handoff routes `BattleEngine` vs `TrinketBattleFeature` vs `SmokeBattleTests`. Bare `./Scripts/test.sh smoke` runs the three-class smoke plan (tab shells, Battle, Shop).

Headless balance sweeps: `Packages/BattleEngine/README.md` and `./Scripts/balance-sweep.sh`. Engine hand size: that README. Presentation layout: `Packages/TrinketBattleFeature/README.md`.

Enemy scaling uses `EnemyPowerCurve` (smoothstep stat anchors at L1/L20/L40) applied after archetype growth. The same multiplier scales enemy HP and stats. Tune encounter level first, then curve anchors, then per-enemy stat shape. Progression hotspot reports include average enemy power rating.

Hidden fight pacing (`FightPacing`) band-scales authored combat magnitudes (damage, heals, block, DoT, control, ability mana) via comeback (losing side) and a progress-based clock (both sides). Passive turn-start mana drip is excluded.

Percentage multipliers on combat integers (damage, healing, control buildup, mana/gold bonuses) round via `CombatRounding` in `TrinketCore` (nearest integer, ties to even). Integer division semantics (half Block, gold-per-Block, half mana) stay as truncating division.

Talent trees organize 6 nodes across 3 visual unlock rows (2 per row). Power is flat across all rows — do not scale talent magnitude or impact by row level (`PD-013`). All talent nodes must be balanced equally as build side-grades. Combat-log names for talent triggers come from `CombatModifierProfile.triggerAbilityNames` (first writer wins when a node applies). Talent UI symbols use `Keyword.visualStyle`, not a field on `TalentNode`. Holy / turn-start / mana cleanses go through `CombatTriggerEngine.performRandomCleanses` so `afterCleansePerformed` always runs.

Party “additional damage vs poisoned/burning” auras **add their extra percents** across living allies (two +25% auras → +50%), and each contributor is logged by talent name. Hits spawned from a dodge (`DamageOptions.causedByDodge`) can themselves be dodged, but they do not run `afterDodge` again. Stun/Burn/Freeze damage uses the real type pipeline (control meter, stacks, build-up) — do not label a raw Health hit as Stun.

