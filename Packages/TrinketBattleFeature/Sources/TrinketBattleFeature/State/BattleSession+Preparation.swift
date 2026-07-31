import Foundation
import TrinketFeatureSupport

public extension BattleSession {
    internal struct PreparedBattleRun {
        let configuration: ActiveBattleConfiguration
        let simulation: BattleSimulationStore.PreparedRun
    }

    func prepareBattleRun(_ configuration: ActiveBattleConfiguration) {
        guard activeBattle == nil,
              let runKey = configuration.runKey else { return }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            simulation: simulation.makePreparedRun(from: configuration)
        )
    }

    /// Opening-hand ability art names for a prepared run (cast faces on first play).
    /// Peeks a copy so the prepared run keeps an empty hand for the paced deal.
    func preparedAbilityArtworkNames(for runKey: BattleRunKey) -> [String] {
        guard let run = preparedBattleRunsByKey[runKey] else { return [] }
        return simulation.openingHandArtworkNames(for: run.simulation)
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

    internal func installSimulationPresentation() {
        guard let snapshot = simulation.presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
