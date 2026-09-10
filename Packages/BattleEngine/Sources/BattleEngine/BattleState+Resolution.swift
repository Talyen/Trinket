extension BattleState {
    mutating func withAutomaticPlay(_ body: (inout BattleState) throws -> [ActionEvent]) rethrows -> [ActionEvent] {
        resolution.beginAutomaticPlay()
        defer { resolution.endAutomaticPlay() }
        return try body(&self)
    }

    var playerTurnNumber: Int {
        turnCount + 1
    }

    func isPlayerTurn(every interval: Int, startingAt first: Int? = nil) -> Bool {
        let first = first ?? interval
        return interval > 0 && playerTurnNumber >= first && (playerTurnNumber - first).isMultiple(of: interval)
    }
}
