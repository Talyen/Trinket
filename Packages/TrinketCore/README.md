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
`Collection+Safe.swift`, `ActiveEffect.swift`, `DamageCondition.swift`.

Contracts: keyword matching runs through one case-insensitive pattern
(`Keyword.highlightPattern` with `Keyword.termLookup`); `Keyword.referenced(in:)`
and keyword highlighting share it. `SeededRandomNumberGenerator` is deterministic
per seed with a fixed non-zero fallback state; equality includes draw progress.
`Effect.durationTurns == 0` covers both instant effects and indefinite buffs;
`EffectKind` flags (`isInstant`, `advancesEachTurn`, removable buff/debuff) are
the source of truth for lifecycle, locked by `EffectModelTests`.

```sh
./Scripts/test-package.sh TrinketCore
```
