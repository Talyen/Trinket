struct CombatantUniqueState: Hashable {
    struct Turn: Hashable {
        var cardsPlayed = 0
        var repeatedCritical = false
        var answeredBlock = false
        var usedFinalSpark = false
        var lastOrdinaryAttackCopyID: Int?
        var returnedGaleThisTurn = false
        var returnedFlightThisTurn = false
        var hasAttacked = false
        var wrenflightDodge = 0.0
    }

    var turn = Turn()
    var patientEdgeReady = false
    var viperReady = false
    var wildheartReady = false
    var goldDamage = 0
}
