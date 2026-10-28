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
    case actorGainedGoldThisTurn
    case firstTurn
}
