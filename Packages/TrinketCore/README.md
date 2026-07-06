# TrinketCore

Domain primitives shared across all Trinket packages. No UIKit/SwiftUI dependencies.

## Contents

| File | Ownership |
|------|-----------|
| `Effect.swift` | Tagged union of all keyword effects (`.burn`, `.shield`, `.instantHeal`, etc.) |
| `GameEnums.swift` | `Keyword`, `ItemSlot`, `Rarity`, `CombatantRole`, `AbilityTier`, `EffectKind` |
| `PrimaryStats.swift` / `+Rules.swift` | Stat model and formula rules (e.g. `controlMeterThreshold`) |
| `CombatantProgression.swift` | Per-combatant level, XP accumulation, and level-up logic |
| `ActiveEffect.swift` | Runtime effect instance used by battle |
| `SeededRandomNumberGenerator.swift` | Deterministic RNG for reproducible battle outcomes |
| `HomesteadTypes.swift` | Homestead node/resource types |
| `ExperienceScaling.swift` | XP award formulas (level-delta multiplier, catch-up, bracket pacing) using `CombatantProgression.requiredXP` |

This package is imported by every other package (`TrinketContent`, `BattleEngine`, `TrinketPersistence`, `TrinketDesignSystem`). Keep dependencies here to zero.
