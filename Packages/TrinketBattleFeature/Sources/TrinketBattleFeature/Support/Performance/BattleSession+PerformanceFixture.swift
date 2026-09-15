import BattleEngine
import Foundation
import TrinketContent

#if DEBUG
extension BattleSession {
    /// Prepare a live state; normal commands still own the terminal action and reveal.
    func performanceFixtureState(_ initial: BattleState) -> BattleState {
        let arguments = ProcessInfo.processInfo.arguments
        let victory = arguments.contains("-performance-outcome-victory")
        let log = arguments.contains("-performance-log")
        guard log || victory || arguments.contains("-performance-outcome-defeat") else { return initial }
        var state = initial
        if log {
            let source = initial.enemy
            let enemy = Combatant(
                id: source.id, name: source.name, role: source.role, maxHealth: 10000,
                maxMana: source.maxMana, actionIntervalTurns: source.actionIntervalTurns,
                abilityChoices: source.abilityChoices,
            )
            state = BattleState(
                hero: initial.hero, companion: initial.companion, enemy: enemy,
                heroModifiers: initial.heroModifiers, companionModifiers: initial.companionModifiers,
                enemyModifiers: initial.enemyModifiers, heroStartingHealth: nil, companionStartingHealth: nil,
                enemyFaction: initial.enemyFaction, rngSeed: BattlePerformanceFixture.seed,
                tracksLog: false, dealOpeningHand: false,
            )
        }
        _ = state.drawOpeningHand(rebuildLog: false)
        for index in 0 ..< 500 {
            let previous = state
            if victory || log, let card = PlayPolicy.greedy.preferredPlayableCard(in: state) {
                _ = try? state.playCard(cardID: card.id, rebuildLog: false)
            } else {
                _ = state.endTurn(rebuildLog: false)
            }
            if log, index >= 19 || state.isBattleOver {
                return state.isBattleOver ? previous : state
            }
            if state.isBattleOver {
                precondition(state.isEnemyDefeated == victory, "Performance outcome fixture reached the wrong outcome")
                return previous
            }
        }
        preconditionFailure("Performance outcome fixture did not reach a terminal state")
    }
}
#endif
