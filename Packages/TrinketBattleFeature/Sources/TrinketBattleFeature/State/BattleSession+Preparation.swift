import Foundation
import TrinketBattleRuntime
import TrinketFeatureSupport

public extension BattleSession {
    internal struct PreparedBattleRun {
        let configuration: ActiveBattleConfiguration
        let simulation: BattleSimulationStore.PreparedRun
    }

    @discardableResult
    func prepareBattleRun(_ configuration: ActiveBattleConfiguration) -> Bool {
        guard activeBattle == nil,
              let runKey = configuration.runKey else { return false }
        if preparedBattleRunsByKey[runKey]?.configuration.id == configuration.id {
            return true
        }
        preparedBattleRunsByKey[runKey] = PreparedBattleRun(
            configuration: configuration,
            simulation: simulation.makePreparedRun(from: configuration)
        )
        lifecyclePhase = .prepared
        return true
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
        installActiveBattle(preparedBattleRun.configuration)
        return true
    }

    @discardableResult
    func activate(_ configuration: ActiveBattleConfiguration) -> Bool {
        guard activeBattle == nil else { return false }
        pendingPreparedRun = nil
        installActiveBattle(configuration)
        return true
    }

    @discardableResult
    func restart(_ configuration: ActiveBattleConfiguration) -> Bool {
        guard activeBattle != nil else { return false }
        pendingPreparedRun = nil
        installActiveBattle(configuration)
        return true
    }

    internal func installSimulationPresentation() {
        guard let snapshot = simulation.presentationSnapshot() else { return }
        presentation.install(snapshot)
    }
}
