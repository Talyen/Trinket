import Foundation

/// Ability predicates. Evaluation lives in
/// `BattleEngine.BattleConditionEvaluator`; keep new cases in sync with its switch.
public enum DamageCondition: CaseIterable, Hashable, Sendable {
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
    case allyMissingHealth
    case enemyHasBuff
    case enemyHasBlock
    case enemyFullHealth
    case actorHasTwoBlock
    case firstTurn

    /// Canonical English compatibility text; conditions and battle evaluation remain data-only.
    public var sentenceFragment: String {
        localizedClause(locale: Locale(identifier: "en")).text
    }
}
