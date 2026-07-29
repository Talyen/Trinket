import BattleEngine
import Foundation
import TrinketFeatureSupport

public extension BattleSession {
    internal struct PreparedBattleRun {
        let configuration: ActiveBattleConfiguration
        let state: BattleState
        let presentation: BattlePresentationSnapshot
    }

    func prepareBattleRun(_ configuration: ActiveBattleConfiguration) {
        guard activeBattle == nil,
              let runKey = configuration.runKey else { return }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return
        }
        let state = Self.makeBattleState(from: configuration)
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            state: state,
            presentation: BattlePresentationSnapshot(
                configurationID: configuration.id,
                state: state
            )
        )
    }

    /// Opening-hand ability art names for a prepared run (cast faces on first play).
    /// Peeks a copy so the prepared run keeps an empty hand for the paced deal.
    func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String] {
        guard let run = preparedBattleRunsByKey[runKey] else { return [] }
        var preview = run.state
        preview.drawOpeningHand(rebuildLog: false)
        return preview.hand.cards.compactMap { $0.ability.artReference?.imageName }
    }

    func activatePreparedBattle(
        runKey: BattleRunKey,
        heroID: String,
        companionID: String,
        enemyID: String?
    ) -> Bool {
        guard let preparedBattleRun = preparedBattleRunsByKey[runKey],
              preparedBattleRun.configuration.runKey == runKey,
              preparedBattleRun.configuration.hero.combatant.id == heroID,
              preparedBattleRun.configuration.companion.combatant.id == companionID,
              preparedBattleRun.configuration.enemy?.id == enemyID
        else { return false }
        preparedBattleRunsByKey.removeValue(forKey: runKey)
        pendingPreparedRun = preparedBattleRun
        activeBattle = preparedBattleRun.configuration
        return true
    }

    internal func installBattleState(_ newState: BattleState, configurationID: UUID? = nil) {
        state = newState
        guard let configurationID = configurationID ?? activeBattle?.id else { return }
        presentation.install(
            BattlePresentationSnapshot(configurationID: configurationID, state: newState)
        )
    }
}
