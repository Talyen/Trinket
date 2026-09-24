import TrinketContent
import TrinketCore

package struct UniqueBattleState {
    struct OwnerState {
        var cardsPlayed = 0
        var repeatedCritical = false
        var answeredBlock = false
        var usedFinalSpark = false
        var lastAttack: Ability?
        var lastOrdinaryAbility: Ability?
        var returnedFlightThisTurn = false
        var hasAttacked = false
        var viperReady = false
        var wildheartReady = false
        var goldDamage = 0
        var wrenflightDodge = 0.0

        mutating func resetTurn() {
            cardsPlayed = 0
            hasAttacked = false
            repeatedCritical = false
            answeredBlock = false
            usedFinalSpark = false
            lastAttack = nil
            lastOrdinaryAbility = nil
            returnedFlightThisTurn = false
            wrenflightDodge = 0
        }
    }

    struct CardPlay {
        let owner: BattleParticipant
        let originalAbility: Ability
        var returnName: String?
        var draws: [String] = []
        var attackBonus = 0
        var guaranteedCritical = false
        var repeatDamage = false
        var damageRequests: [DamageRequest] = []
    }

    var owners: [BattleParticipant: OwnerState] = [:]
    var card: CardPlay?
    var retainedStunByEffectID: [Int: Int] = [:]
    // Out-of-turn attacks owed by Knight's Answer defenses and Dodge counters. Recorded during
    // damage resolution and drained once the triggering action completes, so a
    // full Basic never nests inside the damage pipeline on small
    // worker-thread stacks.
    var pendingBlockAnswerOwners: [BattleParticipant] = []
    var pendingCounterAttackActorIDs: [String] = []
    // Reentrancy guard for the outermost-damage drain below. Nested damage
    // during a drain only enqueues; the outer loop picks it up iteratively
    // instead of recursing drain -> Basic -> damage -> drain.
    var isDrainingOutOfTurnAttacks = false
}
