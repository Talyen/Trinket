# TrinketCore

Domain primitives shared across all Trinket packages. No UIKit/SwiftUI dependencies.
Keep this package independent of the app and feature UI.

Owns effects and keywords, stats and combat rounding, progression and enemy power
curves, homestead resource/node types, and deterministic RNG. Imported by every other
package. Keep dependencies here at zero.

Module map: `Keyword.swift` (matching, rules), `Effect.swift` (`Effect`,
`DamageComponent`, potency, decay, targets), `Effect+Properties.swift`
(`EffectKind` registry key plus behavior flags and battle phrases),
`EffectPresentation.swift` (apply phrases), `CombatRounding.swift`,
`CombatantProgression.swift`, `ExperienceScaling.swift` with `EnemyPowerCurve.swift`
(shared mid/late thresholds live on `EnemyPowerCurve`), `TalentModels.swift`,
`HomesteadTypes.swift`, `ItemSlot.swift` with `ProgressionEnums.swift`,
`CombatPowerSnapshot.swift`, `SeededRandomNumberGenerator.swift`,
`BattleGoldFlow.swift`, `ActiveEffect.swift`, `Collection+Safe.swift`, `DamageCondition.swift`
(evaluation lives in `BattleEngine.BattleConditionEvaluator`).

Contracts: keyword matching runs through one case-insensitive pattern
(`Keyword.highlightPattern` with `Keyword.termLookup`), normalizing both straight (`'`)
and typographic curly (`’`) apostrophes; `Keyword.referenced(in:)`
and keyword highlighting share it. `SeededRandomNumberGenerator` is deterministic
per seed with a fixed non-zero fallback state; equality includes draw progress.
`Effect.durationTurns == 0` covers both instant effects and indefinite buffs;
`EffectKind` flags (`isInstant`, `advancesEachTurn`, removable buff/debuff) are
the source of truth for lifecycle, locked by `EffectModelTests`. Documented
quirks pending battle-owner review: `hemorrhage` never advances,
`maximumManaBonus` is both instant and a buff, `blessedAegis` is instant with
neither buff nor debuff flag. `BattleGoldFlow` clamps negatives and saturates
instead of trapping; `CombatRounding` maps non-positive bases to zero and
saturates at `Int.max`.

Talent eligibility resolves each node's row from its owning tree. `cappedUnlocks`
repairs selected IDs at every point budget, keeping only prerequisite-complete
selections in row, tree, then node order. Removed selections leave their points
available; valid selections within budget are unchanged.

```sh
./Scripts/test-package.sh TrinketCore
```
