import TrinketFeatureContracts

public extension PlaySession {
    @discardableResult
    func restartActiveBattle() -> StageMapMessage? {
        let combatants = battle.activeBattle.map { [$0.hero.combatant, $0.companion.combatant] } ?? []
        return battleCoordinator.requestRestart {
            finishBattleExit(for: combatants)
        }
    }
}
