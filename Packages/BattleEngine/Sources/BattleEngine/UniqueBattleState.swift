import TrinketContent
import TrinketCore

package struct UniqueBattleState {
    struct OwnerState {
        var cardsPlayed = 0
        var returnedHarvest = false
        var repeatedCritical = false
        var calledCompanion = false
        var answeredBlock = false
        var usedFinalSpark = false
        var usedElements: Set<Keyword> = []
        var lastAttack: Ability?
        var heldCardDamage = 0
        var viperReady = false
        var wildheartReady = false
        var goldDamage = 0
        var wrenflightDodge = 0.0

        mutating func resetTurn() {
            cardsPlayed = 0
            returnedHarvest = false
            repeatedCritical = false
            calledCompanion = false
            answeredBlock = false
            usedFinalSpark = false
            usedElements = []
            lastAttack = nil
            wrenflightDodge = 0
        }
    }

    struct CardPlay {
        let owner: BattleParticipant
        let originalAbility: Ability
        let targetWasBleeding: Bool
        var returnName: String?
        var draws: [String] = []
        var attackBonus = 0
        var guaranteedCritical = false
        var repeatDamage = false
        var damageRequests: [DamageRequest] = []
    }

    var owners: [BattleParticipant: OwnerState] = [:]
    var card: CardPlay?
    var pendingOrdinaryActorID: String?
    var ordinaryActionActorID: String?
    var reactionDepth = 0
    var retainedStunByEffectID: [Int: Int] = [:]
}
