import TrinketContent

/// A fresh automation run owns its observation window; pausing never settles combat.
public struct AutoBattleProgress: Sendable {
    private var progress: BattleDefeatProgress
    private var lastProgressRound: Int

    public init(in battle: BattleState) {
        progress = battle.defeatProgress
        lastProgressRound = battle.turnCount
    }

    public mutating func shouldPause(in battle: BattleState) -> Bool {
        guard !battle.isBattleOver else { return false }
        let currentProgress = battle.defeatProgress
        if currentProgress != progress {
            progress = currentProgress
            lastProgressRound = battle.turnCount
        }
        return battle.turnCount - lastProgressRound >= 30
    }
}
