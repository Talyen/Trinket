import BattleEngine
import Foundation
import TrinketBattleRuntime
import TrinketFeatureSupport

/// Pure simulation operations for an active battle. Presentation (feedback, overlays,
/// timing) stays on `BattleSession`; this type owns engine mutation mechanics only.
@MainActor
enum BattleSimBridge {
    static func outcome(for state: BattleState?) -> BattleSimulationOutcome? {
        guard let state else { return nil }
        return BattleSimulationOutcome.resolve(
            isPartyDefeated: state.isPartyDefeated,
            isEnemyDefeated: state.isEnemyDefeated
        )
    }

    static func isCardPlayable(_ card: BattleCard, in state: BattleState?) -> Bool {
        state?.isCardPlayable(card) ?? false
    }

    @discardableResult
    static func playCard(cardID: Int, state: inout BattleState?) throws -> [ActionEvent] {
        guard var battleState = state else {
            throw BattlePlayError.battleOver
        }
        let events = try battleState.playCard(cardID: cardID, rebuildLog: false)
        state = battleState
        return events
    }

    @discardableResult
    static func endTurn(state: inout BattleState?) -> [ActionEvent] {
        guard var battleState = state else { return [] }
        let events = battleState.endTurn(rebuildLog: false)
        state = battleState
        return events
    }

    static func syncLog(state: inout BattleState?) {
        guard var battleState = state else { return }
        battleState.syncLog()
        state = battleState
    }

    static func releaseLogProjection(state: inout BattleState?) {
        guard var battleState = state else { return }
        battleState.releaseLogProjection()
        state = battleState
    }

    static func makeBattleState(from configuration: BattleRunConfiguration) -> BattleState {
        BattleState(
            hero: configuration.hero.combatant,
            companion: configuration.companion.combatant,
            enemy: configuration.enemy,
            heroModifiers: configuration.hero.modifiers,
            companionModifiers: configuration.companion.modifiers,
            enemyModifiers: configuration.enemyModifiers,
            rngSeed: configuration.rngSeed,
            tracksLog: false,
            dealOpeningHand: false
        )
    }
}
