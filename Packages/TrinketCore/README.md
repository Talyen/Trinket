# TrinketCore

Domain primitives shared across all Trinket packages. No UIKit/SwiftUI dependencies.
Keep this package independent of the app and feature UI.

Owns effects and keywords, stats and combat rounding, progression and enemy power
curves, homestead resource/node types, and deterministic RNG. Imported by every other
package. Keep dependencies here at zero.

Module map: `Keyword.swift` (cases, rules) with `KeywordHighlighting.swift`
(highlight pattern, term lookup, `referenced(in:)`), `Effect.swift` (`Effect`,
`DamageComponent`, potency, decay, targets), `Effect+Properties.swift`
(`EffectKind` registry key plus behavior flags),
`EffectPresentation.swift` (apply phrases plus battle summary phrases), `CombatRounding.swift` with
`SaturatedArithmetic.swift` (shared saturating `Int` math), `CombatantProgression.swift`,
`ExperienceScaling.swift` with `EnemyPowerCurve.swift`
(shared mid/late thresholds live on `EnemyPowerCurve`), `TalentModels.swift`,
`HomesteadTypes.swift` (retired-identifier aliases share one decode helper),
`ItemSlot.swift` with `ProgressionEnums.swift`,
`SeededRandomNumberGenerator.swift`,
`BattleGoldFlow.swift`, `ActiveEffect.swift` (plus display-only `EffectSummary`),
`Collection+Safe.swift`, `DamageCondition.swift`
(evaluation lives in `BattleEngine.BattleConditionEvaluator`; adding a case
must update its switch — `CoreValueTypesTests` pins the case count).

Contracts: keyword matching runs through one case-insensitive pattern
(`Keyword.highlightPattern` with `Keyword.termLookup`), normalizing both straight (`'`)
and typographic curly (`’`) apostrophes; `Keyword.referenced(in:)`
and keyword highlighting share it (implementation in `KeywordHighlighting.swift`).
`SeededRandomNumberGenerator` is deterministic
per seed with a fixed non-zero fallback state; equality is lineage (seed plus
draw progress), so the zero seed and the fallback seed share a future sequence
while comparing unequal. Saturation instead of trapping is the package
convention for unreachable-extreme inputs (`SaturatedArithmetic`); normal
values are unaffected. Effect empowerment and damage-potential sums follow
that convention; Poison decay divides potency by four before applying its
minimum one-point loss, avoiding multiplication overflow.
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
selections in row, tree, then node order (tree priority is the `trees` array
order; node IDs must be unique across trees). Removed selections leave their points
available; valid selections within budget are unchanged. Point budget
(`totalTalentPoints`) is owned by `CombatantProgression`; unlock legality is
owned by `TalentModels`.

```sh
./Scripts/test-package.sh TrinketCore
```
