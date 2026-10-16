import TrinketContent
import TrinketCore

package struct UniqueBattleState {
    struct CardPlay {
        let owner: BattleParticipant
        let originalCopyID: Int
        var returnName: String?
        var draws: [String] = []
        var attackBonus = 0
        var guaranteedCritical = false
        var repeatDamage = false
        var damageRequests: [RepeatedDamage] = []
    }

    struct RepeatedDamage {
        let request: DamageRequest
        let stackPotency: Int
    }

    struct PendingCounterAttack {
        let actorID: String
        var preparesDodgeAttackBonuses = false
    }

    var card: CardPlay?
    var retainedStunByEffectID: [Int: Int] = [:]
    // Out-of-turn attacks owed by Knight's Answer defenses and Dodge counters. Recorded during
    // damage resolution and drained once the triggering action completes, so a
    // full Basic never nests inside the damage pipeline on small
    // worker-thread stacks.
    var pendingBlockAnswerOwners: [BattleParticipant] = []
    var pendingCounterAttacks: [PendingCounterAttack] = []
    // Reentrancy guard for the outermost-damage drain below. Nested damage
    // during a drain only enqueues; the outer loop picks it up iteratively
    // instead of recursing drain -> Basic -> damage -> drain.
    var isDrainingOutOfTurnAttacks = false
}
