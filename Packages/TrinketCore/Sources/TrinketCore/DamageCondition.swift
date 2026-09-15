import Foundation

/// Bonus-damage predicates. Evaluation lives in
/// `BattleEngine.BattleConditionEvaluator`; keep new cases in sync with its switch.
public enum DamageCondition: Hashable, Sendable {
    case enemyBleeding
    case enemyBurning
    case enemyNotBurning
    case enemyPoisoned
    case enemyFrozen
    case enemyStunned
    case enemyStunnedOrFrozen
    case enemyMarked
    case enemyLowerHealthThanActor
    case allyBelowHalfHealth
    case enemyHasBuff
    case firstTurn

    /// Full sentence fragment used in card text (single home for condition copy).
    public var sentenceFragment: String {
        switch self {
        case .enemyBleeding: "the enemy is Bleeding"
        case .enemyBurning: "the enemy is Burning"
        case .enemyNotBurning: "the enemy is not Burning"
        case .enemyPoisoned: "the enemy is Poisoned"
        case .enemyFrozen: "the enemy is Frozen"
        case .enemyStunned: "the enemy is Stunned"
        case .enemyStunnedOrFrozen: "the enemy is Stunned or Frozen"
        case .enemyMarked: "the enemy is Marked"
        case .enemyLowerHealthThanActor: "the enemy has less Health than you"
        case .allyBelowHalfHealth: "your Hero or Companion is below half Health"
        case .enemyHasBuff: "the enemy has a buff"
        case .firstTurn: "played on the first turn"
        }
    }
}
