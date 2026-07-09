# BattleEngine Tests

Test ownership matrix for `Packages/BattleEngine/Tests/BattleEngineTests/`.

Each behavior should have **one primary owner**. Integration files only test
cross-boundary contracts through `BattleState.advanceOneStep()`. If a test does
not need the full battle loop, it belongs in a unit file instead.

## Ownership matrix

| Concern | Owner | Example |
|---------|-------|---------|
| Pure formulas | `TrinketCoreTests/PrimaryStatsRulesTests` | `controlMeterThreshold` |
| Combatant defaults | `TrinketContentTests/CombatantModelTests` | zero `primaryStats` |
| Single engine step | `*EngineTests`, `*PipelineTests` | `ControlMeterEngine.applyMeterCharge` |
| Turn consumption | `BattleTurnEngineTests` | `consumeActionSkip` |
| Handler apply/tick | `EffectHandlers*Tests` | cleanse removes meter |
| Presentation strings | `EffectSummaryBuilderTests`, `ActionEventFormatterTests` | “Stun Build-up: 3/10” |
| Turn loop wiring | `*IntegrationTests` (thin, 3–6 tests) | skip claims turn slot |
| Full battle regression | `BattleGoldenPathTests` | pinned tick/action/HP outcomes |
| Catalog ability combos | `AbilityEffectIntegrationTests` | Blackjack gold, Bloodthorn |

## Integration files

| File | Scope |
|------|-------|
| `ControlMeterIntegrationTests` | Stun/freeze meter → skip through ticks |
| `CleanseIntegrationTests` | Cleanse abilities through ticks |
| `MitigationIntegrationTests` | Shield/armor through ticks |
| `RestorationIntegrationTests` | Heal/leech through ticks |
| `StatIntegrationTests` | Stats flowing into damage/heal in battle |
| `AbilityEffectIntegrationTests` | Multi-effect catalog abilities |

## Conventions

- File headers list what the file owns and what it defers elsewhere.
- Parameterize symmetric keywords (stun/freeze) instead of duplicating tests.
- Assert event semantics and HP deltas, not full log fingerprints.
- Shared setup lives in `Support/BattleTestFixtures.swift`.
- `Docs/Testing.md` defers exhaustive log/UI prose unit tests; keep `ActionEventFormatterTests` representative only.

## Where to put new combat code

Do **not** grow `BattleState.swift` with feature logic. Prefer:

1. Effect-specific rules → `EffectHandlers/`
2. Shared combat math → existing `*Engine` / `DamagePipeline` / applicator
3. Shared mutation plumbing used by multiple engines → `BattleState+*.swift` (`package`)
4. Never add catalog-specific branching to `BattleState`

Public facade: reads + `advanceOneStep` / log lifecycle. Engine mutations are `package`.
