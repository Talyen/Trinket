import TrinketContent
import TrinketCore

struct CombatantUniqueState: Hashable {
    var cardsPlayed = 0
    var repeatedCritical = false
    var answeredBlock = false
    var usedFinalSpark = false
    var lastAttack: Ability?
    var lastOrdinaryAttackCopyID: Int?
    var returnedGaleThisTurn = false
    var returnedFlightThisTurn = false
    var hasAttacked = false
    var patientEdgeReady = false
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
        lastOrdinaryAttackCopyID = nil
        returnedGaleThisTurn = false
        returnedFlightThisTurn = false
        wrenflightDodge = 0
    }
}
