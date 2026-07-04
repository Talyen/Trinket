import Foundation

/// Conditions evaluated at ability resolution time against battle state.
public enum DamageCondition: Hashable, Sendable {
    case enemyBleeding
    case enemyBurning
    case enemyPoisoned
    case enemyFrozen
    case enemyStunned
    case enemyStunnedOrFrozen
    case enemyMarked
    case enemyLowerHealthThanActor
    case allyBelowHalfHealth
    case enemyHasBuff
}
